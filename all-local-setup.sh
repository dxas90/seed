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
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl --context "${CONTEXT}" patch configmap/argocd-cmd-params-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'

kubectl --context "${CONTEXT}" rollout restart deployment/argocd-server -n argocd

kubectl --context "${CONTEXT}" wait --for=condition=available -n argocd \
  deployment/argocd-repo-server deployment/argocd-server \
  --timeout=180s

kubectl kustomize . >/tmp/seed-rendered.yaml
kubectl --context "${CONTEXT}" apply -k .

cat <<'EOF'

Local validation completed.

Argo CD repository credentials are intentionally not configured by this script.
Applications using git@github.com:dxas90/seed.git may report Unknown until a
read-only repository credential is created in namespace argocd.

Inspect status with:
  kubectl get applications -n argocd
  kubectl get appprojects -n argocd
EOF
