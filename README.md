# GreenITESO Infra

This repo has two parts:

- **[`neon-db/`](neon-db/README.md)** — Neon Postgres operations docs and tooling (inventory, quotas, roles, recovery, monitoring). This is the actual, currently-used database infrastructure. See its own README for the full index.
- **Terraform (this directory)** — a scaffold for the GCP resources around the app (edge network, Cloud Run, CI/CD, monitoring), matching `GCP Architecture.png`. GitHub verifies the scaffold; current provider resources and deployment state are unknown — see [Status](#status) below.

**Database readiness — 2026-10-01:** Neon dev/staging have 38 matching migration
records; current Backend dev expects 54. Shared dev seed inconsistencies need
review; PR #30/#34 remain unmerged and shared migrations have not run through
the release pipeline. The authorized [PITR drill](neon-db/docs/evidence/pitr-2026-10-01.md)
passed on disposable copies using #34's verifier; both copies were deleted.
See the [dated readiness evidence](neon-db/docs/evidence/database-readiness-2026-10-01.md)
and [deployment handoff](docs/deployment-handoff-2026-10-01.md) for architecture
changes, the approved `prod` Git target and demo prerequisites.

## Architecture

![GCP reference architecture](./GCP%20Architecture.png)

Summary:

- **Edge**: HTTPS load balancer → Cloud Armor → Cloud CDN → Cloud Run
- **Compute target**: Cloud Run for the app container; deployed runtime unverified
- **Persistence**: the diagram shows Cloud SQL, but **the actual database is Neon Postgres** (external to GCP) — see [`neon-db/docs/neon-inventario.md`](neon-db/docs/neon-inventario.md). There is no Cloud SQL module here. Fernando confirmed on 2026-10-01 the Git targets `dev` → Neon `dev`, `preprod` → `staging`, and `prod` → `production`; the final release path is not active yet. The GitHub Environment remains named `production`. The Cloud Storage module targets private object evidence (proposal P1); live bucket state is unverified.
- **CI/CD & observability**: Backend [PR #30](https://github.com/GreenITESO-Proyecto-Integrador/GreenITESO-Backend/pull/30) is ready for review with green CI, but its migration-gated release path has not run after a protected merge. The four required secrets are configured in each `dev`/`preprod` GitHub Environment; runner authentication is unverified. Cloud Run/Secret Manager require an inventory of existing GCP resources. The Terraform Cloud Build trigger is disabled by default (`github_trigger_enabled = false`) until it invokes the reviewed migration gate. The monitoring scaffold defines a one-minute uptime check; actual monitoring is unverified.
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

Run this scaffold once **per environment** (`dev`, `staging`, `production`), each with its own `terraform.tfvars` and state backend — `main.tf` does not fan out to all three by itself. The environment value matches the Neon branch and Cloud Run service name (`greeniteso-dev`, `greeniteso-staging`, `greeniteso-production`); the approved Git release branches are `dev`, `preprod`, and `prod`. This supersedes the planned `main` cutover described in dated inventory entries. Backend PR30 is published with the reviewed `prod` correction (`33b156e`), still unmerged; the production Environment allowlist now permits `prod`, retaining its reviewer and self-review prevention; protected merges and release acceptance remain pending. The legacy `prod` workflow lacks the canonical migration/digest gate and passes an unsupported environment name; replace it through the reviewed promotion chain before enabling deployment. Organization-level cloud variables remain unverified.

Before applying the CI/CD Terraform change, inspect the plan against the actual GCP state. With the default `github_trigger_enabled = false`, applying this configuration can remove a managed `google_cloudbuild_trigger` from existing state. Changing a previously configured `main` target to `prod` can also affect that trigger. GCP state was not inspected in this audit, so this branch does not prove that no trigger exists. No Terraform apply was run by this audit.

## Status

GitHub establishes an unapplied scaffold at its original commit. Isaac now
reports GCP access through Nicolas, as shared by Fernando on 2026-10-01;
current provider resources remain unverified. Before planning changes, verify these inputs against
the existing account and resources:

- No GCP project/configuration was available to verify (`var.project_id` has no default, on purpose)
- No remote state backend is configured (`providers.tf` has no `backend` block — decide GCS backend + bucket before the first real apply)
- Container image/registry/digest: none verified in the inspected GitHub deployment evidence
- Secret Manager inventory and IAM: unverified (`DB_APP_POOLED_URL` etc. — see [`neon-db/docs/neon-operations.md`](neon-db/docs/neon-operations.md) T4)
- Domain ownership/DNS: unverified; HTTPS listener/cert resources are conditional on `var.domain`

The recorded scaffold checks passed `terraform fmt -check -recursive` and
`terraform validate` using Terraform **1.9.8** with `terraform init -backend=false`;
this validates configuration only. No GCP plan or apply was run by this audit.

Inventory the existing GCP account/resources before completing this scaffold
or enabling the app repos' `_deploy.yml` templates; use the canonical migration
gate rather than activating a second release path.
