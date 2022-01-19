locals {
  records = toset(concat([var.fqdn], var.aliases))
}

resource "aws_s3_bucket" "main" {
  bucket = var.fqdn
  acl    = "public-read"
  website { redirect_all_requests_to = var.target }
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.main.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_cloudfront_distribution" "main" {
  enabled = true
  aliases = local.records

  is_ipv6_enabled = true

  origin {
    origin_id   = aws_s3_bucket.main.id
    domain_name = aws_s3_bucket.main.website_endpoint

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id = aws_s3_bucket.main.id

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000

    viewer_protocol_policy = "allow-all"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.main.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_acm_certificate" "main" {
  domain_name               = var.fqdn
  validation_method         = "DNS"
  subject_alternative_names = var.aliases
}

data "aws_route53_zone" "main" {
  name         = coalesce(var.zone, var.fqdn)
  private_zone = false
}

resource "aws_route53_record" "validation" {
  zone_id = data.aws_route53_zone.main.zone_id

  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  name = each.value.name
  type = each.value.type
  ttl  = 60

  records = [
    each.value.record,
  ]
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn
  validation_record_fqdns = [
    for record in aws_route53_record.validation
    : record.fqdn
  ]
}

resource "aws_route53_record" "ipv4" {
  zone_id  = data.aws_route53_zone.main.zone_id
  for_each = local.records
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ipv6" {
  zone_id  = data.aws_route53_zone.main.zone_id
  for_each = local.records
  name     = each.value
  type     = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
