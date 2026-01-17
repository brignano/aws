# aws

AWS infrastructure for brignano.io - personal website hosting, email forwarding, and DNS management.

## Overview

This repository contains Infrastructure as Code (IaC) for deploying and managing the brignano.io domain and related AWS services. It uses Terraform for infrastructure provisioning and CloudFormation for AWS authentication setup.

## Quick Links

- 📖 [Infrastructure Documentation](iac/README.md) - Detailed Terraform configuration guide
- 🔧 [CloudFormation Setup](cloudformation/README.md) - OIDC authentication configuration
- 📋 [Design Document](docs/design.md) - Architecture and design decisions
- 🔄 [Terraform Import Guide](docs/terraform-import.md) - How to import existing AWS resources

## Architecture

```
Internet → Route 53 → CloudFront → Vercel (Website)
                    ├─ / → Main Vercel deployment
                    └─ /resume/* → Resume Vercel deployment
          └→ SES → S3 → Lambda → SES → Gmail (Email Forwarding)
```

**What's Provisioned:**
- **Route 53 DNS** - Manages brignano.io and anthonybrignano.com domains
- **CloudFront CDN** - Distribution with path-based routing for resume site
- **ACM Certificate** - SSL/TLS certificate for HTTPS on brignano.io
- **Amazon SES** - Receives emails at hi@brignano.io and forwards them
- **AWS Lambda** - Python function that processes and forwards emails
- **S3 Storage** - Archives all incoming emails
- **IAM Roles** - Secure permissions for Lambda execution
- **CloudWatch** - Logs and monitoring

## Repository Structure

```
.
├── iac/                         # Terraform Infrastructure as Code
│   ├── main.tf                  # Main resource definitions
│   ├── provider.tf              # AWS provider and Terraform Cloud config
│   ├── locals.tf                # Local variables
│   ├── data.tf                  # Data sources
│   ├── outputs.tf               # Output values
│   ├── lambda/                  # Email forwarding Lambda function
│   │   ├── forward_email.py     # Python Lambda handler
│   │   └── requirements.txt     # Python dependencies
│   └── README.md                # Detailed IaC documentation
├── cloudformation/              # CloudFormation templates
│   ├── template.yml             # OIDC provider setup for Terraform Cloud
│   └── README.md                # CloudFormation setup guide
├── docs/                        # Additional documentation
│   ├── design.md                # Architecture design decisions
│   └── terraform-import.md      # Import existing resources guide
├── .github/workflows/           # CI/CD pipelines
│   ├── plan.yml                 # Terraform plan on PRs
│   ├── apply.yml                # Terraform apply on main branch
│   └── aws-setup.yml            # CloudFormation deployment
└── readme.md                    # This file
```

## Features

