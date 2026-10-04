# Architecture

## Overview

Seed is a GitOps repository for Kubernetes platform services. Argo CD reconciles desired state from Git; Helm and Kustomize render the actual Kubernetes resources.

```text
GitHub repository
    |
    v
argocd/root.yaml
    |
    v
repository-root kustomization.yaml
    |-- AppProjects
    `-- child Applications
          |-- external Helm/OCI chart + Git values file
          `-- plain Kubernetes manifest directory
```

## Bootstrap boundary

Argo CD cannot retrieve its own repository credentials from a repository it cannot yet read. Repository credentials therefore live outside this repository, typically in:

- a Terraform-managed Kubernetes Secret;
- a manually bootstrapped Secret for local development;
- or an external secret system installed before the root Application.

After credentials exist, apply `argocd/root.yaml`. The root Application reads `path: .`, which causes Argo CD to render the repository-root `kustomization.yaml`.

## Application categories

Applications are grouped into AppProjects:

| Project | Typical components |
|---|---|
| `autoscaling` | KEDA and scaling add-ons |
| `cert-manager` | issuers and certificates |
| `kube-system` | CoreDNS and node-level utilities |
| `networking` | Istio, gateways, external DNS |
| `observability` | metrics, dashboards, logs, traces, alerts |
| `security` | External Secrets and secret stores |

The current AppProjects are deliberately permissive during seed development. Restrict repositories, namespaces, clusters, cluster resources, and roles before production.

## Helm values model

External charts and repository-owned values use Argo CD multi-source support:

```text
source 1: Helm or OCI chart repository
source 2: git@github.com:dxas90/seed.git with ref: values
```

The chart source references values through `$values/<path>`. This avoids unreadable escaped inline YAML and allows values changes to produce clean diffs.

## Plain manifests

Plain resources use `spec.source.path` plus `directory.recurse`. Keep these directories free of legacy Flux CRDs, or Argo CD will attempt to apply those Flux objects.

## Dependency ordering

Flux `dependsOn` relationships are represented with Argo CD sync waves when ordering is required. Kubernetes-native eventual consistency should be preferred when explicit waves are unnecessary.

## Environment layout

Reusable platform components live under `kubernetes/apps/`. Environment-specific configuration lives under `clusters/`.

The included AWS staging tree is an example, not a production-ready environment. Replace account IDs, regions, IAM roles, domains, and secret paths before use.

## Security model

- Repository credentials remain outside Git.
- Secrets are referenced using Kubernetes Secrets or External Secrets.
- SOPS files are treated as encrypted examples and are never decrypted during routine validation.
- AppProjects provide the policy boundary for sources, destinations, and cluster-scoped resources.

## Local verification

A disposable kind cluster can validate:

- Argo CD CRD compatibility;
- Application/AppProject namespaces;
- Kustomize rendering;
- and basic controller acceptance.

It cannot validate private repository synchronization without repository credentials, nor cloud-specific workloads without the corresponding IAM and cloud APIs.
