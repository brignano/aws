output "lambda_forward_email_arn" {
  value = aws_lambda_function.email.arn
}

output "brignano_io_name" {
  value = aws_route53_zone.default.name
}

output "brignano_io_zone_id" {
  value = aws_route53_zone.default.zone_id
}

output "anthony_brignano_com_name" {
  value = aws_route53_zone.backup.name
}

output "anthony_brignano_com_zone_id" {
  value = aws_route53_zone.backup.zone_id
}
