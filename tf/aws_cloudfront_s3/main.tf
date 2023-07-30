terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

resource "aws_s3_bucket" "cndf2023_website_bucket" {
  bucket = "unasuke-cndf2023-website"
}

# https://repost.aws/knowledge-center/cloudfront-access-to-amazon-s3
data "aws_iam_policy_document" "cndf2023_website_bucket_policy" {
  statement {
    actions = ["s3:GetObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.cndf2023_website_bucket.arn}/*"]
    condition {
      test     = "StringEquals"
      values   = [aws_cloudfront_distribution.cndf2023_s3.arn]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_s3_bucket_policy" "cndf2023_website_bucket_policy" {
  bucket = aws_s3_bucket.cndf2023_website_bucket.id
  policy = data.aws_iam_policy_document.cndf2023_website_bucket_policy.json
}

data "aws_acm_certificate" "wildcard_cndf2023_unasuke_dev" {
  provider    = aws.use1
  domain      = "cndf2023.unasuke.dev"
  statuses    = ["ISSUED"]
  types       = ["IMPORTED"]
  most_recent = true
  key_types   = ["RSA_2048", "EC_prime256v1"] # https://github.com/hashicorp/terraform-provider-aws/issues/31574
}

resource "aws_cloudfront_distribution" "cndf2023_s3" {
  origin {
    domain_name              = aws_s3_bucket.cndf2023_website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cndf2023_bucket_origin_access_control.id
    origin_id                = aws_s3_bucket.cndf2023_website_bucket.arn
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["aws-cloudfront-s3.cndf2023.unasuke.dev"]

  default_cache_behavior {
    cache_policy_id        = data.aws_cloudfront_cache_policy.managed_cachingoptimized.id
    allowed_methods        = ["HEAD", "GET"]
    cached_methods         = ["HEAD", "GET"]
    target_origin_id       = aws_s3_bucket.cndf2023_website_bucket.arn
    viewer_protocol_policy = "redirect-to-https"
  }

  http_version = "http3"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.wildcard_cndf2023_unasuke_dev.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_cloudfront_origin_access_control" "cndf2023_bucket_origin_access_control" {
  name                              = "CNDF2023 S3 bucket origin access control"
  description                       = "for unasuke-cndf2023-website bucket origin access control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "managed_cachingoptimized" {
  name = "Managed-CachingOptimized"
}
