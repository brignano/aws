# aws

> **Decommissioned 2026-08-23.** This repository no longer manages any AWS
> infrastructure. DNS and inbound email for `brignano.io` and
> `anthonybrignano.com` now run on Cloudflare.

## What happened

DNS authority moved from Route 53 to Cloudflare, and inbound email moved from a
SES → S3 → Lambda forwarder to Cloudflare Email Routing. The full plan, the
verification steps, and the record of what actually happened are in
[docs/tsd-domain-migration-cloudflare.md](docs/tsd-domain-migration-cloudflare.md).

Motivation was Cloudflare Access + Tunnel: publishing homelab services on
Access-protected subdomains requires the domain to be on Cloudflare DNS. Replacing
the email stack was a secondary win — the SES forwarder re-sent messages, which
stripped HTML, dropped attachments, lost CC/BCC and Reply-To, and rewrote the
`From:` header. Email Routing forwards the raw message with ARC sealing and SRS.

## Where things live now

| Concern | Before | Now |
|---|---|---|
| DNS — both domains | Route 53 hosted zones | Cloudflare DNS (Free) |
| Inbound `hi@brignano.io` | SES → S3 → Lambda → SES → Gmail | Cloudflare Email Routing → Gmail |
| `noreply@` | SES bounce rule | Email Routing **Drop** rule |
| Email archive | Versioned S3 bucket | Gmail |
| Failure alerting | SQS DLQ + CloudWatch alarm + SNS | Email Routing Activity Log |
| SPF / DKIM | none | added automatically by Email Routing |
| Website hosting | Vercel | Vercel — **unchanged**, records DNS-only |
| Domain registration | Route 53 Domains | Route 53 Domains — **unchanged** |

Registration and hosting were deliberately left alone. Only DNS authority and
inbound mail moved.

## What is still here

```
.
├── iac/                  # Terraform — declares no resources (see iac/main.tf)
│   ├── main.tf           #   decommission notice + inventory of what was removed
│   ├── locals.tf         #   region only, referenced by provider.tf
│   ├── provider.tf       #   AWS provider + Terraform Cloud backend (aws-config)
│   └── README.md
├── cloudformation/       # Terraform Cloud <-> AWS OIDC. STILL DEPLOYED.
│   ├── template.yml      #   TerraformCloudAssumeRole + OIDC provider
│   └── README.md
└── docs/
    ├── tsd-domain-migration-cloudflare.md   # the migration record
    ├── architecture.md
    └── design.md         # historical design rationale
```

### Why CloudFormation is still deployed

`TerraformCloudAssumeRole` is the credential Terraform Cloud assumes to act in
AWS — including to run the destroy that emptied this workspace. It could not be
removed in the same change. Removing it is a follow-up, and only worth doing if
this workspace is never going to manage AWS resources again.

## Cost

| | Before | After |
|---|---|---|
| Route 53 hosted zones + queries | ~$1.40/mo | $0 |
| SES / Lambda / S3 / CloudWatch | ~$0.53/mo | $0 |
| Cloudflare (DNS, Email Routing) | — | $0 |
| **Total** | **~$1.93/mo** | **$0/mo** |

Domain registration is billed annually by Route 53 Domains and is unaffected.

## If you need to roll back

A snapshot of every Route 53 record as it stood immediately before the migration
is preserved in the TSD's record-inventory table, including the SES verification
token. There were 7 records across 2 zones. Neither domain had DNSSEC or CAA,
which is what made the nameserver change low-risk in the first place.

---

**Maintained by:** Anthony Brignano · **Decommissioned:** 2026-08-23
