# Argo CD entry point

This directory contains the app-of-apps bootstrap Application and category AppProjects.

## Install Argo CD first

If Argo CD is not installed, follow `../docs/argocd-install.md`. The essential commands are:

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch configmap/argocd-cmd-params-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment/argocd-server -n argocd
```

## Bootstrap

1. Configure Argo CD credentials for `git@github.com:dxas90/seed.git`.
2. Apply:

```bash
kubectl apply -f argocd/root.yaml
```

The root Application reads the repository root (`path: .`). The repository-root `kustomization.yaml` lists all AppProjects and child Applications.

## Files

- `root.yaml` — app-of-apps bootstrap object; intentionally not listed in root `kustomization.yaml`.
- `*-project.yaml` — category policy boundaries for child Applications.
- `README.md` — this guide.

The repository-root `kustomization.yaml` is outside this directory because Kustomize's load restrictions prevent an `argocd/` Kustomization from safely importing sibling trees with normal defaults.

## Component pattern

Helm applications use:

```text
<component>/app/
├── <component>-application.yaml
└── <component>-values.yaml
```

The Application uses Argo CD multi-source:

- the external Helm/OCI repository supplies the chart;
- `git@github.com:dxas90/seed.git` supplies the values file with `ref: values`;
- the chart source references `$values/<repository-path>`.

Plain manifest applications point to a Git directory using `source.path` and `directory.recurse`.

## AppProjects

Projects currently group components by platform concern:

- `autoscaling`
- `cert-manager`
- `kube-system`
- `networking`
- `observability`
- `security`

The seed projects permit all sources, destinations, and cluster resources for portability. Restrict them before production use.

## Add an app

1. Choose a category folder under `kubernetes/apps/<category>/`.
2. Create `<component>/app/<component>-application.yaml`.
3. If Helm, create `<component>/app/<component>-values.yaml` and use multi-source `$values/...` syntax.
4. Add the Application path to the repository-root `kustomization.yaml`.
5. Reference the matching AppProject or create a new project.
6. Run:

```bash
kubectl kustomize . >/tmp/seed-rendered.yaml
```

7. Test in kind or another disposable/non-production cluster.

See `../FOLLOW_THIS.md` for mandatory conventions and `../docs/onboarding.md` for a detailed walkthrough.
