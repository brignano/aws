# aws

> **Retired.** This repository no longer manages any infrastructure. It is kept as
> the historical record of the AWS setup that served `brignano.io` from 2020 to
> August 2026, and of the migration that replaced it.

## What happened

DNS and inbound email for `brignano.io` and `anthonybrignano.com` moved from AWS to
Cloudflare on 2026-08-23. The full plan, the verification steps, and the record of
what actually happened are in
[docs/tsd-domain-migration-cloudflare.md](docs/tsd-domain-migration-cloudflare.md).

## Where things are now

| Concern | Now |
|---|---|
| DNS, both domains | Cloudflare DNS (Free) — managed in the Cloudflare dashboard |
| Inbound `hi@brignano.io` | Cloudflare Email Routing → Gmail, with SPF and DKIM |
| Website | Vercel — unchanged throughout, records DNS-only |
| Domain registration | Route 53 Domains — **unchanged**, billed annually |

## What is left in AWS

Only the two domain registrations. Everything else — Route 53 hosted zones, SES,
Lambda, S3, SQS, SNS, CloudWatch, the IAM role and policies, the Terraform Cloud
OIDC trust, and the `aws-config` workspace — has been destroyed.

## Why the automation was removed

With zero resources to manage, the Terraform Cloud workspace and its OIDC trust were
pure standing risk: `TerraformCloudAssumeRole` granted 90 IAM actions across S3, IAM,
SNS, Lambda, SQS, SES, CloudWatch and Route 53 — including `iam:CreateRole`,
`iam:CreatePolicy`, `iam:AttachRolePolicy` and `iam:PassRole`, which are
privilege-escalation capable — to a role assumable from outside the account via OIDC,
protecting nothing.

Deleting it removes that surface entirely. If AWS is ever needed again, rebuild the
trust scoped to whatever is actually required rather than inheriting these grants.

## Contents

```
docs/
├── tsd-domain-migration-cloudflare.md   # the migration record
├── architecture.md                      # before/after diagrams
└── design.md                            # historical design rationale
```

---

**Retired:** 2026-08-23
