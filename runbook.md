# Operations runbook

This runbook covers the generic Seed Kubernetes platform repository.

## Repository

- HTTPS: `https://github.com/dxas90/seed`
- SSH: `git@github.com:dxas90/seed.git`

## Scope

The repository manages example platform components through Argo CD. It contains reusable components under `kubernetes/apps/` and example environment-specific resources under `clusters/`.

Do not assume the example configuration is safe for production. Replace account IDs, domains, IAM roles, secret paths, and storage settings first.

## Health checks

### Render desired state

```bash
kubectl kustomize . >/tmp/seed-rendered.yaml
```

### Argo CD controllers

```bash
kubectl get pods -n argocd
kubectl get deployments -n argocd
```

### Applications and projects

```bash
kubectl get applications -n argocd
kubectl get appprojects -n argocd
```

### Inspect a failed or unknown Application

```bash
kubectl get application <name> -n argocd -o yaml
kubectl get application <name> -n argocd \
  -o jsonpath='{.status.conditions}'
```

A common local error is failure to create a Git client for `git@github.com:dxas90/seed.git`. This means Argo CD repository credentials are missing or invalid.

## Repository credentials

Argo CD must receive repository credentials outside Git. For a private SSH repository, configure a repository Secret or credential template in namespace `argocd`.

Never commit the private deploy key.

```bash
kubectl get secrets -n argocd \
  -l argocd.argoproj.io/secret-type=repository
```

## Root app-of-apps

```bash
kubectl apply -f argocd/root.yaml
kubectl get application cluster-addons -n argocd
```

The root Application uses `path: .` and renders the repository-root `kustomization.yaml`.

## Local kind validation

```bash
kind create cluster --name seed --config kind-config.yaml
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch configmap/argocd-cmd-params-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment/argocd-server -n argocd
kubectl wait --for=condition=available -n argocd \
  deployment/argocd-repo-server deployment/argocd-server \
  --timeout=180s
kubectl apply -k .
```

Expected limitations:

- private Git sources fail without credentials;
- AWS components fail without IAM and AWS APIs;
- cloud load balancers and DNS records do not work in plain kind;
- storage classes may differ;
- production domains remain placeholders.

## Helm values troubleshooting

Applications use multi-source values. Verify:

1. the chart source has a Helm/OCI repository URL;
2. the second source has `ref: values`;
3. the second source points to `git@github.com:dxas90/seed.git`;
4. the chart references `$values/<existing-path>`;
5. the values file parses as YAML.

## Project errors

```bash
kubectl get appprojects -n argocd
kubectl get application <name> -n argocd \
  -o jsonpath='{.spec.project}'
```

Every referenced project must exist under `argocd/` and be listed in root `kustomization.yaml`.

## Sync ordering

```bash
kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave
```

Do not add sync waves unless a real dependency requires them.

## Secret handling

- Do not decrypt SOPS files during routine diagnostics.
- Do not print Kubernetes Secret payloads into tickets or logs.
- Use External Secrets or another managed secret system for runtime credentials.
- Rotate a leaked deploy key immediately through an approved security process.

## Safe rollback

1. Revert the Git commit.
2. Push through the normal review path.
3. Let Argo CD reconcile the revert.

Do not delete namespaces, AppProjects, root Applications, encryption keys, or cluster-scoped resources without explicit impact review.

## Migration record

The Flux CRDs and Flux-only composition files have been removed. If behavior differs from the previous deployment, use Git history and `docs/migration.md` to compare the translated Argo CD Application, values, namespace, and ordering rather than restoring Flux resources.
