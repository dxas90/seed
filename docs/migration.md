# Flux to Argo CD migration record

## Status

The repository now uses Argo CD for GitOps reconciliation. Flux CRDs and Flux-only composition files have been removed.

The active desired-state resources are:

- Argo CD Applications under component directories;
- separate `<component>-values.yaml` files for Helm configuration;
- category AppProjects under `argocd/`;
- `argocd/root.yaml` as the bootstrap Application;
- the repository-root `kustomization.yaml` as the app-of-apps payload.

## Mapping used

| Previous Flux concept | Argo CD replacement |
|---|---|
| `GitRepository` | Argo CD repository credential plus Application repository URL |
| `HelmRepository` | Helm chart `repoURL` in an Application |
| `OCIRepository` | OCI chart source in an Application |
| `HelmRelease` | one Application per release |
| Flux `Kustomization` | Application pointing to a chart or Git directory |
| `dependsOn` | sync-wave annotation where explicit ordering was required |
| `spec.values` | separate `<component>-values.yaml` |

## Removed resources

Cleanup removed:

- Flux `GitRepository` objects;
- Flux `Kustomization` objects;
- Flux `HelmRelease` objects;
- Flux `HelmRepository` and `OCIRepository` objects;
- Flux-only `install.yaml` and `ks.yaml` files;
- Kustomize files whose only purpose was composing those Flux objects;
- Flux labels, namespace references, Renovate manager configuration, and bootstrap documentation.

Use Git history when auditing the original resources. Do not reintroduce Flux manifests alongside Argo CD desired state.

## Manual-review items

The mechanical resource conversion cannot guarantee complete runtime parity for:

1. Secret-backed Flux `valuesFrom` behavior.
2. SOPS decryption, which requires an Argo CD-compatible integration.
3. Retry, remediation, rollback, wait, and health-check behavior.
4. Cloud IAM and IRSA assumptions.
5. Upstream charts that previously lacked a pinned version.
6. Environment-specific DNS, certificates, storage classes, and load balancers.

Review these before production use.

## Validation

The completed cleanup must continue to satisfy:

```bash
kubectl kustomize . >/tmp/seed-rendered.yaml
kubectl apply --dry-run=server -k .
```

Structural expectations:

- all Applications are in namespace `argocd`;
- every Application references an existing AppProject;
- every `$values/...` path exists;
- every Git `source.path` exists;
- no `*.toolkit.fluxcd.io` API remains;
- no `flux-system` namespace reference remains.

For private repository errors, inspect:

```bash
kubectl get application <name> -n argocd \
  -o jsonpath='{.status.conditions}'
```

A missing Git credential is a bootstrap/authentication issue, not a reason to restore Flux resources.
