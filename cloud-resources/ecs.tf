resource aws_ecs_cluster "app_cluster" {
  name = local.app_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_lb_target_group" "ecs" {
  port = 8080
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = aws_vpc.the_vpc.id
  health_check {
    path = "/hello"
    port = "8080"
    protocol = "HTTP"
    interval = 120
  }
  slow_start = 120

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_security_group "lb" {
  vpc_id = aws_vpc.the_vpc.id
  ingress {
    description = "Allow all TCP"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.lb.id]
  subnets  = [for subnet in aws_subnet.public: subnet.id]
}

resource "aws_lb_listener" "ecs_to_tg" {
  load_balancer_arn = aws_lb.ecs.arn
  port = 8080
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }
  depends_on = [aws_lb_target_group.ecs]
}

### Definition of the ECS Execution Role
### This is the role attached to the ECS cluster that allows it to do cluster management tasks such as pulling images from ECS etc.

data aws_iam_policy_document execution_role {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "*"
    ]
    resources = [
      aws_ecr_repository.app_repo.arn,
      "${aws_ecr_repository.app_repo.arn}/*",
      "*"
    ]
  }
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "execution_role" {
  policy = data.aws_iam_policy_document.execution_role.json
}

resource "aws_iam_role" "execution_role" {
  name = "${local.resource_name_prefix}-execution"
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
data aws_iam_policy_document task_role {
  statement {
    actions = [
    ]
    resources = [
    ]
  }
}

resource "aws_iam_policy" "task_role" {
  policy = data.aws_iam_policy_document.execution_role.json
}

resource "aws_iam_role" "task_role" {
  name = "${local.resource_name_prefix}-task"
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
  name = local.resource_name_prefix
}

resource "aws_iam_role_policy_attachment" "task_role" {
  policy_arn = aws_iam_policy.task_role.arn
  role       = aws_iam_role.task_role.id
}

resource "aws_security_group" "ecs_service" {
  vpc_id = aws_vpc.the_vpc.id
  ingress {
    description = "Allow all TCP"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

