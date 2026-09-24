# GreenITESO Infra

This repo has two parts:

- **[`neon-db/`](neon-db/README.md)** — Neon Postgres operations docs and tooling (inventory, quotas, roles, recovery, monitoring). This is the actual, currently-used database infrastructure. See its own README for the full index.
- **Terraform (this directory)** — a scaffold for the GCP resources around the app (edge network, Cloud Run, CI/CD, monitoring), matching `GCP Architecture.png`. No GCP project or runtime configuration was available to verify; this is structure, not a deployed environment — see [Status](#status) below.

## Architecture

![GCP reference architecture](./GCP%20Architecture.png)

Summary:

- **Edge**: HTTPS load balancer → Cloud Armor → Cloud CDN → Cloud Run
- **Compute**: Cloud Run runs the fullstack app container
- **Persistence**: the diagram shows Cloud SQL, but **the actual database is Neon Postgres** (external to GCP) — see [`neon-db/docs/neon-inventario.md`](neon-db/docs/neon-inventario.md). There is no Cloud SQL module here. The target mapping is Git/GitHub `dev` → Neon `dev`, `preprod` → `staging`, and `main` → `production`; the final mapping is not active yet. Cloud Storage is real and used for private object evidence (proposal P1).
- **CI/CD & observability**: there is currently no verified migration-gated release path. Backend PR #30 proposes a GitHub Actions gate, but remains a draft and needs environment credentials/configuration; repository/environment Neon secrets were not found, while organization-level secrets could not be inspected. Cloud Run/Secret Manager also need GCP. The Terraform Cloud Build trigger is disabled by default (`github_trigger_enabled = false`) until it invokes the reviewed migration gate. Cloud Monitoring pings the load balancer every minute.
- **Third-party**: Microsoft Entra ID was merged into Backend `dev` in PR #93 on 2026-09-22; deployed runtime status is not verified. It is external and not provisioned here. An email-sender service account is scaffolded for whatever transactional email provider gets chosen later.

## Layout

```
main.tf                    # wires the modules together for one environment
variables.tf                # project_id, environment, container_image, etc. — no secrets
providers.tf / versions.tf   # google/google-beta provider + version pins
outputs.tf                   # service URL, LB IP, bucket name, etc.
terraform.tfvars.example     # copy to terraform.tfvars (gitignored) and fill in
modules/
  network/       # ALB, Cloud Armor, Cloud CDN, serverless NEG
  compute/       # Cloud Run service + runtime service account
  storage/       # Cloud Storage bucket (private object evidence, P1)
  cicd/          # Cloud Build trigger + Cloud Deploy pipeline/target
  monitoring/    # Uptime check (1 min) + alert policy
```

Run this scaffold once **per environment** (`dev`, `staging`, `production`), each with its own `terraform.tfvars` and state backend — `main.tf` does not fan out to all three by itself. The environment value matches the Neon branch and Cloud Run service name (`greeniteso-dev`, `greeniteso-staging`, `greeniteso-production`); the target Git release branches are `dev`, `preprod`, and `main`. The Backend GitHub branch inventory at `37e4809` on 2026-09-10 listed `main` with four deploy workflows; the branch query on 2026-09-24 no longer listed it. The timing and cause of that change are unverified and must be reconciled before enabling the intended `main` release path. The legacy Git `prod` branch still has a `deploy-prod` workflow, gated by `CLOUD_DEPLOYMENT_ENABLED`; repository and environment settings do not define that variable, but organization-level variables could not be inspected. Treat the legacy route as potentially activatable; do not enable it until it has the required database migration gate and production controls.

Before applying the CI/CD Terraform change, inspect the plan against the actual GCP state. With the new default `github_trigger_enabled = false`, applying this configuration can remove a managed `google_cloudbuild_trigger` from existing state even if no one explicitly changes `true` to `false`; changing the target branch from legacy `prod` to `main` may also update/recreate it. GCP state is not configured or inspected yet, so this branch does not prove that no trigger exists. No Terraform apply has been run.

## Status

Nothing in this directory has been applied. Specifically still missing before a real `terraform plan` would succeed:

- No GCP project/configuration was available to verify (`var.project_id` has no default, on purpose)
- No remote state backend is configured (`providers.tf` has no `backend` block — decide GCS backend + bucket before the first real apply)
- No container image has been built/pushed yet
- No Secret Manager secrets exist yet (`DB_APP_POOLED_URL` etc. — see [`neon-db/docs/neon-operations.md`](neon-db/docs/neon-operations.md) T4)
- No domain is owned, so the load balancer's HTTPS listener/cert resources are conditional on `var.domain` and won't be created until one is

The Terraform files pass `terraform fmt -check -recursive` and `terraform validate` using Terraform **1.9.8** with `terraform init -backend=false`; this validates configuration only. No GCP plan or apply has been run.

Treat this the same way the app repos' `_deploy.yml` GCP templates are treated: scaffolding to fill in once there's an actual GCP account, not something to `terraform apply` today.
