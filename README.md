# GreenITESO Infra

This repo has two parts:

- **[`neon-db/`](neon-db/README.md)** — Neon Postgres operations docs and tooling (inventory, quotas, roles, recovery, monitoring). This is the actual, currently-used database infrastructure. See its own README for the full index.
- **Terraform (this directory)** — a scaffold for the GCP resources around the app (edge network, Cloud Run, CI/CD, monitoring), matching `GCP Architecture.png`. **No GCP project exists yet.** This is structure, not a deployed environment — see [Status](#status) below.

## Architecture

![GCP reference architecture](./GCP%20Architecture.png)

Summary:

- **Edge**: HTTPS load balancer → Cloud Armor → Cloud CDN → Cloud Run
- **Compute**: Cloud Run runs the fullstack app container
- **Persistence**: the diagram shows Cloud SQL, but **the actual database is Neon Postgres** (external to GCP) — see [`neon-db/docs/neon-inventario.md`](neon-db/docs/neon-inventario.md). `modules/database` (Cloud SQL) exists only for shape parity with the diagram and is off by default (`enable_cloud_sql = false`). Cloud Storage is real and used for private object evidence (proposal P1).
- **CI/CD & observability**: GitHub → Cloud Build → Cloud Deploy promotes to Cloud Run; Cloud Monitoring pings the load balancer every minute.
- **Third-party**: Firebase Authentication (OIDC/JWT) is the agreed auth provider — it's not provisioned here, it's external. An email-sender service account is scaffolded for whatever transactional email provider gets chosen later.

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
  database/      # Cloud SQL (disabled by default — see Persistence above)
  storage/       # Cloud Storage bucket (private object evidence, P1)
  cicd/          # Cloud Build trigger + Cloud Deploy pipeline/target
  monitoring/    # Uptime check (1 min) + alert policy
```

Run this scaffold once **per environment** (`dev`, `staging`, `production`), each with its own `terraform.tfvars` and state backend — `main.tf` does not fan out to all three by itself. `environment` here matches the Neon branch / Cloud Run service naming (`greeniteso-dev/staging/prod`); the app repos' Git promote-pipeline branches are named `dev`/`preprod`/`prod` — `modules/cicd`'s `trigger_branch` bridges that naming difference (see the comment in `main.tf`).

## Status

Nothing in this directory has been applied. Specifically still missing before a real `terraform plan` would succeed:

- No GCP project exists (`var.project_id` has no default, on purpose)
- No remote state backend is configured (`providers.tf` has no `backend` block — decide GCS backend + bucket before the first real apply)
- No container image has been built/pushed yet
- No Secret Manager secrets exist yet (`DB_APP_POOLED_URL` etc. — see [`neon-db/docs/neon-operations.md`](neon-db/docs/neon-operations.md) T4)
- No domain is owned, so the load balancer's HTTPS listener/cert resources are conditional on `var.domain` and won't be created until one is

Treat this the same way the app repos' `_deploy.yml` GCP templates are treated: scaffolding to fill in once there's an actual GCP account, not something to `terraform apply` today.
