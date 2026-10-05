# Seed platform operations runbook

This runbook is the operating template for the Seed Kubernetes platform repository. It is intentionally generic: replace placeholders, domains, account IDs, owners, and environment details before using it for a real production platform.

## Runbook summary

| Field | Value |
| - | - |
| Repository | `https://github.com/dxas90/seed` |
| SSH remote | `git@github.com:dxas90/seed.git` |
| Primary delivery model | GitOps with Argo CD app-of-apps |
| Host platform | Kubernetes; local validation uses `kind` |
| Service tier | Template: set to Bronze / Silver / Gold |
| Lifecycle stage | Template: set to Development / Staging / Production |
| Delivered by | Platform / DevOps team |
| Supported by | Template: platform owner or support group |
| Technical owner | Template: named owner or owning team |
| Known about by | Template: platform team, service owners, security/compliance |

## Primary environments and URLs

| Environment | Cluster/context | Region | Primary endpoint | Notes |
| - | - | - | - | - |
| Local | `kind-seed` | local | `http://127.0.0.1:8080` via `./scripts/argocd-port-forward.sh` | Disposable validation only |
| Staging | Template: `<cluster-name>` | Template: `<region>` | Template: `<url>` | Replace before production use |
| Production | Template: `<cluster-name>` | Template: `<region>` | Template: `<url>` | Replace before production use |

## Scope

This repository manages platform add-ons through Argo CD Applications and AppProjects. It contains reusable components under `kubernetes/apps/`, bootstrap prerequisites under `bootstrap/`, and example environment-specific resources under `clusters/`.

This repository is GitOps desired state. Normal changes must flow through Git and Argo CD. Do not make long-lived manual changes with `kubectl`, Helm, or a UI. Manual `kubectl` operations are acceptable only for disposable local validation or emergency diagnostics, and they must be reconciled back into Git when kept.

Do not assume the example configuration is safe for production. Replace domains, account IDs, IAM roles, secret paths, storage settings, ingress/gateway settings, and notification targets first.

## Architecture

The platform follows an Argo CD app-of-apps model:

- `argocd/root.yaml` is the root Application.
- The repository root `kustomization.yaml` lists AppProjects and child Applications.
- AppProjects live under `argocd/` and group Applications by operational area.
- Applications live next to their values under `kubernetes/apps/<namespace>/<component>/...`.
- Helm chart Applications use Argo CD multi-source values:
  - chart source: Helm/OCI repository;
  - values source: this Git repository with `ref: values`;
  - values reference: `$values/<path>/<app>-values.yaml`.
- Local-only mocks live under `local-mocks/` and are applied only to make a disposable kind cluster converge without cloud provider credentials.

### Key directories

| Path | Purpose |
| - | - |
| `argocd/` | Root Application and AppProjects |
| `bootstrap/` | CRDs and prerequisites required before child Applications sync |
| `kubernetes/apps/` | Reusable platform Applications and values |
| `local-mocks/` | Local kind-only mocked Secrets and ConfigMaps |
| `scripts/` | Operator helper scripts |
| `docs/` | Install, architecture, migration, onboarding, and operational notes |

### Cost summary template

Fill this in for real environments. Keep local kind marked as zero-cost/disposable.

| Environment | Monthly estimate | Notes |
| - | - | - |
| Local kind | $0 direct cloud cost | Docker-only disposable cluster |
| Staging | Template: `$<amount>` | Include compute, load balancers, NAT, storage, observability |
| Production | Template: `$<amount>` | Include HA cost and retention settings |

## Data classification

| Question | Answer |
| - | - |
| Contains personal data | Template: No by default; update if workloads or configs include PII |
| Contains sensitive data | Yes, operational metadata and references to secret names/paths can be sensitive |
| Can download personal data | No by default; update for real workloads |
| Can contact individuals | No by default; update if alerting routes page or email people |

## Risk

Primary risks:

- Secret references are present in desired state. Secret values must not be committed.
- Argo CD has permissions to reconcile cluster resources. Incorrect manifests can impact shared platform services.
- Local mocks can hide missing cloud/provider dependencies if mistaken for production readiness.
- Gateway, DNS, ACME, and ExternalSecret resources depend on infrastructure outside kind.
- Cluster-scoped resources such as CRDs, AppProjects, ClusterIssuers, ClusterRoles, and webhooks can affect multiple Applications.

Required controls:

- Review diffs before merge.
- Keep credentials outside Git.
- Use local mocks only for disposable validation.
- Require explicit impact review before deleting namespaces, root Applications, AppProjects, CRDs, KMS/encryption resources, or cluster-scoped controllers.

## Release process type

Partially automated.

## Release process

1. Edit manifests, values, docs, or scripts in Git.
2. Render locally:

   ```bash
   kubectl kustomize . >/tmp/seed-rendered.yaml
   ```

