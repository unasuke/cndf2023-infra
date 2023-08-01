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

locals {
  # Use single az, this is sample repository.
  # azs = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  azs                = ["ap-northeast-1c", "ap-northeast-1d"]
  project_name       = "cndf2023-nlb-fargate"
  nginx_servive_name = "cndf2023-nlb-fargate-nginx"
  h2o_servive_name   = "cndf2023-nlb-fargate-h2o"
}

data "aws_caller_identity" "self" {}

# https://github.com/terraform-aws-modules/terraform-aws-vpc
module "vpc" {
  source                  = "terraform-aws-modules/vpc/aws"
  name                    = local.project_name
  cidr                    = "10.0.0.0/16"
  azs                     = local.azs
  public_subnets          = ["10.0.1.0/24", "10.0.3.0/24"]
  private_subnets         = ["10.0.2.0/24", "10.0.4.0/24"]
  enable_nat_gateway      = true
  single_nat_gateway      = true
  map_public_ip_on_launch = true
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

resource "aws_security_group" "allow_udp_https" {
  name        = "allow-udp-https"
  description = "allow https(udp) access from internet"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description      = "https"
    from_port        = "9443"
    to_port          = "9443"
    protocol         = "udp"
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

resource "aws_ecs_cluster" "cndf2023" {
  name = local.project_name
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
  name               = "ecsTaskExecutionRoleNLB"
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

resource "aws_ecs_task_definition" "cndf2023_nlb_fargate_nginx" {
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
        },
        {
          containerPort = 443
          hostPort      = 443
          protocol      = "tcp"
        },
        {
          containerPort = 9443
          hostPort      = 9443
          protocol      = "udp"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl http://localhost/health"]
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

resource "aws_cloudwatch_log_group" "cndf2023_cloudfront_nlb_nginx" {
  name              = local.nginx_servive_name
  retention_in_days = 14
}

resource "aws_ecs_service" "cndf2023_cloudfront_nlb_nginx" {
  name            = local.nginx_servive_name
  cluster         = aws_ecs_cluster.cndf2023.name
  task_definition = aws_ecs_task_definition.cndf2023_nlb_fargate_nginx.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = module.vpc.public_subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.allow_http.id, aws_security_group.allow_https.id, aws_security_group.allow_udp_https.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_nginx_tg_80.arn
    container_name   = "nginx"
    container_port   = 80
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_nginx_tg_9443.arn
    container_name   = "nginx"
    container_port   = 9443
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_nginx_tg_https.arn
    container_name   = "nginx"
    container_port   = 443
  }
}

resource "aws_lb" "cndf2023_nlb_fargate_nginx_nlb" {
  name               = "cndf2023-nlb-fargate-nginx"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "cndf2023_nlb_fargate_nginx_tg_80" {
  name        = "cndf2023-nlb-faragte-nginx-80"
  port        = 80
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check {
    enabled  = true
    port     = "traffic-port"
    path     = "/health"
    protocol = "HTTP"
    matcher  = "200"
    interval = 5
    timeout  = 3
  }
}

resource "aws_lb_listener" "cndf2023_nlb_fargate_nginx_listener_80" {
  load_balancer_arn = aws_lb.cndf2023_nlb_fargate_nginx_nlb.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_nginx_tg_80.arn
  }
}

resource "aws_lb_target_group" "cndf2023_nlb_fargate_nginx_tg_https" {
  name        = "cndf2023-nlb-faragte-nginx-https"
  port        = 443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check {
    enabled  = true
    port     = 80
    path     = "/health"
    protocol = "HTTP"
    matcher  = "200"
    interval = 5
    timeout  = 3
  }
}

resource "aws_lb_listener" "cndf2023_nlb_fargate_nginx_listener_https" {
  load_balancer_arn = aws_lb.cndf2023_nlb_fargate_nginx_nlb.arn
  port              = 443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_nginx_tg_https.arn
  }
}

resource "aws_lb_target_group" "cndf2023_nlb_fargate_nginx_tg_9443" {
  name        = "cndf2023-nlb-faragte-nginx-9443"
  port        = 9443
  protocol    = "UDP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check {
    enabled  = true
    port     = 80
    path     = "/health"
    protocol = "HTTP"
    matcher  = "200"
    interval = 5
    timeout  = 3
  }
}

resource "aws_lb_listener" "cndf2023_nlb_fargate_nginx_listener_9443" {
  load_balancer_arn = aws_lb.cndf2023_nlb_fargate_nginx_nlb.arn
  port              = 9443
  protocol          = "UDP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_nginx_tg_9443.arn
  }
}

