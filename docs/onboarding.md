# New maintainer onboarding

## First 30 minutes

1. Read `README.md` and `FOLLOW_THIS.md`.
2. Inspect `argocd/root.yaml` and the repository-root `kustomization.yaml`.
3. Pick one simple Application such as reloader.
4. Follow its chart source, values file, project, destination namespace, and root Kustomization entry.
5. Render the repository:

```bash
kubectl kustomize . >/tmp/seed-rendered.yaml
```

6. Confirm the rendered counts:

```bash
grep -c '^kind: Application$' /tmp/seed-rendered.yaml
grep -c '^kind: AppProject$' /tmp/seed-rendered.yaml
```

## Mental model

- `argocd/root.yaml` is the only bootstrap Application.
- `kustomization.yaml` lists what the root manages.
- `argocd/*-project.yaml` defines category-level policy boundaries.
- `*-application.yaml` defines where and how one deployable unit is installed.
- `*-values.yaml` contains human-editable chart configuration.
- `clusters/` contains environment-specific resources.
- The previous Flux objects have been removed; `docs/migration.md` records their Argo CD mapping.

## Add a Helm component

1. Choose a category and AppProject.
2. Create:

```text
kubernetes/apps/<category>/<component>/app/
├── <component>-application.yaml
└── <component>-values.yaml
```

3. Use multi-source in the Application: chart source plus Git values source.
4. Add `metadata.namespace: argocd`.
5. Set an explicit destination namespace.
6. Add the Application path to root `kustomization.yaml`.
7. Run `kubectl kustomize .`.
8. If safe, apply to kind and inspect the Application conditions.

## Add plain manifests

1. Put the resources in a dedicated directory.
2. Point an Application at that directory.
3. Use `directory.recurse: true` only when every YAML object below the directory should be applied.
4. Add the Application to root `kustomization.yaml`.

## Common mistakes

- Omitting `metadata.namespace: argocd`, which creates Applications in the current kubectl namespace.
- Referencing a values file relative to the chart repository instead of using `$values/...` multi-source syntax.
- Using a nonexistent project.
- Copying environment-specific account IDs or domains into reusable configuration.
- Pointing Argo CD at a directory that still includes Flux CRDs.
- Assuming an `Unknown` status means invalid YAML; inspect `.status.conditions` first.

## Pull-request expectations

Include:

- purpose and affected category;
- destination namespace and cluster assumptions;
- chart/version changes;
- values changes;
- dependency/sync-wave changes;
- secret or IAM prerequisites;
- output from `kubectl kustomize .`;
- and kind validation when applicable.

## Where to ask questions

This generic repository does not encode a company team or escalation path. Add ownership and contact information through `CODEOWNERS`, component READMEs, or your organization’s service catalog after adopting the seed.
