# Infrastructure as Code (IaC)

This directory contains Terraform configurations for deploying AWS infrastructure for brignano.io.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Internet Users                              │
└────────────┬────────────────────────────┬───────────────────────────┘
             │                            │
             │ DNS Query                  │ Email to hi@brignano.io
             ▼                            ▼
    ┌────────────────┐          ┌─────────────────┐
    │  Route 53 DNS  │          │   Amazon SES    │
    │  Hosted Zones  │          │ (Email Receipt) │
    └────────┬───────┘          └────────┬────────┘
             │                           │
             │ A/CNAME Records           │ 1. Store Email
             ▼                           ▼
    ┌────────────────┐          ┌─────────────────┐
    │     Vercel     │          │   S3 Bucket     │
    │ (Website Host) │          │ (Email Storage) │
    └────────────────┘          └────────┬────────┘
                                         │
                                         │ 2. Trigger Lambda
                                         ▼
                                ┌─────────────────────┐
                                │  Lambda Function    │
                                │ (Email Forwarder)   │
                                └─────────┬───────────┘
                                         │
                                         │ 3. Forward Email
                                         ▼
                                ┌─────────────────────┐
                                │   Amazon SES        │
                                │ (Send Raw Email)    │
                                └─────────┬───────────┘
                                         │
                                         │ 4. Deliver
                                         ▼
                                ┌─────────────────────┐
                                │  Personal Gmail     │
                                │ (Final Destination) │
                                └─────────────────────┘
                                         │
                                         │ Logs
                                         ▼
                                ┌─────────────────────┐
                                │  CloudWatch Logs    │
                                └─────────────────────┘
