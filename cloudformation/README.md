# CloudFormation - AWS OIDC Setup

This directory contains the CloudFormation template that sets up OpenID Connect (OIDC) authentication between Terraform Cloud and AWS. This enables secure, keyless authentication without storing long-term AWS credentials.

## What Gets Created

The CloudFormation stack (`TerraformAssumeRoleSetup`) creates:

1. **OIDC Provider** (`TerraformOIDCProvider`)
   - URL: `https://app.terraform.io`
   - Client ID: `aws.workload.identity`
   - Thumbprint: `9e99a48a9960b14926bb7f3b02e22da2b0ab7280`

2. **IAM Role** (`TerraformCloudAssumeRole`)
   - Allows Terraform Cloud to assume this role via OIDC
   - Scoped to organization: `brignano`
   - Restricted to workspace runs

3. **IAM Policy** (`TerraformCloudAssumePolicy`)
   - Grants permissions for Terraform to manage AWS resources
   - Includes: Route 53, SES, S3, Lambda, IAM, CloudWatch, Amplify

## Architecture

```
Terraform Cloud → OIDC Provider → IAM Role → AWS Resources
   (Trusted)       (app.terraform.io)  (Assume Role)  (Provisioning)
```

## Prerequisites

Before deploying this stack:

1. **AWS Account** with CloudFormation permissions
2. **GitHub Repository** with Actions enabled
3. **AWS CLI or Console Access** to deploy CloudFormation
4. **Terraform Cloud Organization** created (`brignano`)

## Deployment

### Option 1: Automated Deployment (Recommended)

The stack is automatically deployed via GitHub Actions when changes are pushed to `main`:

1. **Make changes** to `cloudformation/template.yml`
2. **Commit and push** to `main` branch
3. **GitHub Actions** workflow `aws-setup.yml` deploys the stack
4. **Check workflow** run at: https://github.com/brignano/aws/actions

**Required GitHub Secret:**
- `AWS_ASSUME_ROLE_ARN` - IAM role ARN for GitHub Actions (bootstrap role)

### Option 2: Manual Deployment via AWS CLI

```bash
# Validate the template
aws cloudformation validate-template \
  --template-body file://cloudformation/template.yml

# Deploy the stack
aws cloudformation deploy \
  --template-file cloudformation/template.yml \
  --stack-name TerraformAssumeRoleSetup \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Get the output (Role ARN)
aws cloudformation describe-stacks \
  --stack-name TerraformAssumeRoleSetup \
  --query 'Stacks[0].Outputs[?OutputKey==`TerraformCloudAssumeRoleArn`].OutputValue' \
  --output text
```

### Option 3: Manual Deployment via AWS Console

