# Design decisions

The *why* behind this infrastructure. For the resource-level picture see
[architecture.md](architecture.md); for deploy/operations see
[`iac/README.md`](../iac/README.md).

## Goals & constraints

- **Personal-scale.** One owner, low traffic, ~$2/month. Operational simplicity
  and cost beat feature breadth.
- **Everything as code.** All AWS state is reproducible from
  [`iac/`](../iac); nothing clicked into the console by hand.
- **No long-lived credentials.** CI authenticates to AWS via OIDC, never stored
  keys.

## Key decisions

### DNS in Route 53, hosting on Vercel

Route 53 owns the zones because the email pipeline (SES receiving) needs an MX
record in the same authoritative DNS, and Route 53 alias records cleanly handle
the apex → `www` case. Actual website hosting stays on Vercel — it gives free
CDN, TLS, and preview deploys with zero servers to maintain. The apex/`www`
records simply point at Vercel's IP/CNAME. AWS does DNS + email; Vercel does the
app.

### Two domains, one target

`brignano.io` is primary; `anthonybrignano.com` is a backup/vanity domain that
points at the same Vercel app. Both zones are marked `prevent_destroy` — losing
a hosted zone means re-delegating nameservers at the registrar, which is slow
and error-prone, so Terraform is blocked from deleting them.

### Self-hosted email forwarding (SES → S3 → Lambda)

Rather than pay for a mail provider or a SaaS forwarder, incoming mail to
`hi@brignano.io` is received by SES, archived to S3, and forwarded to a personal
Gmail by a small Python Lambda that re-sends via `SendRawEmail`. Rationale:

- **Cost** — SES receiving is free for the first 1,000 emails/month; Lambda and
  S3 are effectively free at this volume.
- **Control & durability** — every message is archived in S3 (versioned,
  encrypted) before forwarding, so nothing is lost if forwarding fails.
- **No mailbox to run** — forwarding to Gmail means no IMAP server, spam stack,
  or webmail to maintain.

Trade-off: it's more moving parts than a managed forwarder, and the Lambda only
forwards plain-text bodies today (see Limitations).

### `noreply@` is bounced, not stored

Mail to `noreply@brignano.io` is rejected at the SES receipt-rule layer (SMTP
550) before touching S3 or Lambda — it should never receive real mail, and
bouncing keeps junk out of the archive and the forwarding path.

### Least-privilege IAM, one role

The Lambda runs under a single role (`LambdaAssumeRole`) with four narrowly
scoped policies — logs, S3 `GetObject` on `emails/*` only, SES `SendRawEmail`,
and SQS `SendMessage` to the DLQ. No wildcards beyond the SES identity ARN. The
S3 bucket policy additionally restricts `PutObject` to the SES service principal
scoped to this account.

### Failure visibility (DLQ + alarm + SNS)

A forwarded email that silently fails to send is worse than a loud error.
Failed Lambda invocations land in an SQS dead-letter queue (14-day retention); a
CloudWatch alarm on DLQ depth > 0 publishes to an SNS topic that emails the
owner. This turns a silent drop into an actionable alert without standing
infrastructure.

### CI/CD via Terraform Cloud + OIDC

Plans run on PRs and applies run on merge to `main`, executed in the
`brignano/aws-config` TFC workspace. AWS access is via an OIDC-assumed role
defined in CloudFormation ([`cloudformation/`](../cloudformation)) — kept
separate from the Terraform that consumes it so the trust anchor can't be
destroyed by a normal apply.

## Cost posture

~$2/month, dominated by the two Route 53 hosted zones ($0.50 each) and the
CloudWatch log group. SES receiving, Lambda, and S3 are within free tier at
personal volume. See the cost table in [`iac/README.md`](../iac/README.md) for
the breakdown.

## Known limitations

- Only the **plain-text** body is forwarded; HTML is stripped.
- **Reply-To / CC / BCC** headers are not preserved.
- Large **attachments** can hit the 30-second Lambda timeout.
- SES starts in **sandbox** mode on new accounts — production access must be
  requested for unrestricted sending.

## Possible future work

- Preserve HTML bodies and Reply-To/CC/BCC headers.
- Proper attachment handling.
- SPF/DKIM/DMARC documentation and records.
- Automated tests for the Lambda handler.
