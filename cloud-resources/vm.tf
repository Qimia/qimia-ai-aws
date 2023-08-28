locals {
  ec2_model_container_name    = "llama-model"
  ec2_webapi_container_name   = "web-api"
  ec2_frontend_container_name = "frontend"
  ec2_service_name            = "${local.app_name}-ec2"
}

data "aws_ec2_instance_type" "server_instance" {
  instance_type = var.model_machine_type
}

locals {
  total_available_vcpu      = data.aws_ec2_instance_type.server_instance.default_vcpus
  total_available_memory_mb = data.aws_ec2_instance_type.server_instance.memory_size
  reserved_memory_mb        = 1 * 1024
  frontend_vcpus            = 1
  frontend_memory_mb        = 1.5 * 1024
  webapi_vcpus              = 1
  webapi_memory_mb          = 1 * 1024
  model_vcpus               = local.total_available_vcpu - local.frontend_vcpus - local.webapi_vcpus
  model_n_threads           = floor(local.model_vcpus / 2)
  model_memory_mb           = local.total_available_memory_mb - local.reserved_memory_mb - local.frontend_memory_mb - local.webapi_memory_mb
}

resource "aws_ecs_task_definition" "ec2_service" {
  family = local.ec2_service_name
  container_definitions = jsonencode([
    {
      name   = local.ec2_model_container_name
      image  = "${aws_ecr_repository.model_repo.repository_url}:latest"
      cpu    = local.model_vcpus * 1024
      memory = local.model_memory_mb
      environment = [
        {
          name  = "S3_MODEL_PATH",
          value = "s3://${data.aws_s3_object.model_binary.id}"
        },
        {
          name  = "NUM_THREADS",
          value = tostring(local.model_n_threads)
        },
        {
          name  = "CONTEXT_SIZE",
          value = "2048"
        }
      ]
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = local.app_name
        }
      }
      mountPoints  = []
      volumesFrom  = []
      portMappings = []
    },
    {
      name        = local.ec2_webapi_container_name
      image       = "${aws_ecr_repository.python_web.repository_url}:latest"
      cpu         = local.webapi_vcpus * 1024
      memory      = local.webapi_memory_mb
      essential   = false
      environment = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = local.app_name
        }
      }
      mountPoints = []
      volumesFrom = []
      portMappings = [
        {
          protocol      = "tcp"
          containerPort = 8000
          hostPort      = 8000
        }
      ]
    },
    {
      name      = local.ec2_frontend_container_name
      image     = "${aws_ecr_repository.frontend_zmq_repo.repository_url}:latest"
      cpu       = local.frontend_vcpus * 1024
      memory    = local.frontend_memory_mb
      essential = false
      environment = [
        {
          name  = "ENV",
          value = var.env
        }
      ]
      mountPoints = []
      volumesFrom = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = local.app_name
        }
      }

      portMappings = [
        {
          protocol      = "tcp"
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])

  requires_compatibilities = ["EC2"]
  network_mode             = "host"
  task_role_arn            = aws_iam_role.model_task_role.arn
  execution_role_arn       = aws_iam_role.model_execution_role.arn
}


data "aws_ssm_parameter" "aws_iam_image_id" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_cloudwatch_log_group" "service_log_group" {
  name = local.ec2_service_name
}


resource "aws_ecs_service" "ec2_service" {
  name            = local.ec2_service_name
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.ec2_service.arn
  desired_count   = 1

  enable_execute_command = true
  launch_type            = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.ec2_frontend.arn
    container_name   = local.ec2_frontend_container_name
    container_port   = 3000
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ec2_backend.arn
    container_name   = local.ec2_webapi_container_name
    container_port   = 8000
  }

  placement_constraints {
    type = "distinctInstance"
  }



  # Allow the cluster to reduce the number of running tasks to 0
  deployment_minimum_healthy_percent = 0

  # Don't start a new task unless one is killed during deployment
  deployment_maximum_percent = 100

  health_check_grace_period_seconds = 120
}