1. Go to [CloudFormation Console](https://console.aws.amazon.com/cloudformation)
2. Click **Create stack** → **With new resources**
3. Upload `cloudformation/template.yml`
4. Stack name: `TerraformAssumeRoleSetup`
5. Click **Next** through the wizard
6. Check **"I acknowledge that AWS CloudFormation might create IAM resources"**
7. Click **Submit**
8. Wait for stack to reach `CREATE_COMPLETE` status
9. Go to **Outputs** tab and copy `TerraformCloudAssumeRoleArn`

## Post-Deployment Configuration

After the CloudFormation stack is created:

### 1. Configure Terraform Cloud Workspace

Navigate to your Terraform Cloud workspace variables:
https://app.terraform.io/app/brignano/workspaces/aws-config/variables

**Add/Update these variables:**

| Variable Name | Value | Type | Sensitive |
|--------------|-------|------|-----------|
| `TFC_AWS_PROVIDER_AUTH` | `true` | Environment | No |
| `TFC_AWS_RUN_ROLE_ARN` | `<ARN from CloudFormation Output>` | Environment | No |

Example ARN: `arn:aws:iam::549188633263:role/TerraformCloudAssumeRole`

### 2. Verify OIDC Configuration

Test that OIDC authentication works:

```bash
# Trigger a Terraform plan
cd iac/
terraform init
terraform plan
```

If OIDC is configured correctly, Terraform will authenticate without AWS access keys.

## Updating the Stack

To update the CloudFormation stack:

1. **Modify** `cloudformation/template.yml`
2. **Test locally** (optional):
   ```bash
   aws cloudformation validate-template --template-body file://cloudformation/template.yml
   ```
3. **Commit and push** to `main` branch
4. **GitHub Actions** will update the stack automatically

Or manually via CLI:
```bash
aws cloudformation deploy \
  --template-file cloudformation/template.yml \
  --stack-name TerraformAssumeRoleSetup \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Permissions Granted

The `TerraformCloudAssumePolicy` grants the following permissions:

### Route 53 (DNS)
- Full access to specific hosted zones:
  - `brignano.io` (Z03854061GJ89FG9XI2HY)
  - `anthonybrignano.com` (Z03941761P902ZZ5Z2ZNA)
- List hosted zones (limited by condition)

### S3 (Storage)
- Full access to specific buckets:
  - `brignano.io-emails`
  - `www.anthonybrignano.com`
  - `anthonybrignano.com`

### SES (Email)
- Full management permissions for SES resources
- Scoped to specific resources:
  - Domain identity: `brignano.io`
  - Email identities under `@brignano.io`
  - Any email identities (for forwarding destinations)
  - Receipt rule set: `default-rule-set`
  - Configuration sets

### Lambda (Functions)
- Create, Update, Delete, Tag functions
- Get and List function details
- Add/Remove permissions

### IAM (Identity)
- Create, Update, Delete roles and policies
- Attach/Detach policies
- Pass roles to services
- Limited to account-scoped resources

### CloudWatch Logs
- Create, Delete, Tag log groups (for Lambda logs)
- Put retention policies
- Describe log groups

### Amplify (Web Hosting)
- Full access to Amplify apps (if needed)

## Security Considerations

### ✅ Security Features

1. **No Long-Term Credentials:** Uses temporary tokens via OIDC
2. **Scoped Access:** Role limited to specific organization and workspaces
3. **Resource Restrictions:** Permissions limited to specific resources (Route 53 zones, S3 buckets, SES identities)
4. **Audit Trail:** CloudTrail logs all assume role operations

### Best Practices

1. **Policy Review:** Regularly review and minimize granted permissions
2. **Monitoring:** Add CloudWatch alarms for unusual assume role activity
3. **Thumbprint Updates:** OIDC thumbprint may need periodic updates

### Principle of Least Privilege

This policy grants Terraform only the permissions needed to manage infrastructure in this repository. If you add new resources, you may need to update the policy.

## Troubleshooting

### Issue: Stack Creation Fails

**Error:** `User is not authorized to perform: iam:CreateRole`
- **Solution:** Ensure you have IAM permissions to create roles and policies

**Error:** `Role with name TerraformCloudAssumeRole already exists`
- **Solution:** Delete the existing role or update the stack instead of creating new

### Issue: OIDC Thumbprint Invalid

**Error:** `Invalid identity token`
- **Solution:** Update the OIDC provider thumbprint in `template.yml`
- Get current thumbprint: 
  ```bash
  echo | openssl s_client -servername app.terraform.io -connect app.terraform.io:443 2>/dev/null | openssl x509 -fingerprint -sha1 -noout | cut -d'=' -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]'
  ```

### Issue: Terraform Cannot Assume Role

**Error:** `Error: error configuring Terraform AWS Provider: failed to get shared config profile`
- **Check:** `TFC_AWS_PROVIDER_AUTH` is set to `true` in Terraform Cloud
- **Check:** `TFC_AWS_RUN_ROLE_ARN` has the correct ARN
- **Verify:** CloudFormation stack deployed successfully

### Issue: Permission Denied for Specific Resource

**Error:** `User: arn:aws:sts::123456789012:assumed-role/TerraformCloudAssumeRole/... is not authorized to perform: [action] on resource: [resource]`
- **Solution:** Add the required permission to `TerraformCloudAssumePolicy` in `template.yml`
- **Redeploy:** Push changes to update the CloudFormation stack

## Stack Outputs

| Output Key | Description | Example Value |
|------------|-------------|---------------|
| `TerraformCloudAssumeRoleArn` | ARN of the IAM role | `arn:aws:iam::549188633263:role/TerraformCloudAssumeRole` |

## Related Documentation

- [Terraform Cloud OIDC with AWS](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration)
- [AWS OIDC Provider Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [CloudFormation IAM Resources](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-iam-role.html)

## Bootstrap Process (First-Time Setup)

If you're setting up this repository from scratch:

1. **Create Bootstrap IAM Role** (one-time, manual):
   - Create an IAM role for GitHub Actions
   - Add OIDC provider for `token.actions.githubusercontent.com`
   - Grant CloudFormation and IAM permissions

2. **Deploy CloudFormation Stack**:
   - Use the bootstrap role to deploy this stack
   - This creates the Terraform Cloud role

3. **Configure Terraform Cloud**:
   - Set the workspace variables as described above

4. **Deploy Infrastructure**:
   - Push to `main` to trigger Terraform deployment

---

**Note:** This CloudFormation template is specifically designed for the `brignano` organization. If you're forking this repository, update the organization name and hosted zone IDs in `template.yml`.
