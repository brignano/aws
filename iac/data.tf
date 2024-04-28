data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "archive_file" "email" {
  type        = "zip"
  source_file = "lambda/forward_email.py"
  output_path = "lambda/forward_email.zip"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.email.function_name}:*",]
  }
}

data "aws_iam_policy_document" "s3_get_object" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = ["${aws_s3_bucket.email.arn}/emails/*",]
  }
}

data "aws_iam_policy_document" "send_raw_email" {
  statement {
    effect = "Allow"

    actions = [
      "ses:SendRawEmail",
    ]

    resources = [
      "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identity/*",
      ]
  }
}

data "aws_iam_policy_document" "s3_bucket" {
  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.email.arn}/emails/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:referer"
      values = ["data.aws_caller_identity.current.account_id"]
    }
  }
}