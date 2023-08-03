# CNDF2023 infra

## What's this?

Terraform, container, website codes for CNDF2023.

- <https://event.cloudnativedays.jp/cndf2023/talks/1890>
- Slide URL <https://slide.rabbit-shocker.org/authors/unasuke/cndf2023/>
  * <https://github.com/unasuke/cndf2023>

## Architectures

### Firebase Hosting

<https://firebase.cndf2023.unasuke.dev>

### Cloudflare Pages (CloudFront over Cloudflare CDN precisely)

<https://cndf2023.unasuke.dev>

See [`tf/aws_cloudfront_s3`](/tf/aws_cloudfront_s3/) ( See `cndf2023_s3_http1`)

### AWS CloudFront and S3 static website hosting

<https://aws-cloudfront-s3.cndf2023.unasuke.dev>

See [`tf/aws_cloudfront_s3`](/tf/aws_cloudfront_s3/)

### AWS CloudFront, Application Load balancer and Fargate

* <https://aws-cloudfront-fargate-nginx.cndf2023.unasuke.dev>
* <https://aws-cloudfront-fargate-h2o.cndf2023.unasuke.dev>

See [`tf/aws_cloudfront_fargate`](/tf/aws_cloudfront_fargate/)

### AWS Network Load Balancer and Fargate

* <https://aws-nlb-fargate-nginx.cndf2023.unasuke.dev>
* <https://aws-nlb-fargate-h2o.cndf2023.unasuke.dev>

See [`tf/aws_nlb_fargate`](/tf/aws_nlb_fargate/)

### Google Cloud Load balancer and Cloud Storage

* <https://gcp-lb-storage.cndf2023.unasuke.dev>

See [`tf/gcp_load_balancing_storage`](/tf/gcp_load_balancing_storage/)

### Google Cloud Load balancer and Cloud Run

* <https://gcp-lb-cloudrun-nginx.cndf2023.unasuke.dev/>
* <https://gcp-lb-cloudrun-h2o.cndf2023.unasuke.dev/>

See [`tf/gcp_load_balancing_cloudrun`](/tf/gcp_load_balancing_cloudrun/)
