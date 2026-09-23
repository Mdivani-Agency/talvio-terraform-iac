# talvio-terraform-iac

Greenfield Terraform for Talvio: **Vercel** (web) + **Supabase** (auth/data) + **AWS** shared services for `email-service` and `media-service`.

This repo is seeded from GitLab [`mdivani-agency/talvio-co/terraform-iac`](https://gitlab.com/mdivani-agency/talvio-co/terraform-iac) (`development` @ `3f1e59f`). Reusable modules are copied **unchanged**. Legacy Dynamo/RDS/Amplify/`auth-proxy-service` are not built and not imported. No GitLab state is copied.

| Env | AWS account | DNS | State |
| --- | --- | --- | --- |
| **dev** | Dedicated account (**D1**, locked) | New hosted zone `dev.talvio.co` (NS-delegated from `talvio.co`) | New S3 bucket `talvio-iac-dev-state` |
| **prod** | Existing prod account | Import live `talvio.co` zone + verified SES (MDI-182) | New S3 bucket `talvio-iac-prod-state` |

Spec: [Terraform IAC (refactor)](https://app.notion.com/p/3daf87a6db578121833bcc1317299f51) · Linear: [MDI-178](https://linear.app/mdivani/issue/MDI-178) / [MDI-179](https://linear.app/mdivani/issue/MDI-179) / [MDI-183](https://linear.app/mdivani/issue/MDI-183)

## Prerequisites

### Accounts and access

1. **Dev (D1).** A dedicated AWS account. The first `bootstrap/` apply still needs an admin principal (IAM user or SSO role). After that, GitHub Actions assumes `talvio-gha-terraform-dev` via OIDC.
2. **Prod.** The existing prod account that already holds zone `talvio.co` / `Z0405368180IU9H5C98FU` and the verified SES identity. Prod apply is [MDI-182](https://linear.app/mdivani/issue/MDI-182); this ticket only prepares the backend config.
3. **DNS.** After the dev zone exists (MDI-180), add NS records for `dev.talvio.co` in the live `talvio.co` zone once.
4. **Vercel / Supabase tokens** (`VERCEL_API_TOKEN`, `SUPABASE_ACCESS_TOKEN`) are required for [MDI-184](https://linear.app/mdivani/issue/MDI-184) plan/apply. OAuth client id/secret are **not** GitHub secrets — they are read from existing SSM `/<env>/auth/{google,linkedin}/client_{id,secret}`.

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

Creates the state bucket **and** the GitHub OIDC provider + IAM roles (MDI-183).

```bash
cd bootstrap
terraform init
terraform apply -var='environment=dev'   # dedicated dev account → talvio-iac-dev-state + OIDC
# later, in the existing prod account:
# terraform apply -var='environment=prod'  # → talvio-iac-prod-state + OIDC
```

Copy `terraform_role_arn` into GitHub (see [CI](#github-actions-and-oidc)). `deploy_role_arn` is also written to SSM `/${env}/ci/deploy-role-arn` for the service repos.

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

ACM validation records sit in the **new** `dev.talvio.co` zone. They will not go `ISSUED` until that zone is NS-delegated from prod `talvio.co` (`Z0405368180IU9H5C98FU`). Do **not** create a second `talvio.co` zone.

```bash
export AWS_PROFILE=talvio-dev   # or let GitHub Actions assume talvio-gha-terraform-dev

terraform init -backend-config=environments/dev.backend.hcl
terraform workspace select dev 2>/dev/null || terraform workspace new dev

# 1. Create the zone first so you can copy name servers.
terraform apply -var-file=variables/dev.tfvars -target=module.dns

# 2. In the existing talvio.co zone, add the four NS records for `dev.talvio.co`
#    from: terraform output hosted_zone_name_servers
#    Wait until `dig NS dev.talvio.co` returns those servers.

# 3. Full platform (certs, media, SES, API keys, SSM).
terraform apply -var-file=variables/dev.tfvars
```

Preferred path after OIDC is set: push to `development` (or Actions → apply / dev). If apply hangs on `aws_acm_certificate_validation`, the NS records are not live yet — finish step 2 and re-run.

Helpers:

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

`main.tf` wires the AWS platform (MDI-180). `app.tf` wires Supabase + the existing Vercel project (MDI-184). OIDC roles are created by `bootstrap/`.

## GitHub Actions and OIDC

Workflow: [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml).

| Event | What runs |
| --- | --- |
| Pull request | `fmt -check`, `validate`, `plan` against **dev** (`variables/dev.tfvars`). Plan is a job summary + `tfplan-dev` artifact. |
| Push to `development`, or `workflow_dispatch` apply/dev | `apply` for **dev**, GitHub Environment `dev` |
| Push to `main`, or `workflow_dispatch` plan\|apply/prod | `plan` then protected `apply` for **prod**, GitHub Environment `prod` (no-op until `prod.tfvars` is filled in MDI-182) |

Concurrency group `terraform-<env>` with `cancel-in-progress: false` so two applies cannot race.

### One-time GitHub setup

1. Apply `bootstrap/` in the target AWS account (above).
2. Create GitHub Environments **`dev`** and **`prod`**. On `prod`, add **required reviewers**.
3. Set repository (or Environment) **variables** (role ARNs only — not trust-policy JSON):
   - `DEV_AWS_ROLE_ARN` = bootstrap output `terraform_role_arn` (`talvio-gha-terraform-dev`)
   - `PROD_AWS_ROLE_ARN` = same output from the prod-account bootstrap (`talvio-gha-terraform-prod`)
4. Repository secrets (MDI-184 plan/apply):
   - `VERCEL_API_TOKEN`
   - `SUPABASE_ACCESS_TOKEN`

   The Auth `send_email` hook secret is **not** a GitHub secret. Terraform generates it (`random_bytes.email_hook_secret`), writes SSM `/${env}/email/hook-secret`, and passes the same value into `supabase_settings.auth.hook_send_email_secrets`. Google / LinkedIn client secrets are read from SSM. The Supabase DB password is generated here and stored at `/${env}/supabase/database_password`.

The Actions job needs `id-token: write`. `aws-actions/configure-aws-credentials` assumes the role via GitHub OIDC (`token.actions.githubusercontent.com`).

Until `DEV_AWS_ROLE_ARN` is set, PR jobs still run fmt/validate and skip the remote plan.

This org uses **immutable OIDC subject claims** (repos created after 15 Jul 2026). A token from Environment `dev` looks like:

```text
repo:Mdivani-Agency@328309464/talvio-terraform-iac@1367138775:environment:dev
```

not `repo:Mdivani-Agency/talvio-terraform-iac:environment:dev`. `bootstrap/oidc.tf` trusts **both** classic and immutable `sub` values (`aud` stays `sts.amazonaws.com`). Numeric ids are pinned in `bootstrap/variables.tf`. After changing trust, re-apply `bootstrap/` in each account so Terraform owns the IAM role (a later apply must not drop the immutable claims).

After merging an OIDC trust change:

```bash
cd bootstrap
terraform apply -var='environment=dev'    # picks up console edits + deploy-role
# when standing up prod (MDI-182):
# terraform apply -var='environment=prod'
# then set PROD_AWS_ROLE_ARN to terraform_role_arn
```

### Service deploy roles

`modules/ci_oidc` is instantiated from `bootstrap/` (not the main root) so the roles exist before the first platform apply.

| Role | Trust | SSM |
| --- | --- | --- |
| `talvio-gha-terraform-<env>` | `talvio-terraform-iac` (`pull_request` + `development` + `environment:dev` on dev; `main` + `environment:prod` on prod), classic **and** immutable `sub`. Attaches `AdministratorAccess` for now. | — |
| `talvio-gha-deploy-<env>` | `talvio-media-service` and `talvio-email-service` (`development` / `main` + `environment:<env>`), classic **and** immutable `sub`. Inline policy covers `sls deploy` (CloudFormation, Lambda, API GW, IAM role CRUD, SSM read, Route53/ACM for `serverless-domain-manager`). | `/${env}/ci/deploy-role-arn` |

Service GitHub Actions (MDI-185 / MDI-186) should:

```yaml
permissions:
  id-token: write
  contents: read
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}   # or SSM /${stage}/ci/deploy-role-arn
    aws-region: us-west-1
```

## Layout

```
versions.tf  backend.tf  providers.tf  main.tf  app.tf  variables.tf  outputs.tf
environments/dev.backend.hcl  environments/prod.backend.hcl
variables/dev.tfvars  variables/prod.tfvars
variables/templates/{magic_link,recovery,invite,email_change,welcome}.html
modules/ssl  modules/api_gateway  modules/s3  modules/dynamodb  modules/ses  modules/ssm
modules/dns  modules/acm          # new (zone + us-west-1 cert; ssl stays us-east-1)
modules/ci_oidc                   # GitHub OIDC IAM role + optional SSM
bootstrap/                        # state bucket + GitHub OIDC provider + CI roles
scripts/plan.sh  scripts/deploy.sh
.github/workflows/terraform.yml
```

Do not copy `modules/rds`, GitLab `terraform.tfstate.d/`, or `environments/.dev.tf` / `.prod.tf`.

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
| TF CI role | `talvio-gha-terraform-dev` |
| Service deploy role | `talvio-gha-deploy-dev` → SSM `/dev/ci/deploy-role-arn` |

## SES templates (MDI-189 contract)

| Template | Placeholders | Subject |
| --- | --- | --- |
| `magic_link` | `token`, `confirmation_url`, `email`, `site_url` | Your Talvio sign-in code |
| `recovery` | same | Reset your Talvio password |
| `invite` | same | You're invited to Talvio |
| `email_change` | `token`, `token_new`, `confirmation_url`, `old_email`, `email`, `site_url` | Confirm your new email on Talvio |
| `welcome` | `name`, `email`, `site_url` | Welcome to Talvio |

No SES SMTP IAM user (D5). Auth hook secret is generated here (`random_bytes.email_hook_secret`) and stored at `/dev/email/hook-secret`. The same resource is passed into Supabase `hook_send_email_secrets` — no `TF_VAR_`.

## App platform (MDI-184)

`enable_app_platform = true` on dev creates hosted Supabase `talvio-dev` and attaches the **existing** Vercel project (`prj_VHE5Mf9O1zmaiA1kDQdRHxWdkEiT`). Terraform does **not** manage `vercel_project`, so apply cannot replace it.

| Thing | Value |
| --- | --- |
| Supabase project | `talvio-dev`, org slug `vxmuczxicfctjtbdfall`, region `us-west-1` |
| Auth mail | HTTPS hook `https://api.dev.talvio.co/email/hooks/send-email` (no `smtp_*`) |
| Auth providers | email OTP + Google + `linkedin_oidc` (client id/secret from SSM `/dev/auth/...`) |
| Vercel domain | `dev.talvio.co` on git branch `development` |
| Apex DNS | A `76.76.21.21` (Vercel anycast; zone apex cannot be a CNAME) |
| Frontend env | `NEXT_PUBLIC_*`, `SUPABASE_SECRET_KEY`, `MEDIA_SERVICE_API_KEY` (generic GW key). Not set: `OPENAI_API_KEY`, `GOOGLE_FONTS_API_KEY` |
| SSM | `/dev/supabase/{url,project_ref,publishable_key,secret_key,database_password}` |

On both Vercel `development` and `preview`, keys starting with `NEXT_PUBLIC_` use `sensitive = false` so the client bundle can inline them. Every other key is `sensitive = true` (D3: previews share `talvio-dev`). Production Vercel env is left untouched until MDI-182.

`VERCEL_API_TOKEN` is a **repository** secret (same token for dev and prod). Do **not** set `provider.vercel.team` — a team-scoped token cannot `GET /v2/teams/{id}` (`team_unauthorized`). Domain and env resources pass `team_id` as a query parameter instead.

After apply:

1. Add the callback `terraform output -raw supabase_oauth_callback_url` (`https://<ref>.supabase.co/auth/v1/callback`) on the Google and LinkedIn OAuth apps.
2. If Vercel already has the same env keys from the dashboard, apply may 409 — delete the dashboard copies (or import) and re-run.
3. Schema / `db-push.yml` stay in `talvio-web-app`. This repo does not write web-app GitHub secrets.