### 1. Domain Management
- **Primary Domain:** brignano.io → Points to CloudFront distribution
- **CloudFront CDN:** 
  - Default path (/) → Main Vercel deployment
  - /resume/* → Resume Vercel deployment (same-origin navigation)
- **Backup Domain:** anthonybrignano.com → Also points to Vercel
- **DNS Provider:** AWS Route 53 for reliable DNS resolution
- **SSL/TLS:** ACM certificate for HTTPS on brignano.io
- **Subdomains:**
  - www.brignano.io → Alias to brignano.io (via CloudFront)
  - resume.brignano.io → Points to Vercel hosting (separate deployment, maintained for backward compatibility)
  - www.anthonybrignano.com → Points to Vercel hosting

### 2. Email Forwarding
- **Receive Email:** hi@brignano.io
- **Forward To:** Personal Gmail account (configured in `locals.tf`)
- **Storage:** All emails archived in S3 bucket
- **No-Reply Handling:** Emails to noreply@brignano.io are automatically bounced

### 3. Infrastructure as Code
- **Terraform** manages all AWS resources
- **Version Control** for infrastructure changes
- **CI/CD** via GitHub Actions and Terraform Cloud
- **Automated Deployment** on merge to main branch

### 4. Security & Authentication
- **OIDC Authentication:** Keyless AWS access from Terraform Cloud
- **IAM Least Privilege:** Minimal permissions for each component
- **No Stored Credentials:** Uses temporary credentials via OIDC
- **Audit Logs:** CloudWatch logs for all operations

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **AWS Account** with administrative access
2. **Terraform Cloud Account** 
   - Organization: `brignano`
   - Workspace: `aws-config`
3. **Domain Names** 
   - Registered and ready to configure nameservers
4. **GitHub Repository Access**
   - Able to configure secrets and run workflows
5. **Vercel Project** (or alternative hosting)
   - For website hosting
6. **Email Account**
   - Gmail or other for receiving forwarded emails

## Getting Started

### Initial Setup (One-Time)

1. **Deploy CloudFormation Stack** (OIDC Provider for Terraform Cloud):
   ```bash
   # This is automated via GitHub Actions
   # See cloudformation/README.md for details
   ```

2. **Configure Terraform Cloud Workspace:**
   - Set `TFC_AWS_PROVIDER_AUTH` = `true`
   - Set `TFC_AWS_RUN_ROLE_ARN` = (ARN from CloudFormation output)

3. **Update Configuration:**
   - Edit `iac/locals.tf` with your domains, email, and Vercel settings

4. **Verify SES Email:**
   - Check your forwarding destination email for AWS SES verification
   - Click the verification link

5. **Deploy Infrastructure:**
   - Push changes to `main` branch
   - GitHub Actions triggers Terraform Cloud apply

### For Development

For making infrastructure changes:

1. **Create a Branch:**
   ```bash
   git checkout -b feature/my-change
   ```

2. **Make Changes:**
   - Edit files in `iac/` directory

3. **Open Pull Request:**
   - GitHub Actions runs `terraform plan`
   - Review the plan in the PR comment

4. **Merge to Main:**
   - GitHub Actions runs `terraform apply`
   - Infrastructure is updated automatically

## Configuration

### Customizing for Your Use

To adapt this repository for your own use:

1. **Update `iac/locals.tf`:**
   ```hcl
   locals {
     domain_name = {
       default = "yourdomain.com"
       backup  = "yourbackup.com"
     }
     email_address       = "your-email@gmail.com"
     vercel_ip_address   = "your-vercel-ip"
     vercel_cname_record = "your-vercel-cname"
   }
   ```

2. **Update CloudFormation `template.yml`:**
   - Change hosted zone IDs to match your domains
   - Update organization/workspace names

3. **Update GitHub Secrets:**
   - `TF_API_TOKEN` - Terraform Cloud API token
   - `AWS_ASSUME_ROLE_ARN` - IAM role ARN for GitHub Actions

## Cost Estimate

Estimated monthly costs for running this infrastructure:

| Service | Usage | Monthly Cost |
|---------|-------|-------------|
| Route 53 Hosted Zones | 2 zones | $1.00 |
| Route 53 Queries | ~1M queries | $0.40 |
| CloudFront Distribution | ~10GB data transfer, ~100k requests | $1.00 |
| ACM Certificate | 1 certificate | Free |
| SES Receiving | First 1,000 emails | Free |
| SES Sending | ~100 emails | $0.01 |
| Lambda | ~100 invocations | Free |
| S3 Storage | ~1 GB | $0.02 |
| CloudWatch Logs | 1 log group, 30-day retention | $0.50 |
| **Total** | | **~$2.93/month** |

*Actual costs may vary. Free tier covers Lambda and most SES usage for low-volume personal use.*

## Troubleshooting

### Common Issues

**Issue:** `Error: creating Route 53 Record: InvalidChangeBatch: resource already exists`
- **Solution:** Import the existing resource into Terraform state
- **Guide:** See [docs/terraform-import.md](docs/terraform-import.md)

**Issue:** Email not being forwarded
- **Check:** SES email verification status
- **Check:** Lambda CloudWatch logs: `/aws/lambda/email-forwarder`
- **Check:** S3 bucket for incoming email objects
- **Verify:** SES sending limits not exceeded

**Issue:** Lambda timeout errors
- **Cause:** Large email attachments
- **Solution:** Increase timeout in `iac/main.tf` (currently 30s)

**Issue:** Terraform Cloud authentication fails
- **Check:** CloudFormation stack deployed successfully
- **Check:** `TFC_AWS_RUN_ROLE_ARN` variable set correctly
- **Verify:** OIDC provider thumbprint is current

### Viewing Logs

**Lambda Execution Logs:**
```bash
aws logs tail /aws/lambda/email-forwarder --follow
```

**Terraform Cloud Runs:**
- https://app.terraform.io/app/brignano/workspaces/aws-config/runs

**CloudFormation Stack:**
- AWS Console → CloudFormation → TerraformAssumeRoleSetup

## CI/CD Pipeline

### GitHub Actions Workflows

1. **`plan.yml`** - Runs on Pull Requests
   - Uploads configuration to Terraform Cloud
   - Runs `terraform plan`
   - Comments plan output on PR

2. **`apply.yml`** - Runs on Push to Main
   - Uploads configuration to Terraform Cloud
   - Runs `terraform apply`
   - Automatically confirms and applies changes

3. **`aws-setup.yml`** - Deploys CloudFormation
   - Runs when `cloudformation/template.yml` changes
   - Uses OIDC to authenticate with AWS
   - Deploys/updates the TerraformAssumeRoleSetup stack

### Deployment Flow

```
Developer → Git Push → GitHub → Terraform Cloud → AWS
             │
             ├─ PR: terraform plan (review)
             └─ Main: terraform apply (deploy)
```

## Security Considerations

### Current Security Measures

1. ✅ **IAM Least Privilege** - Each component has minimal permissions
2. ✅ **OIDC Authentication** - No long-term AWS credentials stored
3. ✅ **Private S3 Bucket** - Email storage not publicly accessible
4. ✅ **SES Verification** - Prevents unauthorized email forwarding
5. ✅ **CloudWatch Logging** - Audit trail for all operations
6. ✅ **Terraform Cloud** - State files encrypted and secured

### Security Best Practices

- 🔒 Enable MFA on AWS root account
- 🔒 Regularly review IAM permissions
- 🔒 Monitor CloudWatch logs for suspicious activity
- 🔒 Keep Terraform providers up to date
- 🔒 Review SES bounce and complaint rates
- 🔒 Consider enabling S3 bucket versioning
- 🔒 Consider enabling S3 server-side encryption

## Known Limitations

- **Email Format:** Only plain text emails are forwarded (HTML stripped)
- **Large Attachments:** May timeout (30-second Lambda limit)
- **Reply-To Header:** Not currently preserved in forwarded emails
- **CC/BCC:** Not forwarded to destination
- **SES Sandbox:** New AWS accounts require production access request

## Future Enhancements

- [ ] Support HTML email forwarding
- [ ] Preserve Reply-To, CC, BCC headers
- [ ] Handle email attachments properly
- [ ] Add email filtering/spam detection
- [ ] CloudWatch alarms for Lambda failures
- [ ] S3 bucket encryption at rest
- [ ] SPF/DKIM/DMARC documentation
- [ ] Automated testing for Lambda function
- [ ] Cost monitoring and alerts

## Support & Contribution

This is a personal infrastructure repository. If you're using it as a template:

1. Fork the repository
2. Update configuration for your domains and email
3. Deploy to your own AWS account
4. Customize as needed

## License

See individual file headers for license information.

### IaC Folder (Legacy Documentation)

*Note: This section is maintained for backward compatibility. See [iac/README.md](iac/README.md) for current documentation.*

Terraform configuration for:
- **Route 53**: DNS zones for `brignano.io` and `anthonybrignano.com` with A records pointing to Vercel
- **SES (Simple Email Service)**: Email identity verification and receipt rules for `hi@brignano.io`
- **Lambda**: Email forwarding function that processes incoming emails and forwards them to your primary email
- **S3**: Email storage bucket for archiving incoming messages
- **IAM**: Roles and policies for Lambda to access S3 and send emails via SES
- **CloudWatch**: Logging for Lambda execution

### CloudFormation Folder (Legacy Documentation)

*Note: This section is maintained for backward compatibility. See [cloudformation/README.md](cloudformation/README.md) for current documentation.*

CloudFormation template for setting up GitHub Actions OIDC authentication with AWS:
- **OIDC Provider**: Configures OpenID Connect provider for `https://app.terraform.io`
- **IAM Role**: `TerraformCloudAssumeRole` for Terraform Cloud to assume with OIDC
- **IAM Policy**: `TerraformCloudAssumePolicy` grants permissions to manage Route 53 (DNS), SES, Lambda, S3, CloudWatch, and IAM resources
- **GitHub Actions Integration**: Enables secure, keyless authentication from GitHub Actions workflows via OIDC federation

This setup allows Terraform Cloud to deploy infrastructure changes without storing AWS credentials.

## Local Development Setup

1. Create an `.env.local` file (gitignored):

```bash
AWS_ACCESS_KEY=""
AWS_SECRET_ACCESS_KEY=""
TF_TOKEN_app_terraform_io=""
```

2. Configure AWS CLI (optional, for manual operations):
```bash
aws configure
```

3. Install Terraform locally (for testing):
```bash
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads
```

## Resources & References

- **AWS Documentation:**
  - [SES Email Receiving](https://docs.aws.amazon.com/ses/latest/dg/receiving-email.html)
  - [Lambda with Python](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
  - [Route 53 Developer Guide](https://docs.aws.amazon.com/route53/)

- **Terraform:**
  - [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
  - [Terraform Cloud](https://app.terraform.io)

- **Examples:**
  - [AWS Lambda SES Forwarder](https://github.com/aws-samples/aws-lambda-ses-forwarder)

---

**Maintained by:** Anthony Brignano  
**Last Updated:** 2026-01-08
