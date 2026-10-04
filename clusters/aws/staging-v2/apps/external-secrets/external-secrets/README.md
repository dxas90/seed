# External Secrets (AWS - Parameter Store) Setup

This folder deploys the External Secrets operator and a `ClusterSecretStore` that uses AWS Systems Manager Parameter Store.

Pre-reqs

- Your EKS cluster has an OIDC provider (IRSA) associated (`eksctl utils associate-iam-oidc-provider` or via console).
- `aws` CLI is configured & authenticated to the target AWS account.

Files in this folder

- `external-secrets-trust-policy.json` — trust policy for the role (allow OIDC web identity from the cluster’s service account).
- `external-secrets-policy.json` — IAM policy allowing read access to `arn:aws:ssm:region:account:parameter/seed/*`.
- `helmrelease.yaml` — HelmRelease for external-secrets. The default values include `serviceAccount.annotations.eks.amazonaws.com/role-arn` with the role ARN; update if needed.
- `clustersecretstore-aws-paramstore.yaml` — Example ClusterSecretStore for Parameter Store with JWT/ServiceAccount auth.

Create IAM role & policy (example)

1. Create the role using the trust policy (this allows the service account to assume the role via IRSA):

```bash
aws iam create-role \
  --role-name seed-${ENV_SLUG:-staging-us}-ES-role \
  --assume-role-policy-document file://$(pwd)/clusters/aws/stg/apps/external-secrets/external-secrets/external-secrets-trust-policy.json \
  --description "IAM role for external-secrets operator to access AWS Parameter Store"
```

Example role creation output will show the role ARN (use it in HelmRelease annotations):

```json
{
  "Role": {
    "Arn": "arn:aws:iam::<ACCOUNT_ID>:role/ES-role",
    "RoleName": "ES-role",
    ...
  }
}
```

1. Create the policy granting read access to Parameter Store for the `seed/*` path:

```bash
aws iam create-policy \
  --policy-name seed-${ENV_SLUG:-staging-us}-ES-parameter-store-policy \
  --policy-document file://$(pwd)/clusters/aws/stg/apps/external-secrets/external-secrets/external-secrets-policy.json \
  --description "Allow external-secrets to read SSM parameters for seed"
```

1. Attach the policy to the role:

```bash
aws iam attach-role-policy \
  --role-name seed-${ENV_SLUG:-staging-us}-ES-role \
  --policy-arn arn:aws:iam::000000000000:policy/seed-${ENV_SLUG:-staging-us}-ES-parameter-store-policy
```

1. Update HelmRelease (if needed)

- The repo’s `helmrelease.yaml` already annotates the service account with the role ARN:

`serviceAccount.annotations.eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/seed-${ENV_SLUG:-staging-us}-ES-role`

- If you created a role in a different AWS account or region, update this value.

1. Verify

Check the `ClusterSecretStore` usage and the ExternalSecrets resources you create in your cluster (`kubectl -n external-secrets get externalsecret`).
Read operator logs for permission errors: `kubectl -n external-secrets logs deploy/external-secrets`.

Notes & Security

- Replace `<ACCOUNT_ID>` with your AWS account ID.
- The provided policy is intentionally scoped to `arn:aws:ssm:us-east-2:000000000000:parameter/seed/*`. For your account/region, update `external-secrets-policy.json` accordingly.
- Do not commit AWS credentials or ARNs with production secrets; use SOPS/ExternalSecrets for secure storage.

Lifecycle / Secret retention

- The ExternalSecret `target.creationPolicy` controls creation & ownership of the generated Secret:
  - `Owner` — sets an OwnerReference on the generated Secret so deleting the ExternalSecret also deletes the Secret.
  - `Merge` — does not create an OwnerReference; the Secret remains after ExternalSecret deletion (use this if you want to keep the secret).
