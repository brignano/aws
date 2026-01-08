# Terraform Cloud Import Guide

## Issue: Resource Already Exists

If you encounter an error like:

```
Error: creating Route 53 Record: InvalidChangeBatch: [Tried to create resource record set [name='www.anthonybrignano.com.', type='CNAME'] but it already exists]
```

This means a resource exists in AWS but is not tracked in Terraform state.

## Solution: Import Existing Resource

### Option 1: Import via Terraform Cloud UI (Recommended)

1. **Navigate to Terraform Cloud:**
   - Go to https://app.terraform.io/app/brignano/workspaces/aws-config
   - Click on "Settings" → "General"

2. **Enable CLI-Driven Workflow (temporarily):**
   - Change "Execution Mode" to "Local"
   - Save settings

3. **Run Import Locally:**
   ```bash
   cd iac/
   
   # Initialize Terraform with Terraform Cloud backend
   terraform init
   
   # Import the existing CNAME record
   terraform import aws_route53_record.backup_www <ZONE_ID>_www.anthonybrignano.com_CNAME
   
   # Example:
   # terraform import aws_route53_record.backup_www Z03941761P902ZZ5Z2ZNA_www.anthonybrignano.com_CNAME
   ```

4. **Restore Remote Execution:**
   - Go back to Terraform Cloud UI
   - Change "Execution Mode" back to "Remote"
   - Save settings

5. **Verify State:**
   ```bash
   terraform state list | grep backup_www
   ```

### Option 2: Delete and Recreate via Terraform

If importing is not possible, you can delete the existing DNS record and let Terraform recreate it:

⚠️ **Warning:** This will cause brief DNS downtime for www.anthonybrignano.com

1. **Delete the existing record manually:**
   - Go to Route 53 console
   - Find hosted zone for anthonybrignano.com
   - Delete the CNAME record for "www"

2. **Run Terraform Apply:**
   - Terraform will create the record fresh

### Option 3: Use Import Block (Terraform 1.5+)

Add an import block to your Terraform configuration:

```hcl
import {
  to = aws_route53_record.backup_www
  id = "Z03941761P902ZZ5Z2ZNA_www.anthonybrignano.com_CNAME"
}
```

Then run:
```bash
terraform plan
terraform apply
```

## Getting the Zone ID

To find your hosted zone ID:

```bash
# Using AWS CLI
aws route53 list-hosted-zones --query "HostedZones[?Name=='anthonybrignano.com.'].Id" --output text

# Or check Terraform outputs
terraform output backup_hosted_zone_id
```

## Import Format for Route 53 Records

The import ID format for Route 53 records is:
```
<zone_id>_<record_name>_<record_type>
```

Examples:
- A record: `Z1234567890ABC_example.com_A`
- CNAME record: `Z1234567890ABC_www.example.com_CNAME`
- MX record: `Z1234567890ABC_example.com_MX`

## Preventing This Issue

To avoid this issue in the future:

1. **Always Import First:** Before adding a resource to Terraform that already exists in AWS, import it first
2. **Use Terraform for All Changes:** Avoid making manual changes in the AWS console
3. **State Management:** Regularly backup Terraform state
4. **Documentation:** Document any manual changes that need to be imported

## Related Resources

- [Terraform Import Documentation](https://developer.hashicorp.com/terraform/cli/import)
- [Terraform Cloud Import](https://developer.hashicorp.com/terraform/cloud-docs/run/cli)
- [AWS Route 53 Record Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record#import)