resource "aws_ecs_task_definition" "cndf2023_nlb_fargate_h2o" {
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
        },
        {
          containerPort = 443
          hostPort      = 443
          protocol      = "tcp"
        },
        {
          containerPort = 9443
          hostPort      = 9443
          protocol      = "udp"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl http://localhost/health"]
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

resource "aws_cloudwatch_log_group" "cndf2023_cloudfront_nlb_h2o" {
  name              = local.h2o_servive_name
  retention_in_days = 14
}

resource "aws_ecs_service" "cndf2023_cloudfront_nlb_h2o" {
  name            = local.h2o_servive_name
  cluster         = aws_ecs_cluster.cndf2023.name
  task_definition = aws_ecs_task_definition.cndf2023_nlb_fargate_h2o.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = module.vpc.public_subnets
    assign_public_ip = true
    security_groups  = [aws_security_group.allow_http.id, aws_security_group.allow_https.id, aws_security_group.allow_udp_https.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_h2o_tg_80.arn
    container_name   = "h2o"
    container_port   = 80
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_h2o_tg_9443.arn
    container_name   = "h2o"
    container_port   = 9443
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_h2o_tg_https.arn
    container_name   = "h2o"
    container_port   = 443
  }
}

resource "aws_lb" "cndf2023_nlb_fargate_h2o_nlb" {
  name               = "cndf2023-nlb-fargate-h2o"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "cndf2023_nlb_fargate_h2o_tg_80" {
  name        = "cndf2023-nlb-faragte-h2o-80"
  port        = 80
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check {
    enabled  = true
    port     = "traffic-port"
    path     = "/health"
    protocol = "HTTP"
    matcher  = "200"
    interval = 5
    timeout  = 3
  }
}

resource "aws_lb_listener" "cndf2023_nlb_fargate_h2o_listener_80" {
  load_balancer_arn = aws_lb.cndf2023_nlb_fargate_h2o_nlb.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_h2o_tg_80.arn
  }
}

resource "aws_lb_target_group" "cndf2023_nlb_fargate_h2o_tg_https" {
  name        = "cndf2023-nlb-faragte-h2o-https"
  port        = 443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check {
    enabled  = true
    port     = 80
    path     = "/health"
    protocol = "HTTP"
    matcher  = "200"
    interval = 5
    timeout  = 3
  }
}

resource "aws_lb_listener" "cndf2023_nlb_fargate_h2o_listener_https" {
  load_balancer_arn = aws_lb.cndf2023_nlb_fargate_h2o_nlb.arn
  port              = 443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_h2o_tg_https.arn
  }
}

resource "aws_lb_target_group" "cndf2023_nlb_fargate_h2o_tg_9443" {
  name        = "cndf2023-nlb-faragte-h2o-9443"
  port        = 9443
  protocol    = "UDP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  health_check {
    enabled  = true
    port     = 80
    path     = "/health"
    protocol = "HTTP"
    matcher  = "200"
    interval = 5
    timeout  = 3
  }
}

resource "aws_lb_listener" "cndf2023_nlb_fargate_h2o_listener_9443" {
  load_balancer_arn = aws_lb.cndf2023_nlb_fargate_h2o_nlb.arn
  port              = 9443
  protocol          = "UDP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cndf2023_nlb_fargate_h2o_tg_9443.arn
  }
}
