# talvio-terraform-iac

Greenfield Terraform for Talvio: **Vercel** (web) + **Supabase** (auth/data) + **AWS** shared services for `email-service` and `media-service`.

This repo is seeded from GitLab [`mdivani-agency/talvio-co/terraform-iac`](https://gitlab.com/mdivani-agency/talvio-co/terraform-iac) (`development` @ `3f1e59f`). Reusable modules are copied **unchanged**. Legacy Dynamo/RDS/Amplify/`auth-proxy-service` are not built and not imported. No GitLab state is copied.

| Env | AWS account | DNS | State |
| --- | --- | --- | --- |
| **dev** | Dedicated account (**D1**, locked) | New hosted zone `dev.talvio.co` (NS-delegated from `talvio.co`) | New S3 bucket `talvio-iac-dev-state` |
| **prod** | Existing prod account | Import live `talvio.co` zone + verified SES (MDI-182) | New S3 bucket `talvio-iac-prod-state` |

Spec: [Terraform IAC (refactor)](https://app.notion.com/p/3daf87a6db578121833bcc1317299f51) · Linear: [MDI-178](https://linear.app/mdivani/issue/MDI-178) / [MDI-179](https://linear.app/mdivani/issue/MDI-179)

## Prerequisites

### Accounts and access

1. **Dev (D1).** A dedicated AWS account. Terraform and the AWS CLI must assume a role (or user) in that account that can create S3, Route53, ACM, API Gateway, DynamoDB, SES, SSM, and CloudFront. GitHub OIDC roles land in [MDI-183](https://linear.app/mdivani/issue/MDI-183).
2. **Prod.** The existing prod account that already holds zone `talvio.co` / `Z0405368180IU9H5C98FU` and the verified SES identity. Prod apply is [MDI-182](https://linear.app/mdivani/issue/MDI-182); this ticket only prepares the backend config.
3. **DNS.** After the dev zone exists (MDI-180), add NS records for `dev.talvio.co` in the live `talvio.co` zone once.
4. **Vercel / Supabase tokens** are not required until [MDI-184](https://linear.app/mdivani/issue/MDI-184). Providers are declared now so the lockfile stays stable.

### Tooling

- Terraform `~> 1.11` (native S3 `use_lockfile`, no DynamoDB lock table)
- AWS CLI v2, credentials for the target account
- `jq` optional

```bash
# macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

## One-time: create the state bucket

The main root uses a **partial** S3 backend (`backend "s3" {}`). The bucket must exist **before** `terraform init` with a backend config. Create it once per account with the tiny `bootstrap/` root (local state) **or** the CLI.

### Option A — `bootstrap/`

```bash
cd bootstrap
terraform init
terraform apply -var='environment=dev'   # dedicated dev account → talvio-iac-dev-state
# later, in the existing prod account:
# terraform apply -var='environment=prod'  # → talvio-iac-prod-state
```

### Option B — AWS CLI

```bash
ENV=dev   # or prod
BUCKET="talvio-iac-${ENV}-state"
REGION=us-west-1

aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Do **not** reuse the legacy buckets `talvio-iac-*-state-bucket`.

## Init, workspace, plan, apply

Backend configs: `environments/dev.backend.hcl` and `environments/prod.backend.hcl` (`use_lockfile = true`).

### Dev (dedicated account)

```bash
export AWS_PROFILE=talvio-dev   # or whatever role/profile points at the dedicated account

terraform init -backend-config=environments/dev.backend.hcl
terraform workspace select dev 2>/dev/null || terraform workspace new dev

# After MDI-180 wires modules:
terraform plan  -var-file=variables/dev.tfvars -out=tfplan
terraform apply tfplan
```

Helpers (same sequence):

```bash
chmod +x scripts/plan.sh scripts/deploy.sh
./scripts/plan.sh dev
./scripts/deploy.sh
```

### Prod (existing account, later)

```bash
export AWS_PROFILE=talvio-prod

terraform init -reconfigure -backend-config=environments/prod.backend.hcl
terraform workspace select prod 2>/dev/null || terraform workspace new prod
terraform plan  -var-file=variables/prod.tfvars
```

`variables/prod.tfvars` is a stub until MDI-182.

### Validate without AWS (CI / local syntax check)

The S3 backend is not contacted:

```bash
terraform init -backend=false
terraform validate
```

`main.tf` is intentionally empty in this ticket — modules live under `modules/` and are wired in MDI-180.

## Layout

```
versions.tf  backend.tf  providers.tf  main.tf  variables.tf  outputs.tf
environments/dev.backend.hcl  environments/prod.backend.hcl
variables/dev.tfvars  variables/prod.tfvars
variables/templates/magic_link.html
modules/ssl  modules/api_gateway  modules/s3  modules/dynamodb  modules/ses  modules/ssm
bootstrap/                    # one-off state bucket
scripts/plan.sh  scripts/deploy.sh
```

New modules (`dns`, `supabase`, `vercel`, `ci_oidc`) arrive in later tickets. Do not copy `modules/rds`, GitLab `terraform.tfstate.d/`, or `environments/.dev.tf` / `.prod.tf`.

## Naming (dev)

| Thing | Value |
| --- | --- |
| Hosted zone | `dev.talvio.co` |
| API | `api.dev.talvio.co` |
| Media CDN | `media.dev.talvio.co` |
| Media bucket | `talvio-media-dev` |
| SES from | `no-reply@dev.talvio.co` |
| State | `talvio-iac-dev-state`, workspace `dev` |
| Region | `us-west-1` |
