locals {
  domains = merge({ (var.domain) = var.zone }, var.aliases)
}

resource "aws_s3_bucket" "main" {
  provider = aws.bucket
  bucket   = var.domain
}

resource "aws_s3_bucket_acl" "main" {
  provider = aws.bucket
  bucket   = aws_s3_bucket.main.id
  acl      = "public-read"
}

resource "aws_s3_bucket_policy" "main" {
  provider = aws.bucket
  bucket   = aws_s3_bucket.main.id
  policy   = data.aws_iam_policy_document.bucket_policy.json
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

resource "aws_s3_bucket_website_configuration" "main" {
  provider = aws.bucket
  bucket   = aws_s3_bucket.main.id

  dynamic "index_document" {
    for_each = var.redirect_target == null ? ["index.html"] : []
    content {
      suffix = index_document.value
    }
  }

  dynamic "error_document" {
    for_each = var.redirect_target == null ? ["index.html"] : []
    content {
      key = error_document.value
    }
  }

  dynamic "redirect_all_requests_to" {
    for_each = var.redirect_target == null ? [] : [
      trimprefix(var.redirect_target, "https://")
    ]
    content {
      host_name = redirect_all_requests_to.value
      protocol  = "https"
    }
  }
}

resource "aws_cloudfront_distribution" "main" {
  for_each = local.domains

  enabled = true
  aliases = [each.key]

  is_ipv6_enabled = true

  default_root_object = var.redirect_target == null ? "index.html" : null

  origin {
    origin_id   = aws_s3_bucket.main.id
    domain_name = aws_s3_bucket_website_configuration.main.website_endpoint

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  default_cache_behavior {
    target_origin_id = aws_s3_bucket.main.id

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    min_ttl     = 0
    default_ttl = 1800
    max_ttl     = 3600

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    dynamic "lambda_function_association" {
      for_each = var.lambda_edge_arns
      content {
        event_type   = lambda_function_association.value
        lambda_arn   = lambda_function_association.key
        include_body = false
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.main[each.key].certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }
}

resource "aws_acm_certificate_validation" "main" {
  for_each                = aws_route53_record.validation
  certificate_arn         = aws_acm_certificate.main[each.key].arn
  validation_record_fqdns = [each.value.fqdn]
}

resource "aws_acm_certificate" "main" {
  for_each          = local.domains
  domain_name       = each.key
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "main" {
  for_each     = local.domains
  name         = each.value
  private_zone = false
}

resource "aws_route53_record" "validation" {
  for_each = aws_acm_certificate.main
  zone_id  = data.aws_route53_zone.main[each.key].zone_id
  name     = tolist(each.value.domain_validation_options)[0].resource_record_name
  type     = tolist(each.value.domain_validation_options)[0].resource_record_type
  ttl      = 60
  records  = [tolist(each.value.domain_validation_options)[0].resource_record_value]
}

resource "aws_route53_record" "ipv4" {
  for_each = aws_cloudfront_distribution.main
  zone_id  = data.aws_route53_zone.main[each.key].zone_id
  name     = each.key
  type     = "A"
  alias {
    name                   = each.value.domain_name
    zone_id                = each.value.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "ipv6" {
  for_each = aws_cloudfront_distribution.main
  zone_id  = data.aws_route53_zone.main[each.key].zone_id
  name     = each.key
  type     = "AAAA"
  alias {
    name                   = each.value.domain_name
    zone_id                = each.value.hosted_zone_id
    evaluate_target_health = true
  }
}
