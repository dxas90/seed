# Follow this: repository implementation and migration rules

These instructions are for human maintainers and coding agents changing this GitOps repository.

## Scope

Use this repository for reusable Kubernetes platform components managed with Argo CD, Helm, and Kustomize.

The structure is a default, not a law. Preserve working behavior and deployment paths first. Reorganize only when the resulting structure is easier to validate, operate, and explain.

## Source of truth

- Argo CD `Application` and `AppProject` resources are the GitOps source of truth.
- `<component>-values.yaml` is the source of truth for Helm values.
- `argocd/root.yaml` is the app-of-apps bootstrap entry point.
- The repository-root `kustomization.yaml` lists AppProjects and child Applications.
- The prior Flux CRDs have been removed; use Git history and `docs/migration.md` when auditing the translation.

## Definition of done

A change is complete only when all applicable conditions are true:

1. Every changed YAML file parses.
2. `kubectl kustomize .` renders successfully.
3. Every Argo CD Application has `metadata.namespace: argocd`.
4. Every Helm Application references a separate values file when non-trivial values exist.
5. Every `source.path` and `$values/...` path exists in the repository.
6. Every Application references an existing AppProject.
7. Environment and namespace behavior is preserved unless the change intentionally modifies it.
8. Secrets, private keys, generated credentials, kubeconfigs, and state files are not committed.
9. Documentation explains any new component, environment, dependency, or operational assumption.
10. The final report includes the exact commands run and their real results.

## Required process before changing files

1. Read `README.md`, `argocd/README.md`, and the nearest component files.
2. Inspect the repository-root `kustomization.yaml`.
3. Identify the deployment unit:
   - Helm chart,
   - plain Kubernetes directory,
   - CRD/configuration bundle,
   - or environment-specific overlay.
4. Identify ordering requirements and map them to Argo CD sync waves.
5. Identify required namespaces and cluster-scoped resources.
6. Check for encrypted or external secret dependencies without decrypting or printing them.
7. Check whether the component is safe to exercise in kind.

## Standard component patterns

### Helm chart

```text
kubernetes/apps/<category>/<component>/app/
├── <component>-application.yaml
└── <component>-values.yaml
```

Use Argo CD multi-source for external charts plus values from this repository:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: example
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: example-category
  destination:
    server: https://kubernetes.default.svc
    namespace: example
  sources:
    - repoURL: https://example.github.io/charts
      chart: example
      targetRevision: 1.2.3
      helm:
        valueFiles:
          - $values/kubernetes/apps/example-category/example/app/example-values.yaml
    - repoURL: git@github.com:dxas90/seed.git
      targetRevision: main
      ref: values
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
```

Rules:

- Do not embed large `helm.values` strings.
- Pin chart versions whenever the source supports it.
- Keep sensitive values out of the values file; reference Secrets or ExternalSecrets.
- Use `<component>-values.yaml`, not an ambiguous `values.yaml`, when multiple charts share a directory.

### Plain Kubernetes manifests

Use one Application pointing at a dedicated manifest directory:

```yaml
spec:
  source:
    repoURL: git@github.com:dxas90/seed.git
    targetRevision: main
    path: kubernetes/apps/example-category/example/resources
    directory:
      recurse: true
```

Do not point `directory.recurse` at a directory containing Flux `HelmRelease`, `GitRepository`, `OCIRepository`, or Flux `Kustomization` objects unless the migration intentionally needs them applied.

### Dependency ordering

Translate dependencies into sync waves:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

Lower waves sync first. Keep ordering minimal; do not assign waves when Kubernetes discovery and normal reconciliation are sufficient.

## AppProjects

- Put AppProjects under `argocd/<category>-project.yaml`.
- During prototyping, permissive source/destination policies are acceptable.
- Before production, restrict:
  - `sourceRepos`,
  - destinations,
  - namespace scope,
  - cluster-scoped resources,
  - and roles/groups.
- Every Application must reference an existing project.

## Root app-of-apps

`argocd/root.yaml` points to the repository root (`path: .`). The root Kustomization lists AppProjects and child Applications.

Do not add `argocd/root.yaml` to the repository-root `kustomization.yaml`; the root Application is the bootstrap object and should not recursively manage itself.

## Repository references

Canonical repository:

- HTTPS: `https://github.com/dxas90/seed`
- SSH: `git@github.com:dxas90/seed.git`

