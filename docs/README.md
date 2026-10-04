# Documentation index

Start with the document that matches your task.

| Document | Use it for |
|---|---|
| [`../README.md`](../README.md) | Repository overview, structure, and quick start |
| [`argocd-install.md`](argocd-install.md) | Install Argo CD, enable insecure server mode, configure access, and troubleshoot |
| [`architecture.md`](architecture.md) | Understand the app-of-apps, multi-source Helm values, projects, and environment boundaries |
| [`onboarding.md`](onboarding.md) | Add a component and learn the maintainer workflow |
| [`migration.md`](migration.md) | Audit the completed Flux-to-Argo CD migration |
| [`../runbook.md`](../runbook.md) | Operate and troubleshoot the repository |
| [`../FOLLOW_THIS.md`](../FOLLOW_THIS.md) | Mandatory implementation rules and completion checklist |
| [`../argocd/README.md`](../argocd/README.md) | Understand the root Application and AppProjects |
| [`../bootstrap/README.md`](../bootstrap/README.md) | Review optional pre-Argo cluster resources and SOPS considerations |

## Fast paths

### First-time installation

1. `argocd-install.md`
2. `../argocd/README.md`
3. `../README.md`

### New component

1. `onboarding.md`
2. `../FOLLOW_THIS.md`
3. `architecture.md`

### Sync failure

1. `../runbook.md`
2. `argocd-install.md`
3. Inspect the affected `<component>-application.yaml` and `<component>-values.yaml`.

### Production adoption

1. `architecture.md`
2. `migration.md`
3. `../bootstrap/README.md`
4. Restrict every AppProject and replace all generic placeholders.