resource "aws_security_group" "ec2_security_group" {
  vpc_id = aws_vpc.the_vpc.id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  description = "Qimia AI ${var.env} EC2 Machines"
}

resource "aws_vpc_security_group_ingress_rule" "lb_to_ec2" {
  ip_protocol                  = "-1"
  security_group_id            = aws_security_group.ec2_security_group.id
  referenced_security_group_id = aws_security_group.lb.id
  description                  = "Allow access from the Load Balancer to EC2"
}

resource "aws_vpc_security_group_ingress_rule" "ec2_to_rds" {
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.allow_tls.id
  referenced_security_group_id = aws_security_group.ec2_security_group.id
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Allow access from the EC2 machines to the database."
}

## TODO remove later this global access
resource "aws_vpc_security_group_ingress_rule" "temp_global_access_ec2" {
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.ec2_security_group.id
  description       = "Allow access globally to EC2 - must be removed at a later time"
}


resource "aws_launch_configuration" "ecs_launch_config" {
  image_id             = data.aws_ssm_parameter.aws_iam_image_id.value
  iam_instance_profile = aws_iam_instance_profile.runner_task_role.name
  user_data            = "#!/bin/bash\necho 'ECS_CLUSTER=${aws_ecs_cluster.app_cluster.name}' >> /etc/ecs/ecs.config ; mkdir -p /var/run/artifacts"
  instance_type        = data.aws_ec2_instance_type.server_instance.instance_type
  key_name             = "devops"
  security_groups = [
    aws_security_group.ec2_security_group.id
  ]
}


resource "aws_autoscaling_group" "this" {
  name                 = "${local.secret_resource_prefix}-${aws_launch_configuration.ecs_launch_config.name}"
  depends_on           = [aws_launch_configuration.ecs_launch_config]
  vpc_zone_identifier  = [for subnet in aws_subnet.public : subnet.id]
  launch_configuration = aws_launch_configuration.ecs_launch_config.name

  desired_capacity          = 1
  min_size                  = 0
  max_size                  = 3
  health_check_grace_period = 300
  health_check_type         = "EC2"

  target_group_arns = [aws_lb_target_group.ec2_frontend.arn]
}

resource "aws_lb_listener" "https_to_ec2_frontend" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.qimiaai.arn
  depends_on        = [aws_lb_target_group.ec2_frontend]
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "https_to_ec2_frontend" {
  listener_arn = aws_lb_listener.https_to_ec2_frontend.arn
  priority     = 98
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_frontend.arn
  }

  condition {
    host_header {
      values = [local.frontend_dns]
    }
  }
}

resource "aws_lb_target_group" "ec2_frontend" {
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.the_vpc.id

  lifecycle {
    create_before_destroy = true
  }
  health_check {
    path                = "/"
    port                = "3000"
    protocol            = "HTTP"
    interval            = 120
    unhealthy_threshold = 5
    healthy_threshold   = 2
  }
  deregistration_delay = "30"
  slow_start = 180
}

resource "aws_lb_listener" "https_to_ec2_backend" {
  load_balancer_arn = aws_lb.ecs.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.qimiaai.arn
  depends_on        = [aws_lb_target_group.ec2_backend]
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "https_to_ec2_backend" {
  listener_arn = aws_lb_listener.https_to_ec2_backend.arn
  priority     = 99
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_backend.arn
  }

  condition {
    host_header {
      values = [local.backend_dns]
    }
  }
}

resource "aws_lb_target_group" "ec2_backend" {
  port        = 8000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.the_vpc.id

  lifecycle {
    create_before_destroy = true
  }
  health_check {
    path                = "/v1/health"
    port                = "8000"
    protocol            = "HTTP"
    interval            = 120
    unhealthy_threshold = 5
    healthy_threshold   = 2
  }
  deregistration_delay = "30"
  slow_start = 180
}

