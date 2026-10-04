# Seed Kubernetes Platform

A reusable GitOps seed repository for managing Kubernetes platform components with Argo CD, Helm, and Kustomize.

Repository:

- HTTPS: `https://github.com/dxas90/seed`
- SSH: `git@github.com:dxas90/seed.git`

This repository is intentionally generic. Replace example domains, account IDs, regions, storage classes, and cluster-specific settings before using it outside a local test cluster.

## Goals

- Keep each component easy to locate, understand, and remove.
- Keep Helm values as normal YAML files that produce useful pull-request diffs.
- Use one Argo CD `Application` per deployable unit.
- Separate platform concerns through Argo CD `AppProject` resources.
- Provide one app-of-apps bootstrap entry point.
- Preserve an understandable category hierarchy without forcing every component into an identical shape.

## Repository structure

```text
.
├── argocd/
│   ├── root.yaml                    # root app-of-apps Application
│   ├── *-project.yaml               # category AppProjects
│   └── README.md                    # Argo CD conventions and onboarding
├── bootstrap/
│   ├── kustomization.yaml           # pre-Argo bootstrap resources
│   └── README.md                    # bootstrap guidance
├── clusters/
│   └── aws/staging-v2/              # example environment-specific resources
├── kubernetes/
│   └── apps/
│       ├── cert-manager/
│       ├── external-secrets/
│       ├── istio-system/
│       ├── keda/
│       ├── kube-system/
│       ├── networking/
│       └── observability/
├── docs/
│   ├── README.md                      # documentation index
│   ├── argocd-install.md              # install and access Argo CD
│   ├── architecture.md
│   ├── migration.md
│   └── onboarding.md
├── FOLLOW_THIS.md                   # rules for maintainers and coding agents
├── kustomization.yaml               # renders AppProjects + child Applications
├── kind-config.yaml                 # optional local kind cluster config
└── mise.toml                        # local tool versions and helper tasks
```

## Application standard

### Helm-based component

```text
kubernetes/apps/<category>/<component>/app/
├── <component>-application.yaml
└── <component>-values.yaml
```

The Application uses Argo CD multi-source support:

1. Helm or OCI repository supplies the chart.
2. This Git repository supplies the values file through `ref: values`.
3. `helm.valueFiles` references the file with `$values/...`.

Example:

```yaml
spec:
  sources:
    - repoURL: https://example.github.io/charts
      chart: example
      targetRevision: 1.2.3
      helm:
        valueFiles:
          - $values/kubernetes/apps/example/example/app/example-values.yaml
    - repoURL: git@github.com:dxas90/seed.git
      targetRevision: main
      ref: values
```

This keeps values readable and reviewable without embedding escaped YAML strings in an Application manifest.

### Plain Kubernetes component

Plain manifests use a Git source and a directory path:

```yaml
spec:
  source:
    repoURL: git@github.com:dxas90/seed.git
    targetRevision: main
    path: kubernetes/apps/example/example/resources
    directory:
      recurse: true
```

## Quick start

### Prerequisites

Install Git, `kubectl`, Argo CD in the target cluster, and optionally `kind` and `mise`.

### Clone

```bash
git clone git@github.com:dxas90/seed.git
cd seed
```

### Validate locally

```bash
kubectl kustomize . >/tmp/seed-rendered.yaml
```

### Install Argo CD

Confirm the target context, then install and configure Argo CD:

```bash
kubectl config current-context
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
```

`server.insecure=true` expects TLS termination in front of Argo CD or local-only access. Do not expose the HTTP endpoint directly to an untrusted network.

See [`docs/argocd-install.md`](docs/argocd-install.md) for repository credentials, UI access, status commands, and troubleshooting.

### Bootstrap through app-of-apps

Configure Argo CD repository credentials for `git@github.com:dxas90/seed.git`, then apply:

```bash
kubectl apply -f argocd/root.yaml
```

Argo CD renders the repository-root `kustomization.yaml`, which lists the AppProjects and child Applications.

### Validate without Git reconciliation

For a disposable cluster, validate the child resources directly:

```bash
kubectl kustomize . >/tmp/seed-rendered.yaml
kubectl apply --dry-run=server -k .
```

## Local kind testing

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
kubectl kustomize . >/tmp/seed-rendered.yaml
kubectl apply -k .
kubectl get applications -n argocd
kubectl get appprojects -n argocd
```

Applications that reference the SSH repository remain `Unknown` until Argo CD has repository credentials. That is an authentication issue, not a manifest-schema issue.

To open the UI after setup, run this in a separate terminal and keep it open:

```bash
./scripts/argocd-port-forward.sh
```

Then browse to `http://127.0.0.1:8080`. If port 8080 is occupied, use `ARGOCD_LOCAL_PORT=18080 ./scripts/argocd-port-forward.sh`.

## Adding a component

1. Choose or create a category under `kubernetes/apps/`.
2. Create `<component>/app/<component>-application.yaml`.
3. For Helm, create `<component>/app/<component>-values.yaml`.
4. Select the matching AppProject or add `argocd/<category>-project.yaml`.
5. Add the Application to the repository-root `kustomization.yaml`.
6. Run `kubectl kustomize .`.
7. Test against kind or a non-production cluster.
8. Document component-specific assumptions.

See `docs/onboarding.md` and `FOLLOW_THIS.md` for the complete workflow.

## Environment-specific configuration

`clusters/` contains example environment-specific resources. Before enabling an environment:

- replace example AWS account IDs and regions;
- replace domains and certificate subjects;
- review IRSA annotations and trust policies;
- review storage classes and persistent volume sizes;
- configure Argo CD repository credentials;
- configure SOPS recipients if encrypted files are retained;
- remove components you do not intend to run.

## Security rules

- Never commit unencrypted credentials, kubeconfigs, cloud keys, or private SSH keys.
- Treat existing `*.sops.yaml` files as examples until their recipients and payloads are verified.
- Keep Argo CD repository credentials outside the repository.
- Tighten AppProject `sourceRepos`, destinations, and cluster-resource allowlists before production.
- Do not make permanent production changes with direct `kubectl apply`; commit desired state and let Argo CD reconcile it.

## Migration status

The repository now uses Argo CD Applications and AppProjects exclusively for GitOps reconciliation. The previous Flux CRDs have been removed. Argo CD manifests and `<component>-values.yaml` files are the active structure. See `docs/migration.md` for the completed migration record and remaining platform-specific review items.

## Further reading

- `FOLLOW_THIS.md` — implementation and migration rules
- `docs/argocd-install.md` — install, configure, access, and troubleshoot Argo CD
- `argocd/README.md` — Argo CD entry point and conventions
- `docs/architecture.md` — repository architecture
- `docs/onboarding.md` — new-maintainer walkthrough
- `docs/migration.md` — Flux-to-Argo migration notes
- `runbook.md` — operational checks and troubleshooting

## License

Apache License 2.0. See `LICENSE`.