3. Validate shape against a disposable cluster when available:

   ```bash
   ./all-local-setup.sh
   kubectl --context kind-seed get applications -n argocd \
     -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
   ```

4. Review the Git diff. Confirm no secrets are included.
5. Push the branch and merge through the normal review path.
6. Let Argo CD reconcile. Do not bypass Git for desired-state changes.

## Rollback process type

Manual Git revert.

## Rollback process

1. Identify the bad commit.
2. Revert it in Git:

   ```bash
   git revert <bad-sha>
   git push
   ```

3. Let Argo CD reconcile the revert.
4. Watch the impacted Applications:

   ```bash
   kubectl get applications -n argocd
   kubectl get application <name> -n argocd -o yaml
   ```

Do not delete namespaces, AppProjects, root Applications, CRDs, encryption keys, or cluster-scoped resources as a rollback shortcut without explicit impact review.

## Failover architecture type

Template: define per real environment.

The generic repository does not provide application data-plane failover by itself. In a production implementation, document:

- active/active or active/passive model;
- cluster, region, and DNS failover boundaries;
- how Argo CD is restored or re-pointed;
- which stateful dependencies must be restored before platform add-ons;
- expected RTO and RPO.

## Failover process type

Template: Manual / PartiallyAutomated / Automated.

## Failover details template

1. Confirm the incident boundary: cluster, region, DNS, IAM, cloud provider, or Git provider.
2. Freeze non-emergency deployments.
3. Restore or provision the target cluster prerequisites.
4. Apply bootstrap CRDs/controllers.
5. Apply the Argo CD root Application.
6. Validate all AppProjects and Applications.
7. Switch ingress/DNS only after health checks pass.
8. Record the exact commit SHA and cluster context used.

## Data recovery process type

Template: PartiallyAutomated.

## Data recovery details template

This repository stores desired state, not application data. Recovery focuses on reconstructing cluster configuration from Git. For real environments, document:

- Git repository restore process;
- Argo CD backup/restore process if Argo CD state is backed up;
- cloud secret manager restore process;
- persistent volume snapshot and restore process;
- certificate/key rotation process after a compromise.

## Key and secret management process type

Externally managed.

## Key and secret management details

- Never commit private keys, tokens, API keys, passwords, kubeconfigs, or decrypted Secret values.
- Use External Secrets or another managed secret system for runtime credentials.
- `local-mocks/` contains fake non-sensitive placeholders for kind validation only.
- Rotate leaked credentials immediately through the approved security process.
- Argo CD repository credentials must be created out-of-band in namespace `argocd`.

Check configured Argo CD repository credentials:

```bash
kubectl get secrets -n argocd \
  -l argocd.argoproj.io/secret-type=repository
```

## Monitoring

Minimum operator checks:

```bash
kubectl get applications -n argocd
kubectl get appprojects -n argocd
kubectl get pods -n argocd
kubectl get pods -A | grep -v Running | grep -v Completed
```

For real environments, add links or commands for:

- metrics dashboards;
- log search;
- alert routes;
- SLOs and error budgets;
- cloud provider health dashboards;
- audit logs.

## Health checks

### Render desired state

```bash
kubectl kustomize . >/tmp/seed-rendered.yaml
grep -c '^kind: Application$' /tmp/seed-rendered.yaml
grep -c '^kind: AppProject$' /tmp/seed-rendered.yaml
```

### Argo CD controllers

```bash
kubectl get pods -n argocd
kubectl get deployments -n argocd
kubectl get statefulsets -n argocd
```

### Applications and projects

```bash
kubectl get applications -n argocd \
  -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project,NAMESPACE:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'

kubectl get appprojects -n argocd
```

Healthy local validation target:

```text
Every Application reports: Synced / Healthy
```

### Root app-of-apps

```bash
kubectl apply -f argocd/root.yaml
kubectl get application cluster-addons -n argocd
```

The root Application uses `path: .` and renders the repository-root `kustomization.yaml`.

## Local kind validation

Fast path:

```bash
./all-local-setup.sh
```

Manual flow:

```bash
kind create cluster --name seed --config kind-config.yaml
kubectl --context kind-seed create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl --context kind-seed apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side
kubectl --context kind-seed patch configmap/argocd-cmd-params-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'
kubectl --context kind-seed apply --server-side -k bootstrap
kubectl --context kind-seed apply -k local-mocks
kubectl --context kind-seed apply -k .
```

Local-only behavior:

- `local-mocks/` seeds fake ConfigMaps and Secrets required by charts.
- `external-dns` uses the in-memory provider for kind validation.
- certificates use the local `selfsigned` issuer.
- Argo CD Gateway health is overridden in local setup because kind has no cloud LoadBalancer controller and Gateway `Programmed` can remain false with `EXTERNAL-IP=<pending>`.

Expected limitations:

