################################################################################
# DECOMMISSIONED — 2026-08-23
#
# This workspace no longer manages any AWS resources.
#
# DNS for brignano.io and anthonybrignano.com moved to Cloudflare, and inbound
# email moved from the SES -> S3 -> Lambda forwarder to Cloudflare Email Routing.
# See ../docs/tsd-domain-migration-cloudflare.md for the full migration record.
#
# What used to live here (39 resources, all destroyed by this change):
#   - Route 53 hosted zones for both domains, plus 7 records
#   - SES domain/email identities, receipt rule set and 3 receipt rules
#   - email-forwarder Lambda (Python 3.12) + IAM role and 4 scoped policies
#   - S3 bucket archiving inbound mail (versioned, AES256) + 5 config resources
#   - SQS dead-letter queue, SNS topic + subscription, CloudWatch alarm and log group
#
# NOTE: destroying the Route 53 *hosted zones* does not affect domain
# *registration*. Both domains remain registered via Route 53 Domains; only their
# nameservers point at Cloudflare.
#
# The Terraform Cloud <-> AWS OIDC plumbing in ../cloudformation/ is intentionally
# left in place: TerraformCloudAssumeRole is the credential this destroy runs as,
# so it cannot be removed in the same change. Remove it in a follow-up once this
# apply has completed cleanly.
################################################################################
