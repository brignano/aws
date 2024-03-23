data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "archive_file" "email" {
  type        = "zip"
  source_file = "../lambda/forward_email.py"
  output_path = "forward_email.zip"
}