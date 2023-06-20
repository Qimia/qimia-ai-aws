data "aws_acm_certificate" "qimiaai" {
  domain = "qimiaai.com"
}

resource "aws_ecs_cluster" "app_cluster" {
  name = local.app_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_lb_target_group" "ecs" {
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.the_vpc.id
  health_check {
    path     = "/v1/health"
    port     = "8000"
    protocol = "HTTP"
    interval = 120
  }
  slow_start = 120

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "frontend" {
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.the_vpc.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "lb" {
  vpc_id = aws_vpc.the_vpc.id
  ingress {
    description      = "Allow all TCP"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
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

resource "aws_lb" "ecs" {
  idle_timeout       = 120
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]
}

resource "aws_lb_listener" "ecs_to_tg" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 8000
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
  depends_on = [aws_lb_target_group.ecs]
}

resource "aws_lb_listener" "https_to_backend" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.qimiaai.arn
  depends_on        = [aws_lb_target_group.ecs]
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "https_to_backend" {
  listener_arn = aws_lb_listener.https_to_backend.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  condition {
    host_header {
      values = ["api.${local.env_domain_name}"]
    }
  }
}





resource "aws_lb_listener" "http_to_frontend" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  depends_on = [aws_lb_target_group.frontend]
}


resource "aws_lb_listener" "https_to_frontend" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.qimiaai.arn
  depends_on        = [aws_lb_target_group.frontend]
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "https_to_frontend" {
  listener_arn = aws_lb_listener.https_to_frontend.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    host_header {
      values = ["chat.${local.env_domain_name}"]
    }
  }
}



resource "aws_lb_listener" "frontend_tg" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 3000
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
  depends_on = [aws_lb_target_group.frontend]
}

### Definition of the ECS Execution Role
### This is the role attached to the ECS cluster that allows it to do cluster management tasks such as pulling images from ECS etc.
data "aws_ecr_repository" "tempimage" {
  name = "abdullahrepo"
}

data "aws_iam_policy_document" "execution_role" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = [
      aws_ecr_repository.app_repo.arn,
      "${aws_ecr_repository.app_repo.arn}:*",
      "*"
    ]
  }
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "execution_role" {
  policy = data.aws_iam_policy_document.execution_role.json
}

resource "aws_iam_role" "execution_role" {
  name = "${local.app_name}-execution"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "execution_role" {
  policy_arn = aws_iam_policy.execution_role.arn
  role       = aws_iam_role.execution_role.id
}

### Definition of ECS task role, with this role, the app runbning inside the docker container is authorized to use the AWS API.
data "aws_iam_policy_document" "task_role" {
  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecrets",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${var.account}:secret:${local.secret_resource_prefix}*",
    ]
  }

  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:*"
    ]
    resources = [
      "${data.aws_s3_bucket.model_bucket.arn}",
      "${data.aws_s3_bucket.model_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "task_role" {
  policy = data.aws_iam_policy_document.task_role.json
}

resource "aws_iam_role" "task_role" {
  name = "${local.app_name}-task"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        }
      ]
    }
  )
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = local.app_name
}

resource "aws_iam_role_policy_attachment" "task_role" {
  policy_arn = aws_iam_policy.task_role.arn
  role       = aws_iam_role.task_role.id
}

resource "aws_security_group" "ecs_service" {
  vpc_id = aws_vpc.the_vpc.id
  ingress {
    description      = "Allow all TCP"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
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

data "aws_ssm_parameters_by_path" "parameters" {
  path = "/${local.app_name}/"
}

resource "aws_ssm_parameter" "cluster_name" {
  name  = "${data.aws_ssm_parameters_by_path.parameters.path}ecs_cluster_name"
  type  = "String"
  value = aws_lb.ecs.dns_name
}

resource "aws_secretsmanager_secret" "lb_url" {
  name = "${local.secret_resource_prefix}api_url"
}

resource "aws_secretsmanager_secret_version" "lb_url" {
  secret_id     = aws_secretsmanager_secret.lb_url.id
  secret_string = "api.${local.env_domain_name}"
}

resource "aws_secretsmanager_secret" "frontend_url" {
  name = "${local.secret_resource_prefix}frontend_url"
}

resource "aws_secretsmanager_secret_version" "frontend_url" {
  secret_id     = aws_secretsmanager_secret.frontend_url.id
  secret_string = "chat.${local.env_domain_name}"
}

output "load_balancer_url" {
  value = aws_lb.ecs.dns_name
}