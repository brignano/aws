# Terraform — `aws-config` workspace

> **This workspace declares no resources.** Decommissioned 2026-08-23; the
> `terraform apply` on that change destroyed all 39 previously managed resources.

## Files

| File | Purpose |
|---|---|
| `main.tf` | Decommission notice and an inventory of what was removed. No resources. |
| `locals.tf` | `region` only — retained because `provider.tf` references it. |
| `provider.tf` | AWS provider and the Terraform Cloud backend (`brignano/aws-config`). |

## Why the workspace still exists

Emptied rather than deleted, so the destroy is recorded in state history and in
this repository rather than happening out of band. The Terraform Cloud workspace
`brignano/aws-config` now manages zero resources.

## CI/CD

| Workflow | Trigger | Effect |
|---|---|---|
| `plan.yml` | pull requests touching `iac/**` | `terraform plan`, output posted to the PR |
| `apply.yml` | pushes to `main` touching `iac/**` | `terraform apply` with **auto-approve** |
| `aws-setup.yml` | pushes to `main` touching `cloudformation/template.yml` | deploys the OIDC CloudFormation stack |

**`apply.yml` auto-approves.** Any future change under `iac/**` merged to `main`
applies immediately with no review gate beyond the PR itself. Read the `plan.yml`
output on the PR before merging — that plan output is the only checkpoint.

Note the path filters: changes outside `iac/**` do not trigger an apply, which is
why documentation-only PRs to this repository are safe.

## If you bring this workspace back

The AWS side of the OIDC trust (`TerraformCloudAssumeRole`, defined in
`../cloudformation/template.yml`) is still deployed, so authentication still
works. Its IAM policy still grants Route 53, SES, Lambda, S3, CloudWatch, SQS,
SNS, and IAM permissions — scope that down to whatever is actually needed rather
than inheriting the old grants.

## What used to be here

Route 53 hosted zones for `brignano.io` and `anthonybrignano.com` plus 7 records;
SES domain and email identities with a 3-rule receipt rule set (bounce, archive,
forward); an `email-forwarder` Lambda in Python 3.12 with an IAM role and 4 scoped
policies; a versioned, AES256-encrypted S3 bucket archiving inbound mail; and an
SQS dead-letter queue, SNS topic and subscription, CloudWatch metric alarm and log
group for failure alerting.

See [`../docs/architecture.md`](../docs/architecture.md) for diagrams of both the
old and current architectures, and
[`../docs/tsd-domain-migration-cloudflare.md`](../docs/tsd-domain-migration-cloudflare.md)
for the migration record.
