data "aws_acm_certificate" "qimiaai" {
  domain = local.app_dns
}

resource "aws_ecs_cluster" "app_cluster" {
  name = local.app_name
  setting {
    name  = "containerInsights"
    value = "enabled"
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
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name = local.app_name
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
  secret_string = local.backend_dns
}

resource "aws_secretsmanager_secret" "frontend_url" {
  name = "${local.secret_resource_prefix}frontend_url"
}

resource "aws_secretsmanager_secret_version" "frontend_url" {
  secret_id     = aws_secretsmanager_secret.frontend_url.id
  secret_string = local.frontend_dns
}

output "load_balancer_url" {
  value = aws_lb.ecs.dns_name
}

resource "aws_secretsmanager_secret" "email_address" {
  name = "${local.secret_resource_prefix}email_address"
}

resource "aws_secretsmanager_secret" "email_password" {
  name = "${local.secret_resource_prefix}email_password"
}

resource "aws_secretsmanager_secret" "email_smtp_send_address" {
  name = "${local.secret_resource_prefix}email_smtp_send_address"
}