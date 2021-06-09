provider "aws" {
  version = "2.33.0"
  alias = "cert"
  region = var.aws_region
}

data "aws_route53_zone" "dnszone" {
  name = var.dns_zone
  private_zone = false
}

locals {
  domain_name = "terraformcloud.learningwithexperts.com"
}

resource "aws_s3_bucket" "terraform_cloud" {
  bucket = local.domain_name
}

resource "aws_acm_certificate" "cloudfront_cert" {
  provider = aws.cert
  domain_name = local.domain_name
  validation_method = "DNS"
}

resource "aws_route53_record" "cloudfront_cert" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.dnszone.zone_id
}

resource "aws_acm_certificate_validation" "cloudfront_cert" {
  provider = aws.cert
  certificate_arn = aws_acm_certificate.cloudfront_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cloudfront_cert : record.fqdn]
}

locals {
  origin_id = "terraformcloud"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "cloudfront origin access identity"
}

resource "aws_cloudfront_distribution" "distribution" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "production - terraform-cloud"

  aliases = [ local.domain_name ]

  tags = {
    "CreatedBy": "Terraform"
    "Environment": "production"
    "Application": "terraform-cloud"
  }

  origin {
    origin_id   = local.origin_id
    domain_name = aws_s3_bucket.terraform_cloud.bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
    }
  }

  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    target_origin_id = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress = true
    default_ttl = 31536000
    min_ttl = 31536000
    max_ttl = 31536000

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cloudfront_cert.arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2018"
  }

  depends_on = [ aws_acm_certificate.cloudfront_cert, aws_acm_certificate_validation.cloudfront_cert ]
}

resource "aws_route53_record" "cloudfront_fqdn_dns" {
  name =  local.domain_name
  zone_id = data.aws_route53_zone.dnszone.zone_id
  type = "A"
  alias {
    name = aws_cloudfront_distribution.distribution.domain_name
    zone_id = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = true
  }
  depends_on = [ aws_cloudfront_distribution.distribution ]
}
