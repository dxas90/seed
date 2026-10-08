#!/usr/bin/env bash
set -euo pipefail

# Local disposable-cluster setup for the Seed repository.
# This script never creates or stores repository credentials.

command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
command -v kind >/dev/null || { echo "kind is required" >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required" >&2; exit 1; }

docker info >/dev/null 2>&1 || { echo "docker daemon is not running" >&2; exit 1; }

CLUSTER_NAME="${KIND_CLUSTER_NAME:-seed}"
CONTEXT="kind-${CLUSTER_NAME}"

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml
fi

kubectl --context "${CONTEXT}" create namespace argocd --dry-run=client -o yaml \
  | kubectl --context "${CONTEXT}" apply -f -

kubectl --context "${CONTEXT}" apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side

kubectl --context "${CONTEXT}" patch configmap/argocd-cmd-params-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'

# Local kind has no cloud LoadBalancer controller. Mark Gateway resources healthy
# when accepted so the local validation loop does not block on EXTERNAL-IP=<pending>.
kubectl --context "${CONTEXT}" patch configmap/argocd-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"resource.customizations.health.gateway.networking.k8s.io_Gateway":"hs = {}\nhs.status = \"Healthy\"\nhs.message = \"Healthy (overridden for kind)\"\nreturn hs\n"}}'

kubectl --context "${CONTEXT}" rollout restart deployment/argocd-server -n argocd
kubectl --context "${CONTEXT}" delete pod argocd-application-controller-0 -n argocd --ignore-not-found

kubectl --context "${CONTEXT}" wait --for=condition=available -n argocd \
  deployment/argocd-repo-server deployment/argocd-server \
  --timeout=180s

# Apply bootstrap CRDs first (Gateway API, Prometheus Operator CRDs, cert-manager, etc.)
# These are prerequisites for the ArgoCD Applications that reference them.
# Must use --server-side to avoid annotation-too-large errors on large CRDs.
echo "Applying bootstrap CRDs (server-side)..."
kubectl --context "${CONTEXT}" apply --server-side -k bootstrap

# Local-only mocks for cloud-backed secrets/config. These let kind validate the
# applications without real AWS Secrets Manager, Cloudflare, Slack, PagerDuty, etc.
# Create the target namespaces first: a clean cluster does not have them until
# the Argo CD Applications reconcile, but local-mocks must exist before that.
echo "Creating local mock namespaces..."
for namespace in observability networking cert-manager; do
  kubectl --context "${CONTEXT}" create namespace "${namespace}" --dry-run=client -o yaml \
    | kubectl --context "${CONTEXT}" apply -f -
done

echo "Applying local mock resources..."
kubectl --context "${CONTEXT}" apply -k local-mocks

kubectl kustomize . >/tmp/seed-rendered.yaml
kubectl --context "${CONTEXT}" apply -k .

cat <<EOF

Local validation completed.

Argo CD repository credentials are intentionally not configured by this script.
Applications using git@github.com:dxas90/seed.git may report Unknown until a
read-only repository credential is created in namespace argocd.

Inspect status with:
  kubectl --context "${CONTEXT}" get applications -n argocd
  kubectl --context "${CONTEXT}" get appprojects -n argocd

Open the Argo CD UI in a separate terminal:
  ./scripts/argocd-port-forward.sh

Then browse to:
  http://127.0.0.1:8080

The port-forward command intentionally remains attached to its terminal. Stop it
with Ctrl-C. It is not started by this setup script, because a foreground
port-forward would make setup appear hung and a shell background job would die
when this script exits.
EOF
