terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Use single az, this is sample repository.
  # azs = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  azs                = ["ap-northeast-1a", "ap-northeast-1c"]
  nginx_servive_name = "cndf2023-cloudfront-fargate-nginx"
  h2o_servive_name   = "cndf2023-cloudfront-fargate-h2o"
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

data "aws_caller_identity" "self" {}

data "aws_acm_certificate" "wildcard_cndf2023_unasuke_dev" {
  provider    = aws.use1
  domain      = "cndf2023.unasuke.dev"
  statuses    = ["ISSUED"]
  types       = ["IMPORTED"]
  most_recent = true
  key_types   = ["RSA_2048", "EC_prime256v1"] # https://github.com/hashicorp/terraform-provider-aws/issues/31574
}

data "aws_cloudfront_cache_policy" "managed_cachingoptimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_security_group" "allow_http" {
  name        = "allow-http"
  description = "allow http access from internet"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description      = "http"
    from_port        = "80"
    to_port          = "80"
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "allow_https" {
  name        = "allow-https"
  description = "allow https access from internet"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description      = "https"
    from_port        = "443"
    to_port          = "443"
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "allow shh connection from internet"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description      = "ssh"
    from_port        = "22"
    to_port          = "22"
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-vpc
module "vpc" {
  source                  = "terraform-aws-modules/vpc/aws"
  name                    = "cndf2023-cloudfront-fargate"
  cidr                    = "10.0.0.0/16"
  azs                     = local.azs
  public_subnets          = ["10.0.1.0/24", "10.0.3.0/24"]
  private_subnets         = ["10.0.2.0/24", "10.0.4.0/24"]
  enable_nat_gateway      = true
  single_nat_gateway      = true
  map_public_ip_on_launch = true
}

resource "aws_ecs_cluster" "cndf2023" {
  name = "cndf2023-cloudfront-fargate"

}

resource "aws_ecr_repository" "cndf2023_nginx" {
  name = local.nginx_servive_name
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "cndf2023_h2o" {
  name = local.h2o_servive_name
  image_scanning_configuration {
    scan_on_push = true
  }
}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_policy.json
}

data "aws_iam_policy_document" "ecs_tasks_trust_policy" {
  statement {
    sid    = ""
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "attach_ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

}

resource "aws_iam_role_policy_attachment" "attach_ecs_task_execution_role_ecr_pull" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# maybe unneed
resource "aws_iam_role_policy_attachment" "attach_ecs_task_execution_role_ssm_read" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_ecs_task_definition" "cndf2023_cloudfront_fargate_nginx" {
  family                   = local.nginx_servive_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "${aws_ecr_repository.cndf2023_nginx.repository_url}:latest"
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl http://localhost"]
        interval    = 30
        retries     = 3
        timeout     = 5
        startPeriod = 5
      }
      mountPoints = []
      environment = []
      volumesFrom = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.nginx_servive_name
          awslogs-region        = "ap-northeast-1"
          awslogs-create-group  = "true"
          awslogs-stream-prefix = "nginx"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "cndf2023_cloudfront_fargate_nginx" {
  name              = local.nginx_servive_name
  retention_in_days = 14
}

resource "aws_ecs_service" "cndf2023_cloudfront_fargate_nginx" {
  name            = local.nginx_servive_name
  cluster         = aws_ecs_cluster.cndf2023.name
  task_definition = aws_ecs_task_definition.cndf2023_cloudfront_fargate_nginx.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = module.vpc.public_subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.allow_http.id, aws_security_group.allow_https.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.cndf2023_cloudfront_fargate_nginx_tg.arn
    container_name   = "nginx"
    container_port   = 80
  }
}

resource "aws_lb" "cndf2023_cloudfront_fargate_nginx_alb" {
  name               = "cndf2023-cf-fargate-nginx"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.allow_http.id, aws_security_group.allow_https.id]
}

resource "aws_lb_listener" "cndf2023_cloudfront_fargate_nginx_listener" {
  load_balancer_arn = aws_lb.cndf2023_cloudfront_fargate_nginx_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_cloudfront_fargate_nginx_tg.arn
  }
}

