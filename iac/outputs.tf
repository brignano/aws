output "aws_region" {
  value       = data.aws_region.current.name
  description = "The current AWS region"
}

output "aws_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "The current AWS account ID"
}

output "email_forwarding_lambda_arn" {
  value       = aws_lambda_function.email.arn
  description = "The ARN of the Lambda function that is responsible for forwarding emails."
}

output "primary_website" {
  value       = "https://${aws_route53_zone.default.name}"
  description = "The default website domain name."
}

output "primary_hosted_zone_id" {
  value       = aws_route53_zone.default.zone_id
  description = "The default hosted zone ID."
}

output "backup_website" {
  value       = "https://${aws_route53_zone.backup.name}"
  description = "The backup website domain name."
}

output "backup_hosted_zone_id" {
  value       = aws_route53_zone.backup.zone_id
  description = "The backup hosted zone ID."
}
