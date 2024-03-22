###############
# brignano.io #
###############

resource "aws_route53_zone" "default" {
  name = local.domain_name.default
  lifecycle {
    prevent_destroy = true
  }
}

# todo: remove below resource
resource "aws_route53_record" "default" {
  zone_id = aws_route53_zone.default.zone_id
  name    = aws_route53_zone.default.name
  type    = "A"
  ttl     = 300
  records = [local.vercel_ip_address]
}

resource "aws_route53_record" "default_www" {
  zone_id = aws_route53_zone.default.zone_id
  name    = "www.${aws_route53_zone.default.name}"
  type    = "A"

  alias {
    name                   = aws_route53_zone.default.name
    zone_id                = aws_route53_zone.default.zone_id
    evaluate_target_health = false
  }
}

#######################
# anthonybrignano.com #
#######################

resource "aws_route53_zone" "backup" {
  name = local.domain_name.backup
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "backup" {
  zone_id = aws_route53_zone.backup.zone_id
  name    = local.domain_name.backup
  type    = "A"
  alias {
    name                   = aws_s3_bucket_website_configuration.redirect.website_domain
    zone_id                = aws_s3_bucket.redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "backup_www" {
  zone_id = aws_route53_zone.backup.zone_id
  name    = "www.${local.domain_name.backup}"
  type    = "A"
  alias {
    name                   = local.domain_name.backup
    zone_id                = aws_route53_zone.backup.zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket" "redirect" {
  bucket = local.domain_name.backup
}

resource "aws_s3_bucket_website_configuration" "redirect" {
  bucket = aws_s3_bucket.redirect.bucket
  redirect_all_requests_to {
    host_name = aws_route53_zone.default.name
    protocol  = "https"
  }
}

################
# email config #
################

resource "aws_ses_domain_identity" "primary" {
  domain = aws_route53_zone.default.name
}

resource "aws_route53_record" "ses_verif" {
  zone_id = aws_route53_zone.default.zone_id
  name    = "_amazonses.${aws_ses_domain_identity.primary.id}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.primary.verification_token]
}

resource "aws_ses_domain_identity_verification" "ses_verif" {
  domain = aws_ses_domain_identity.primary.id

  depends_on = [aws_route53_record.ses_verif]
}

resource "aws_route53_record" "email" {
  zone_id = aws_route53_zone.default.zone_id
  name    = aws_route53_zone.default.name
  type    = "MX"
  ttl     = "600"
  records = ["10 inbound-smtp.${data.aws_region.current.name}.amazonaws.com"]
}

resource "aws_ses_email_identity" "email" {
  email = local.email_address
}

resource "aws_s3_bucket" "email" {
  bucket = "${aws_route53_zone.default.name}-email-bucket"
}

resource "aws_s3_bucket_ownership_controls" "email" {
  bucket = aws_s3_bucket.email.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "email" {
  depends_on = [aws_s3_bucket_ownership_controls.email]

  bucket = aws_s3_bucket.email.id
  acl    = "private"
}

resource "aws_s3_bucket_policy" "email" {
  bucket = aws_s3_bucket.email.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSESPuts",
      "Effect": "Allow",
      "Principal": {
        "Service": "ses.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "${aws_s3_bucket.email.arn}/emails/*",
      "Condition": {
        "StringEquals": {
        "aws:Referer": "${data.aws_caller_identity.current.account_id}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role" "email" {
  name               = "LambdaSesForwarder"
  path               = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "AllowLambdaAssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "email" {
  name = "LambdaSesForwarder"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaToCreateLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:CreateLogGroup",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowLambdaToSendEmails",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "ses:SendRawEmail"
      ],
      "Resource": [
        "${aws_s3_bucket.email.arn}/emails/*",
        "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identity/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "email" {
  role       = aws_iam_role.email.name
  policy_arn = aws_iam_policy.email.arn
}

data "archive_file" "email" {
  type        = "zip"
  source_file = "lambda/forward_email.py"
  output_path = "work/lambda.zip"
}

resource "aws_lambda_function" "email" {
  filename      = data.archive_file.email.output_path
  function_name = "SesForwarder" # todo: "email-forwarder"
  role          = aws_iam_role.email.arn
  handler       = "forward_email.lambda_handler"
  timeout       = 30
  tags          = {}

  source_code_hash = filebase64sha256(data.archive_file.email.output_path)
  runtime          = "python3.12"
  environment {
    variables = {
      MailS3Bucket  = aws_s3_bucket.email.bucket
      MailS3Prefix  = "emails"
      MailSender    = aws_ses_email_identity.email.email
      MailRecipient = aws_ses_email_identity.email.email
      Region        = data.aws_region.current.name
    }
  }
}

resource "aws_ses_receipt_rule_set" "primary" {
  rule_set_name = "default-rule-set"
}

resource "aws_ses_active_receipt_rule_set" "primary" {
  rule_set_name = aws_ses_receipt_rule_set.primary.rule_set_name
}

resource "aws_ses_receipt_rule" "noreply" {
  name          = "noreply"
  rule_set_name = aws_ses_receipt_rule_set.primary.rule_set_name
  recipients    = ["noreply@${aws_route53_zone.default.name}"]
  enabled       = true
  scan_enabled  = true

  bounce_action {
    position        = 1
    smtp_reply_code = "550"
    status_code     = "5.1.1"
    message         = "Mailbox does not exist"
    sender          = "noreply@${aws_route53_zone.default.name}"
  }
}

resource "aws_ses_receipt_rule" "archive" {
  name          = "archive"
  rule_set_name = aws_ses_receipt_rule_set.primary.rule_set_name
  recipients    = [aws_route53_zone.default.name]
  enabled       = true
  scan_enabled  = true

  s3_action {
    position          = 1
    bucket_name       = aws_s3_bucket.email.bucket
    object_key_prefix = "emails/"
  }
}

resource "aws_ses_receipt_rule" "forward" {
  name          = "forward"
  rule_set_name = aws_ses_receipt_rule_set.primary.rule_set_name
  recipients    = ["hi@${aws_route53_zone.default.name}"]
  enabled       = true
  scan_enabled  = true

  lambda_action {
    position        = 1
    function_arn    = aws_lambda_function.email.arn
    invocation_type = "Event"
  }
}

resource "aws_lambda_permission" "email" {
  statement_id   = "AllowExecutionFromSES"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.email.function_name
  principal      = "ses.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = aws_ses_receipt_rule.forward.arn
}