```

## Components

### 1. DNS Management (Route 53)

**Resources:**
- `aws_route53_zone.default` - Hosted zone for brignano.io
- `aws_route53_zone.backup` - Hosted zone for anthonybrignano.com
- DNS A and CNAME records pointing to Vercel hosting
- Subdomain records: www (alias), resume (CNAME to Vercel)

**Purpose:** Manages domain name resolution for both primary and backup domains, including subdomain routing.

### 2. Email Service (SES)

**Resources:**
- `aws_ses_domain_identity.primary` - Domain identity verification for brignano.io
- `aws_ses_email_identity.email` - Email identity for forwarding destination
- `aws_ses_receipt_rule_set.primary` - Receipt rule set for processing incoming emails
- `aws_ses_receipt_rule.noreply` - Bounces emails sent to noreply@brignano.io
- `aws_ses_receipt_rule.archive` - Stores emails in S3
- `aws_ses_receipt_rule.forward` - Triggers Lambda for email forwarding

**Purpose:** Receives emails at hi@brignano.io and processes them through receipt rules.

### 3. Email Forwarding (Lambda)

**Resources:**
- `aws_lambda_function.email` - Python 3.12 function that forwards emails
- `aws_lambda_permission.email` - Allows SES to invoke the Lambda function

**Function Details:**
- **Runtime:** Python 3.12
- **Handler:** `forward_email.lambda_handler`
- **Timeout:** 30 seconds
- **Source:** `lambda/forward_email.py`

**Environment Variables:**
- `S3_BUCKET_NAME` - S3 bucket where emails are stored
- `S3_BUCKET_PREFIX` - Prefix path in bucket (emails/)
- `FORWARD_TO_EMAIL` - Destination email address
- `REGION` - AWS region
- `LOG_LEVEL` - Logging verbosity (INFO by default)

**How It Works:**
1. SES triggers Lambda when email arrives at hi@brignano.io
2. Lambda retrieves the raw email from S3
3. Lambda parses the email content and metadata
4. Lambda reformats and sends email via SES to personal Gmail

### 4. Storage (S3)

**Resources:**
- `aws_s3_bucket.email` - Stores incoming emails before forwarding
- `aws_s3_bucket_policy.email` - Allows SES to write email objects

**Purpose:** Provides durable storage for all incoming emails and enables Lambda to retrieve them.

### 5. Identity and Access Management (IAM)

**Resources:**
- `aws_iam_role.email` - Lambda execution role (LambdaAssumeRole)
- `aws_iam_policy.lambda_logs` - Allows Lambda to create CloudWatch logs
- `aws_iam_policy.s3_get_object` - Allows Lambda to read emails from S3
- `aws_iam_policy.send_raw_email` - Allows Lambda to send emails via SES

**Principle of Least Privilege:**
Each IAM policy grants only the minimum permissions required for the Lambda function to operate.

### 6. Monitoring (CloudWatch)

**Resources:**
- `aws_cloudwatch_log_group.email_logs` - Stores Lambda execution logs
- **Retention:** 30 days

**Purpose:** Tracks Lambda function execution, errors, and email forwarding operations.

## File Structure

```
iac/
├── main.tf          # Main resource definitions
├── provider.tf      # Provider and Terraform Cloud configuration
├── locals.tf        # Local variables (domains, IPs, email addresses)
├── data.tf          # Data sources (region, account, archive)
├── outputs.tf       # Output values for reference
├── lambda/
│   ├── forward_email.py    # Email forwarding Lambda function
│   ├── forward_email.zip   # Packaged Lambda deployment (auto-generated)
│   └── requirements.txt    # Python dependencies
└── README.md        # This file
```

## Configuration

### Local Variables (locals.tf)

Update these values in `locals.tf` if you're forking this repo:

```hcl
locals {
  region            = "us-east-1"
  domain_name = {
    default = "brignano.io"          # Primary domain
    backup  = "anthonybrignano.com"  # Secondary domain
  }
  email_address       = "anthonybrignano@gmail.com"  # Forwarding destination
  log_level          = "INFO"                         # Lambda log level
  vercel_ip_address  = "216.198.79.1"                # Vercel A record IP
  vercel_cname_record = "7db213ad1eff704d.vercel-dns-017.com"  # Vercel CNAME
}
```

### Terraform Cloud

This configuration is designed to run in Terraform Cloud:

- **Organization:** brignano
- **Workspace:** aws-config
- **Authentication:** OIDC with AWS (configured via CloudFormation)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform Cloud Account** with workspace configured
3. **Domain Names** registered and ready to transfer to Route 53
4. **Verified Email Address** in SES for forwarding destination
5. **Vercel Project** hosting the website (or alternative hosting)

## Deployment

### Initial Setup

1. **Configure Terraform Cloud workspace variables:**
   - `TFC_AWS_PROVIDER_AUTH`: `true`
   - `TFC_AWS_RUN_ROLE_ARN`: ARN from CloudFormation stack output

2. **Deploy CloudFormation stack first** (see `../cloudformation/README.md`):
   ```bash
   # This sets up OIDC authentication for Terraform Cloud
   ```

3. **Verify SES email address** (manual step):
   - Check email inbox for verification link from AWS SES
   - Click the verification link before deploying

4. **Deploy Terraform configuration:**
   - Push changes to `main` branch
   - GitHub Actions will trigger Terraform Cloud deployment

### Updates

Changes to `iac/**` files automatically trigger:
- **Pull Requests:** `terraform plan` via GitHub Actions
- **Main Branch:** `terraform apply` via GitHub Actions

## Outputs

After deployment, Terraform provides these outputs:

```hcl
output "aws_region"                    # Current AWS region
output "aws_account_id"                # AWS account ID
output "email_forwarding_lambda_arn"   # Lambda function ARN
output "primary_website"               # https://brignano.io
output "primary_hosted_zone_id"        # Route 53 zone ID
output "backup_website"                # https://anthonybrignano.com
output "backup_hosted_zone_id"         # Route 53 backup zone ID
```

## Costs

Estimated monthly costs (as of 2024):

| Service | Usage | Cost |
|---------|-------|------|
| Route 53 | 2 hosted zones | $1.00 |
| Route 53 | ~1M queries/month | $0.40 |
| SES | Receiving emails | Free (first 1,000) |
| SES | Sending emails | $0.10 per 1,000 emails |
| Lambda | ~100 invocations/month | Free (first 1M) |
| S3 | ~1 GB storage | $0.023 |
| CloudWatch | Logs | $0.50 |
| **Total** | | **~$2.03/month** |

*Costs may vary based on actual usage. This is a low-traffic personal website setup.*

## Email Flow Details

### Receiving Email at hi@brignano.io

1. **DNS Configuration:** MX record points to SES inbound endpoint
   ```
   brignano.io. 600 IN MX 10 inbound-smtp.us-east-1.amazonaws.com
   ```

2. **SES Receipt Rules (processed in order):**
   - **noreply rule:** Bounces emails to noreply@brignano.io
   - **archive rule:** Saves email to S3 bucket
   - **forward rule:** Triggers Lambda function

3. **Lambda Processing:**
   - Reads raw email from S3
   - Preserves subject and sender
   - Reformats as new email
   - Sends via SES to Gmail

4. **Verification:** SES requires both sending and receiving email addresses to be verified

### Bouncing noreply@ Emails

Emails sent to `noreply@brignano.io` are automatically rejected with:
- SMTP Reply Code: 550
- Status Code: 5.1.1
- Message: "Mailbox does not exist"

## Terraform State Management

### Importing Existing Resources

If you encounter errors like "resource already exists", you need to import the existing AWS resource into Terraform state.

**Common Error:**
```
Error: creating Route 53 Record: InvalidChangeBatch: [Tried to create resource record set [name='www.anthonybrignano.com.', type='CNAME'] but it already exists]
```

**Solution:**
See the detailed import guide at [`../docs/terraform-import.md`](../docs/terraform-import.md) for step-by-step instructions.

**Quick Import Command:**
```bash
terraform import aws_route53_record.backup_www <ZONE_ID>_www.anthonybrignano.com_CNAME
```

Replace `<ZONE_ID>` with your actual Route 53 hosted zone ID (e.g., `Z03941761P902ZZ5Z2ZNA`).

## Monitoring and Troubleshooting

### CloudWatch Logs

View Lambda execution logs:
```bash
aws logs tail /aws/lambda/email-forwarder --follow
```

Or via AWS Console:
- Navigate to CloudWatch → Log Groups
- Select `/aws/lambda/email-forwarder`
- View recent log streams

### Common Issues

**Issue:** Email not forwarded
- **Check:** SES email verification status
- **Check:** Lambda CloudWatch logs for errors
- **Check:** S3 bucket for email object
- **Verify:** SES sending limits not exceeded

**Issue:** Lambda timeout
- **Check:** S3 object size (large attachments may timeout)
- **Solution:** Increase Lambda timeout (currently 30s)

**Issue:** Permission denied errors
- **Check:** IAM role policies are attached
- **Verify:** Lambda execution role has correct permissions

### Testing Email Forwarding

Send a test email:
```bash
echo "Test email body" | mail -s "Test Subject" hi@brignano.io
```

Check CloudWatch logs within 1-2 minutes for processing status.

## Security Considerations

### Current Security Measures

1. **IAM Least Privilege:** Each component has minimal required permissions
2. **S3 Bucket Policy:** Restricts SES access using account ID condition
3. **Email Verification:** Prevents unauthorized email forwarding
4. **CloudWatch Logging:** Audit trail for all email operations
5. **Private S3 Bucket:** Email storage is not publicly accessible

### Security Best Practices

1. **Enable S3 Encryption:** Consider enabling S3 bucket encryption at rest
2. **Enable S3 Versioning:** Protect against accidental deletion
3. **Review SES Sending Limits:** Monitor bounce and complaint rates
4. **Rotate Credentials:** Use OIDC instead of long-term AWS credentials
5. **Monitor CloudWatch Alarms:** Set up alerts for Lambda errors

## Known Limitations

1. **Reply-To Header:** Not currently preserved (see TODO in `lambda/forward_email.py`)
2. **CC/BCC Headers:** Not currently forwarded (see TODO)
3. **Attachments:** Limited by Lambda 30-second timeout for large files
4. **HTML Emails:** Only plain text body is forwarded
5. **SES Sandbox:** Must request production access for unrestricted sending

## Future Enhancements

- [ ] Preserve Reply-To, CC, and BCC headers
- [ ] Support HTML email content
- [ ] Add attachment handling
- [ ] Implement email filtering rules
- [ ] Add CloudWatch alarms for failures
- [ ] Enable S3 bucket encryption
- [ ] Add SPF/DKIM/DMARC configuration documentation

## References

- [AWS SES Email Receiving](https://docs.aws.amazon.com/ses/latest/dg/receiving-email.html)
- [AWS Lambda with Python](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [SES Email Forwarding Example](https://github.com/aws-samples/aws-lambda-ses-forwarder)
