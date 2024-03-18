# aws

## Setup

1. Add [Identity provider](https://us-east-1.console.aws.amazon.com/iamv2/home?region=us-east-1#/identity_providers)

- Provider Type: `OpenID Connect`
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

2. Add [IAM Role](https://us-east-1.console.aws.amazon.com/iamv2/home?region=us-east-1#/roles)

- Trusted entity type: `Web identity`
- Idenitity provider: `tokens.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- GitHub organization: `brignano`
- GitHub repository: `aws`

3. Add permissions > Create inline policy

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "GitHubActionsCloudFormationAccess",
			"Effect": "Allow",
			"Action": [
				"cloudformation:CreateStack",
				"cloudformation:DescribeStacks",
				"cloudformation:CreateChangeSet",
				"cloudformation:DescribeChangeSet",
				"cloudformation:DeleteChangeSet",
				"cloudformation:ExecuteChangeSet"
			],
			"Resource": "*"
		},
		{
			"Sid": "TerraformOidcProviderAccess",
			"Effect": "Allow",
			"Action": [
				"iam:ListOpenIDConnectProviders",
				"iam:CreateOpenIDConnectProvider",
				"iam:DeleteOpenIDConnectProvider",
				"iam:GetOpenIDConnectProvider"
			],
			"Resource": "arn:aws:iam::549188633263:oidc-provider/app.terraform.io"
		},
		{
			"Sid": "TerraformRolePolicyAccess",
			"Effect": "Allow",
			"Action": [
				"iam:CreatePolicy"
			],
			"Resource": "arn:aws:iam::549188633263:policy/TerraformCloudAssumeRolePolicy"
		},
		{
			"Sid": "TerraformRoleAccess",
			"Effect": "Allow",
			"Action": [
				"iam:GetRole",
				"iam:CreateRole",
				"iam:AttachRolePolicy"
			],
			"Resource": "arn:aws:iam::549188633263:role/TerraformCloudAssumeRole"
		}
	]
}
```

4. Trigger [deploy.yml](.github/workflows/deploy.yml)

5. Update [Variables | brignano-io | brignano | Terraform Cloud](https://app.terraform.io/app/brignano/workspaces/brignano-io/variables) with the `TerraformCloudAssumeRoleArn` from [Stacks | CloudFormation | us-east-1](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks?filteringText=&filteringStatus=active&viewNested=true)