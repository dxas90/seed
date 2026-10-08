# Install and verify Argo CD

This guide installs Argo CD, enables plain HTTP access inside the cluster, verifies the controllers, and bootstraps Seed.

## Before you start

Confirm the active context. Never run installation commands against an unknown cluster.

```bash
kubectl config current-context
kubectl cluster-info
```

For local testing, the expected context is normally `kind-seed`.

## 1. Install Argo CD

Run these commands in order:

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side

kubectl patch configmap/argocd-cmd-params-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'
```

The namespace command returns `AlreadyExists` when rerun. For an idempotent alternative:

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
```

### What `server.insecure=true` does

This setting makes `argocd-server` serve HTTP instead of terminating TLS itself. Use it when TLS is terminated by an ingress, gateway, load balancer, or local port-forward setup.

Do not expose the resulting HTTP endpoint directly to an untrusted network. For a public endpoint, terminate TLS in front of Argo CD or remove this setting and configure Argo CD TLS.

Restart the server after changing the ConfigMap so the setting takes effect immediately:

```bash
kubectl rollout restart deployment/argocd-server -n argocd
```

## 2. Wait for Argo CD

```bash
kubectl wait --for=condition=available -n argocd \
  deployment/argocd-repo-server \
  deployment/argocd-server \
  --timeout=180s
```

Check all workloads:

```bash
kubectl get pods -n argocd
kubectl get deployments -n argocd
kubectl get crd applications.argoproj.io appprojects.argoproj.io
```

## 3. Configure repository access

Seed uses the private SSH repository:

```text
git@github.com:dxas90/seed.git
```

Argo CD needs a read-only deploy key, GitHub App credential, or another supported repository credential. Keep private keys outside this repository.

Confirm repository Secrets:

```bash
kubectl get secrets -n argocd \
  -l argocd.argoproj.io/secret-type=repository
```

Without credentials, Applications that use Seed as a source report `Unknown` with a repository-client error.

## 4. Validate desired state

From the repository root:

```bash
kubectl kustomize . >/tmp/seed-rendered.yaml
```

The current repository should render:

```bash
grep -c '^kind: Application$' /tmp/seed-rendered.yaml
grep -c '^kind: AppProject$' /tmp/seed-rendered.yaml
```

Expected repository-defined resources:

- 24 Applications
- 6 AppProjects

## 5. Bootstrap Seed

### Local kind mocks

Before applying the Applications in a disposable kind cluster, create the mock target namespaces and seed local-only mocks:

```bash
for namespace in observability networking cert-manager; do
  kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl apply -k local-mocks
```

These mocks replace cloud/provider-backed prerequisites that do not exist in kind:

- `Secret/cert-manager-secret` for the Cloudflare API token normally sourced from AWS Secrets Manager.
- `Secret/external-dns-secret` so the chart can mount its expected token Secret.
- `Secret/alertmanager-secret` plus `ConfigMap/alertmanager` so the Alertmanager StatefulSet can start.
- `ConfigMap/alloy-configmap` so Alloy can start with a minimal local config.

`external-dns` uses the `inmemory` provider for local validation, and certificates use the local `selfsigned` issuer. The real ACME issuers remain present, but the AWS-backed ExternalSecret is excluded from the local issuers kustomization because there is no AWS Secrets Manager backend in kind.

The setup helper applies these automatically:

```bash
./all-local-setup.sh
```

### Normal GitOps bootstrap

Apply only the root Application:

```bash
kubectl apply -f argocd/root.yaml
```

Argo CD then reads the repository root and manages the AppProjects and child Applications listed by `kustomization.yaml`.

### Direct validation mode

For a disposable cluster, apply the child resources directly to validate their CRD shapes:

```bash
kubectl apply --dry-run=server -k .
kubectl apply -k .
```

Use direct apply for testing only. The root Application is the normal long-term entry point.

## 6. Inspect status

Compact overview:

```bash
kubectl get applications -n argocd
kubectl get appprojects -n argocd
```

Show project, destination namespace, sync, and health together:

```bash
kubectl get applications -n argocd \
  -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project,NAMESPACE:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'
```

Show sync waves:

```bash
kubectl get applications -n argocd \
  -o custom-columns='NAME:.metadata.name,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave'
```

Inspect one Application:

```bash
kubectl describe application <name> -n argocd
kubectl get application <name> -n argocd \
  -o jsonpath='{.status.conditions}'
```

## 7. Access the UI locally

Use the repository helper in a separate terminal:

```bash
./scripts/argocd-port-forward.sh
```

It validates the context, namespace, server rollout, service, and local port before starting the forwarding process. It intentionally remains attached to the terminal; closing that terminal or pressing Ctrl-C stops the tunnel.

Defaults:

- context: `kind-seed`
- address: `127.0.0.1`
- local port: `8080`

Override them when needed:

```bash
KUBE_CONTEXT=kind-seed \
ARGOCD_LOCAL_ADDRESS=127.0.0.1 \
ARGOCD_LOCAL_PORT=18080 \
./scripts/argocd-port-forward.sh
```

Equivalent direct command:

```bash
kubectl --context kind-seed port-forward \
  --address 127.0.0.1 \
  service/argocd-server \
  -n argocd \
  8080:80
```

Open:

```text
http://localhost:8080
```

Retrieve the initial administrator password:

```bash
argocd admin initial-password -n argocd
```

or, without the Argo CD CLI:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 --decode; echo
```

Change or disable the initial administrator account according to your production authentication policy.

## 8. Troubleshooting

### Repository client failure

Symptom:

```text
failed to get git client for repo git@github.com:dxas90/seed.git
```

Cause: missing or invalid repository credentials.

### Application project does not exist

```bash
kubectl get appprojects -n argocd
kubectl get application <name> -n argocd \
  -o jsonpath='{.spec.project}'
```

### Values file cannot be found

Inspect `spec.sources[].helm.valueFiles`. Paths beginning with `$values/` are relative to the root of the source whose `ref` is `values`.

### Port-forward exits or appears to crash

A port-forward is a long-running foreground process. Run it in a separate terminal and keep that terminal open:

```bash
./scripts/argocd-port-forward.sh
```

If it exits, check:

```bash
kubectl --context kind-seed get pods -n argocd \
  -l app.kubernetes.io/name=argocd-server
kubectl --context kind-seed get service argocd-server -n argocd
ss -ltn 'sport = :8080'
```

If port 8080 is busy:

```bash
ARGOCD_LOCAL_PORT=18080 ./scripts/argocd-port-forward.sh
```

Do not start `kubectl port-forward ... &` from a setup script and expect it to survive after that script exits. Many shells terminate background jobs on exit, and a foreground port-forward makes setup appear stuck.

### UI returns redirect or protocol errors

Confirm the insecure-server value and restart status:

```bash
kubectl get configmap argocd-cmd-params-cm -n argocd \
  -o jsonpath='{.data.server\.insecure}'; echo
kubectl rollout status deployment/argocd-server -n argocd
```

### Remove the insecure setting

```bash
kubectl patch configmap/argocd-cmd-params-cm \
  -n argocd \
  --type json \
  -p='[{"op":"remove","path":"/data/server.insecure"}]'
kubectl rollout restart deployment/argocd-server -n argocd
```