- private Git sources fail without repository credentials;
- AWS/cloud-provider resources fail without IAM and cloud APIs;
- cloud load balancers and public DNS records do not work in plain kind;
- storage classes may differ;
- production domains remain placeholders.

## First line troubleshooting

Use this order before changing code.

1. Confirm cluster context:

   ```bash
   kubectl config current-context
   kubectl cluster-info
   ```

2. Confirm the render still works:

   ```bash
   kubectl kustomize . >/tmp/seed-rendered.yaml
   ```

3. Check Argo CD controllers:

   ```bash
   kubectl get pods -n argocd
   kubectl logs -n argocd statefulset/argocd-application-controller --tail=100
   ```

4. Find non-green Applications:

   ```bash
   kubectl get applications -n argocd \
     -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
   ```

5. Inspect one failed Application:

   ```bash
   kubectl get application <name> -n argocd -o yaml
   kubectl get application <name> -n argocd \
     -o jsonpath='{.status.conditions}'
   ```

6. Check workload pods and events:

   ```bash
   kubectl get pods -A | grep -v Running | grep -v Completed
   kubectl describe pod <pod> -n <namespace>
   kubectl get events -n <namespace> --sort-by=.lastTimestamp | tail -40
   ```

7. Hard refresh an Application after pushing Git changes:

   ```bash
   kubectl patch application <name> -n argocd --type merge \
     -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
   ```

## Second line troubleshooting

### Multi-source Helm values

Applications use multi-source values. Verify:

1. the chart source has a Helm/OCI repository URL;
2. the second source has `ref: values`;
3. the second source points to `https://github.com/dxas90/seed` or the intended repository;
4. the chart references `$values/<existing-path>`;
5. the values file parses as YAML.

Render or inspect with Argo CD:

```bash
ARGOCD_OPTS='--core --kube-context kind-seed' argocd app manifests <app>
ARGOCD_OPTS='--core --kube-context kind-seed' argocd app diff <app> --hard-refresh
```

### Project errors

```bash
kubectl get appprojects -n argocd
kubectl get application <name> -n argocd \
  -o jsonpath='{.spec.project}'
```

Every referenced project must exist under `argocd/` and be listed in the root `kustomization.yaml`.

### Sync ordering

```bash
kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave
```

Do not add sync waves unless a real dependency requires them.

### Common failure patterns

| Symptom | Likely cause | First check | Fix |
| - | - | - | - |
| Application `Unknown` with repo-client error | Missing Argo CD repository credentials | repository Secrets in `argocd` | Add repo credential out-of-band |
| `no matches for kind` | Missing CRD/bootstrap prerequisite | `kubectl apply --server-side -k bootstrap` | Apply bootstrap before Applications |
| `ExternalSecret` Degraded in kind | Real cloud secret backend unavailable | `kubectl get externalsecret -A` | Use `local-mocks/` or exclude cloud-backed resource from local render |
| Pod stuck `ContainerCreating` with missing Secret/ConfigMap | Chart references runtime config not seeded | `kubectl describe pod` | Add real secret/config or local mock |
| Gateway Progressing in kind | No cloud LoadBalancer / `EXTERNAL-IP=<pending>` | `kubectl get gateway,svc -A` | Use local Argo CD health override or install a local LB controller |
| Helm values not applied | Bad `$values/...` path or missing `ref: values` | `argocd app manifests <app>` | Fix Application sources/valueFiles |
| `istio-cni` OutOfSync on defaulted DaemonSet fields | Client-side diff against Kubernetes defaults | Application compare options | Use server-side diff, not broad ignoreDifferences |

## Secret handling

- Do not decrypt SOPS files during routine diagnostics.
- Do not print Kubernetes Secret payloads into tickets, logs, docs, summaries, or chat.
- Use External Secrets or another managed secret system for runtime credentials.
- Use `local-mocks/` only for disposable local validation.
- Rotate leaked deploy keys or cloud credentials immediately.

## Change safety

Two-person or explicit-impact review required before deleting or replacing:

- Namespaces;
- Argo CD root Applications;
- AppProjects;
- CRDs;
- ClusterIssuers and webhook configurations;
- KMS/encryption resources;
- cluster-scoped controllers;
- persistent storage resources.

## More information

- `README.md` — repository overview and quick start.
- `FOLLOW_THIS.md` — contributor workflow and conventions.
- `docs/argocd-install.md` — Argo CD install and local validation.
- `docs/architecture.md` — architecture details.
- `docs/migration.md` — Flux-to-Argo migration notes.
- `docs/onboarding.md` — onboarding path for new contributors.

## Migration record

The Flux CRDs and Flux-only composition files have been removed. If behavior differs from the previous deployment, use Git history and `docs/migration.md` to compare the translated Argo CD Application, values, namespace, and ordering rather than restoring Flux resources.
