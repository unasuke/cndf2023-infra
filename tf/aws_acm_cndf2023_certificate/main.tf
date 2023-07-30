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

resource "aws_acm_certificate" "wildcard_cndf2023_unasuke_dev" {
  private_key       = file("../../certificate/cndf2023.unasuke.dev.key")
  certificate_body  = file("../../certificate/cndf2023.unasuke.dev.crt")
  certificate_chain = file("../../certificate/cndf2023.unasuke.dev.issuer.crt")
}
