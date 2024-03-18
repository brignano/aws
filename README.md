# aws

## Setup

1. Add [Identity provider](https://us-east-1.console.aws.amazon.com/iamv2/home?region=us-east-1#/identity_providers)

   - Provider Type: `OpenID Connect`
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

2. Add [`IAM Role`](https://us-east-1.console.aws.amazon.com/iamv2/home?region=us-east-1#/roles)

   - Trusted entity type: `Web identity`
   - Idenitity provider: `tokens.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
   - GitHub organization: `brignano`
   - GitHub repository: `aws`

3. Assign [`GitHubActionsAssumeRolePolicy`](https://us-east-1.console.aws.amazon.com/iamv2/home?region=us-east-1#/policies/details/arn%3Aaws%3Aiam%3A%3A549188633263%3Apolicy%2FGitHubActionsAssumeRolePolicy?section=permissions) to the newly created `IAM Role`

4. Trigger [deploy.yml](.github/workflows/deploy.yml)

5. Update [Variables | brignano-io | brignano | Terraform Cloud](https://app.terraform.io/app/brignano/workspaces/brignano-io/variables) with the `TerraformCloudAssumeRoleArn` from [CloudFormation - Stack TerraformAssumeRoleSetup](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/outputs?filteringText=&filteringStatus=active&viewNested=true&stackId=arn%3Aaws%3Acloudformation%3Aus-east-1%3A549188633263%3Astack%2FTerraformAssumeRoleSetup%2F4fe5e940-e561-11ee-8531-1210038c0be9)