Use the SSH URL for private Argo CD repository access. Store repository credentials in Argo CD or an external secret system, never in Git.

## Generic placeholders

This seed repository must not contain organization-specific names, production account IDs, employee emails, internal domains, or private Git hosts.

Use placeholders such as:

- AWS account: `000000000000`
- domain: `platform.example.com`
- owner: `platform@example.com`
- cluster names: `seed-staging`, `seed-production`

Clearly document every placeholder that must be replaced.

## Secrets and encryption

- Never decrypt or print SOPS files during routine migration.
- Verify that `.gitignore` covers local keys before creating them.
- Do not commit private SSH keys.
- Encrypted examples should use documented placeholder recipients or be removed.
- ExternalSecret resources must reference configurable example paths, not internal production paths.

## Validation workflow

Run at minimum:

```bash
kubectl kustomize . >/tmp/seed-rendered.yaml
```

Validate that the render includes expected kinds:

```bash
grep -c '^kind: Application$' /tmp/seed-rendered.yaml
grep -c '^kind: AppProject$' /tmp/seed-rendered.yaml
```

If kind is available:

```bash
kind get clusters
kubectl get namespace argocd
kubectl apply -k .
kubectl get applications -n argocd
kubectl get appprojects -n argocd
```

Installing Argo CD in a disposable kind cluster is allowed. Do not install it into an unknown or production context.

`Unknown` sync status is acceptable in local validation when private repository credentials are absent. Report the exact `Application.status.conditions` message instead of guessing.

## New component checklist

- [ ] Component directory follows the standard layout.
- [ ] Application name is dashed-lowercase.
- [ ] Application namespace is `argocd`.
- [ ] Destination namespace is explicit.
- [ ] AppProject exists.
- [ ] Chart version is pinned when possible.
- [ ] Values are in `<component>-values.yaml`.
- [ ] `$values/...` path is correct.
- [ ] Application is listed in root `kustomization.yaml`.
- [ ] Sync waves reflect real dependencies only.
- [ ] Secrets are referenced, not embedded.
- [ ] `kubectl kustomize .` passes.
- [ ] README or component documentation is updated.

## Migration checklist

When converting Flux resources:

1. Map each Flux `HelmRelease` to one Argo CD Application.
2. Resolve `HelmRepository` or `OCIRepository` into the Application chart source.
3. Move `spec.values` into `<component>-values.yaml`.
4. Convert `dependsOn` to sync waves only where needed.
5. Map `targetNamespace` and HelmRelease namespace explicitly.
6. Normalize stale path aliases against actual on-disk directories.
7. Remove Flux-specific labels and annotations from Argo CD resources.
8. Add the Application to the root Kustomization.
9. Flux files were removed as part of the completed migration; consult Git history rather than restoring duplicate desired state.
10. Record any behavior difference and resolution in `docs/migration.md`.

## Prohibited shortcuts

- Do not fabricate validation results.
- Do not claim Argo CD synchronized successfully if repository credentials were unavailable.
- Do not use direct cluster edits as desired state.
- Do not put plaintext secrets in Helm values.
- Do not leave empty repository URLs or invalid paths.
- Do not add a file to Kustomize by referencing outside its allowed root.
- Do not preserve organization-specific identifiers merely because they existed in the source repository.

## Documentation expectations

Update documentation when changing:

- repository structure;
- bootstrap method;
- supported environments;
- external dependencies;
- namespaces or AppProjects;
- secret providers;
- or destructive operational procedures.

Prefer short, task-oriented instructions with real commands. Keep examples generic and clearly label placeholders.
