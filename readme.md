# aws

AWS infrastructure for brignano.io - personal website hosting, email forwarding, and DNS management.

## Overview

This repository contains Infrastructure as Code (IaC) for deploying and managing the brignano.io domain and related AWS services.

### IaC Folder

Terraform configuration for:
- **Route 53**: DNS zones for `brignano.io` and `anthonybrignano.com` with A records pointing to Vercel
- **SES (Simple Email Service)**: Email identity verification and receipt rules for `hi@brignano.io`
- **Lambda**: Email forwarding function that processes incoming emails and forwards them to your primary email
- **S3**: Email storage bucket for archiving incoming messages
- **IAM**: Roles and policies for Lambda to access S3 and send emails via SES
- **CloudWatch**: Logging for Lambda execution

### CloudFormation Folder

CloudFormation template for setting up GitHub Actions OIDC authentication with AWS:
- **OIDC Provider**: Configures OpenID Connect provider for `https://app.terraform.io`
- **IAM Role**: `TerraformCloudAssumeRole` for Terraform Cloud to assume with OIDC
- **IAM Policy**: `TerraformCloudAssumePolicy` grants permissions to manage Route 53 (DNS), SES, Lambda, S3, CloudWatch, and IAM resources
- **GitHub Actions Integration**: Enables secure, keyless authentication from GitHub Actions workflows via OIDC federation

This setup allows Terraform Cloud to deploy infrastructure changes without storing AWS credentials.

## Setup

1. Create an `.env.local` file

```bash
AWS_ACCESS_KEY=""
AWS_SECRET_ACCESS_KEY=""
TF_TOKEN_app_terraform_io=""
```
