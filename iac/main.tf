###############
# brignano.io #
###############

resource "aws_route53_zone" "brignano_io" {
  name = local.domain_name.default
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "brignano_io" {
  zone_id = aws_route53_zone.brignano_io.zone_id
  name    = local.domain_name.default
  type    = "A"
  ttl     = 300
  records = [local.vercel_ip_address]
}

resource "aws_route53_record" "www_brignano_io" {
  zone_id = aws_route53_zone.brignano_io.zone_id
  name    = "www.${local.domain_name.default}"
  type    = "A"

  alias {
    name                   = local.domain_name.default
    zone_id                = aws_route53_zone.brignano_io.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "brignano_io_mx" {
  zone_id = aws_route53_zone.brignano_io.zone_id
  name    = local.domain_name.default
  type    = "MX"
  ttl     = 1800
  records = ["10 inbound-smtp.us-east-1.amazonaws.com"]
}

resource "aws_route53_record" "brignano_io_txt_ses" {
  zone_id = aws_route53_zone.brignano_io.zone_id
  name    = "_amazonses.${local.domain_name.default}"
  type    = "TXT"
  ttl     = 300
  records = [var.aws_ses_record_value]
}

#######################
# anthonybrignano.com #
#######################

resource "aws_route53_zone" "anthonybrignano_com" {
  name = local.domain_name.backup
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "anthonybrignano_com" {
  zone_id = aws_route53_zone.anthonybrignano_com.zone_id
  name    = local.domain_name.backup
  type    = "A"
  records = [aws_s3_bucket_website_configuration.redirect.website_domain]
}

resource "aws_route53_record" "www_anthonybrignano_com" {
  zone_id = aws_route53_zone.anthonybrignano_com.zone_id
  name    = "www.${local.domain_name.backup}"
  type    = "A"
  alias {
    name                   = local.domain_name.backup
    zone_id                = aws_route53_zone.anthonybrignano_com.zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket" "redirect" {
  bucket = local.domain_name.backup
}

resource "aws_s3_bucket_website_configuration" "redirect" {
  bucket = aws_s3_bucket.redirect.bucket
  redirect_all_requests_to {
    host_name = local.domain_name.default
    protocol  = "https"
  }
}
