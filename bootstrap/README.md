# Bootstrap

This directory contains resources that may be needed before the Argo CD root Application can reconcile the repository.

## Recommended bootstrap order

1. Create or provision the Kubernetes cluster.
2. Install Argo CD.
3. Configure repository credentials for `git@github.com:dxas90/seed.git`.
4. Install any required secret-decryption integration.
5. Apply `argocd/root.yaml`.
6. Let Argo CD manage the remaining desired state.

## Install Argo CD

```bash
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

For idempotent namespace creation, use:

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
```

`server.insecure=true` is appropriate for local access or when TLS terminates at an ingress/gateway. Do not expose Argo CD's plain HTTP endpoint directly to an untrusted network. See `../docs/argocd-install.md` for the complete installation and access guide.

## Repository access

For a private SSH repository, configure Argo CD with:

- URL: `git@github.com:dxas90/seed.git`
- a read-only deploy key or GitHub App credential;
- GitHub's SSH known-host key.

Do not store the private key in this repository.

## SOPS and encrypted files

`bootstrap/sops-age.sops.yaml` is retained as a migration example. Before use:

- confirm it contains no organization-specific payload;
- replace recipients with your own Age recipients;
- configure an Argo CD-compatible SOPS integration;
- test decryption only in a disposable/non-production environment.

Argo CD does not decrypt SOPS files by itself.

## Existing bootstrap Kustomization

`bootstrap/kustomization.yaml` includes foundational CRDs and upstream manifests used by components in this repository. Review every remote URL and version before production.

Render without applying:

```bash
kubectl kustomize bootstrap >/tmp/seed-bootstrap.yaml
```

Apply only after reviewing the rendered resources:

```bash
kubectl apply -k bootstrap
```

## Verify

```bash
kubectl get pods -n argocd
kubectl get crd applications.argoproj.io appprojects.argoproj.io
kubectl get applications -n argocd
```

## Local kind

For schema and controller validation:

```bash
kind create cluster --name seed --config kind-config.yaml
mise run argocd/install
mise run validate
mise run argocd/apply-children
```

Cloud-specific resources, external DNS, IAM, and private Git synchronization require additional configuration and are not fully validated by plain kind.