resource "aws_lb_listener_rule" "cndf2023_cloudfront_fargate_nginx_listener_nginx" {
  listener_arn = aws_lb_listener.cndf2023_cloudfront_fargate_nginx_listener.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_cloudfront_fargate_nginx_tg.arn
  }
  condition {
    host_header {
      values = ["aws-cloudfront-fargate-nginx.cndf2023.unasuke.dev"]
    }
  }
}

resource "aws_lb_target_group" "cndf2023_cloudfront_fargate_nginx_tg" {
  name        = "cndf2023-cf-faragte-nginx"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_cloudfront_distribution" "cndf2023_cloudfront_fargate_nginx_cloudfront" {
  origin {
    domain_name = aws_lb.cndf2023_cloudfront_fargate_nginx_alb.dns_name
    origin_id   = aws_lb.cndf2023_cloudfront_fargate_nginx_alb.name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["aws-cloudfront-fargate-nginx.cndf2023.unasuke.dev"]
  comment         = local.nginx_servive_name

  default_cache_behavior {
    cache_policy_id        = data.aws_cloudfront_cache_policy.managed_cachingoptimized.id
    allowed_methods        = ["HEAD", "GET"]
    cached_methods         = ["HEAD", "GET"]
    target_origin_id       = aws_lb.cndf2023_cloudfront_fargate_nginx_alb.name
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


resource "aws_ecs_task_definition" "cndf2023_cloudfront_fargate_h2o" {
  family                   = local.h2o_servive_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "h2o"
      image     = "${aws_ecr_repository.cndf2023_h2o.repository_url}:latest"
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl http://localhost"]
        interval    = 30
        retries     = 3
        timeout     = 5
        startPeriod = 5
      }
      mountPoints = []
      environment = []
      volumesFrom = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.h2o_servive_name
          awslogs-region        = "ap-northeast-1"
          awslogs-create-group  = "true"
          awslogs-stream-prefix = "h2o"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "cndf2023_cloudfront_fargate_h2o" {
  name              = local.h2o_servive_name
  retention_in_days = 14
}

resource "aws_ecs_service" "cndf2023_cloudfront_fargate_h2o" {
  name            = local.h2o_servive_name
  cluster         = aws_ecs_cluster.cndf2023.name
  task_definition = aws_ecs_task_definition.cndf2023_cloudfront_fargate_h2o.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = module.vpc.public_subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.allow_http.id, aws_security_group.allow_https.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.cndf2023_cloudfront_fargate_h2o_tg.arn
    container_name   = "h2o"
    container_port   = 80
  }
}

resource "aws_lb" "cndf2023_cloudfront_fargate_h2o_alb" {
  name               = "cndf2023-cf-fargate-h2o"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.allow_http.id, aws_security_group.allow_https.id]
}

resource "aws_lb_listener" "cndf2023_cloudfront_fargate_h2o_listener" {
  load_balancer_arn = aws_lb.cndf2023_cloudfront_fargate_h2o_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_cloudfront_fargate_h2o_tg.arn
  }
}

resource "aws_lb_listener_rule" "cndf2023_cloudfront_fargate_h2o_listener_h2o" {
  listener_arn = aws_lb_listener.cndf2023_cloudfront_fargate_h2o_listener.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_cloudfront_fargate_h2o_tg.arn
  }
  condition {
    host_header {
      values = ["aws-cloudfront-fargate-h2o.cndf2023.unasuke.dev"]
    }
  }
}

resource "aws_lb_target_group" "cndf2023_cloudfront_fargate_h2o_tg" {
  name        = "cndf2023-cf-fargate-h2o"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_cloudfront_distribution" "cndf2023_cloudfront_fargate_h2o_cloudfront" {
  origin {
    domain_name = aws_lb.cndf2023_cloudfront_fargate_h2o_alb.dns_name
    origin_id   = aws_lb.cndf2023_cloudfront_fargate_h2o_alb.name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["aws-cloudfront-fargate-h2o.cndf2023.unasuke.dev"]
  comment         = local.h2o_servive_name

  default_cache_behavior {
    cache_policy_id        = data.aws_cloudfront_cache_policy.managed_cachingoptimized.id
    allowed_methods        = ["HEAD", "GET"]
    cached_methods         = ["HEAD", "GET"]
    target_origin_id       = aws_lb.cndf2023_cloudfront_fargate_h2o_alb.name
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
