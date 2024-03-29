locals {
  ec2_model_container_name    = "llama-model"
  ec2_webapi_container_name   = "web-api"
  ec2_frontend_container_name = "frontend"
  ec2_service_name            = "${local.app_name}-ec2"
}

data "aws_ec2_instance_type" "server_instance" {
  instance_type = var.model_machine_type
  lifecycle {
     postcondition {
      condition     = var.use_gpu ? length(self.gpus) > 0 : true
      error_message = "When var.use_gpu is set to true, the number of gpus in the selected machine should be more than 0."
    }
  }
}

locals {
  total_available_vcpu      = data.aws_ec2_instance_type.server_instance.default_vcpus
  total_available_memory_mb = data.aws_ec2_instance_type.server_instance.memory_size
  reserved_memory_mb        = var.reserved_memory_gb * 1024
  frontend_vcpus            = var.frontend_vcpu
  frontend_memory_mb        = var.frontend_memory_gb * 1024
  webapi_vcpus              = var.webapi_vcpu
  webapi_memory_mb          = var.webapi_memory_gb * 1024
  model_vcpus               = local.total_available_vcpu - local.frontend_vcpus - local.webapi_vcpus
  model_n_threads           = var.model_num_threads == 0 ? ceil(local.model_vcpus / 2) : var.model_num_threads
  model_memory_mb           = local.total_available_memory_mb - local.reserved_memory_mb - local.frontend_memory_mb - local.webapi_memory_mb
  ec2_models_path           = "/home/ec2-user/models/"

  model_image_registry = var.use_gpu ? aws_ecr_repository.model_gpu_repo.repository_url : aws_ecr_repository.model_repo.repository_url
}

resource "aws_ecs_task_definition" "ec2_service" {
  family = local.ec2_service_name
  container_definitions = jsonencode([
    {
      name   = local.ec2_model_container_name
      image  = "${local.model_image_registry}:latest"
      cpu    = local.model_vcpus * 1024
      memory = local.model_memory_mb
      environment = concat([
        {
          name  = "S3_MODEL_PATH",
          value = "s3://${data.aws_s3_object.model_binary.id}"
        },
        {
          name  = "MODEL_FILE",
          value = "current.bin"
        },
        {
          name  = "NUM_THREADS",
          value = tostring(local.model_n_threads)
        },
        {
          name  = "CONTEXT_SIZE",
          value = "4096"
        }
      ], var.use_gpu ? [{ name = "NUM_GPU_LAYERS", value = "200000" } ] : []
        )
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = local.app_name
        }
      }
      mountPoints = [
        {
          sourceVolume  = "models"
           containerPath = "/app/models/"
        }
      ]
      resourceRequirements = [{"value": "1", "type": "GPU"}]
      volumesFrom  = []
      portMappings = []
    },
    {
      name        = local.ec2_webapi_container_name
      image       = "${aws_ecr_repository.python_web.repository_url}:latest"
      cpu         = local.webapi_vcpus * 1024
      memory      = local.webapi_memory_mb
      essential   = true
      environment = [
        {
          name  = "ENV",
          value = var.env
        },
        {
          name = "CLOUD",
          value = "aws"
        },
        {
          name = "ENV_FILE_REMOTE_PATH",
          value = "s3://${aws_s3_object.app_config_file.bucket}/${aws_s3_object.app_config_file.key}"
        }
      ]
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
      essential   = true
      environment = [
        {
          name  = "ENV",
          value = var.env
        },
        {
          name  = "NEXT_PUBLIC_API_URL"
          value = "https://${var.backend_dns}"
        },
        {
          name  = "NEXT_PUBLIC_IS_MARKDOWN"
          value = "true"
        },
        {
          name  = "NEXTAUTH_SECRET"
          value = random_id.frontend_public_secret.hex
        },
        {
          name  = "NEXTAUTH_URL"
          value = "https://${var.frontend_dns}"
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
  volume {
    name      = "models"
    host_path = local.ec2_models_path
  }

  requires_compatibilities = ["EC2"]
  network_mode             = "host"
  task_role_arn            = aws_iam_role.model_task_role.arn
  execution_role_arn       = aws_iam_role.model_execution_role.arn
}


data "aws_ssm_parameter" "aws_iam_image_id" {
  name = var.use_gpu ? "/aws/service/ecs/optimized-ami/amazon-linux-2/gpu/recommended/image_id" : "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
#  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/inf/recommended/image_id"

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
  vpc_id = data.aws_vpc.the_vpc.id
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

locals {
  ECS_ENABLE_GPU_SUPPORT = var.use_gpu ? "true" : "false"

  ecs_config_file = join("\n",[
    "ECS_CLUSTER=${aws_ecs_cluster.app_cluster.name}",
    "ECS_ENABLE_GPU_SUPPORT=${local.ECS_ENABLE_GPU_SUPPORT}"
  ])
}

data aws_ami ami {
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.aws_iam_image_id.value]
  }
}

resource "aws_launch_template" "ecs_launch_template" {
  image_id = data.aws_ssm_parameter.aws_iam_image_id.value
  iam_instance_profile {
    name = aws_iam_instance_profile.runner_task_role.name
  }
  user_data = base64encode("#!/bin/bash\nmkdir -p ${local.ec2_models_path}\necho '${local.ecs_config_file}' >> /etc/ecs/ecs.config ; mkdir -p /var/run/artifacts")
  instance_type = data.aws_ec2_instance_type.server_instance.instance_type
  key_name = "devops"
  vpc_security_group_ids = toset([
    aws_security_group.ec2_security_group.id
  ])

  block_device_mappings {
    device_name = data.aws_ami.ami.root_device_name
    ebs {
      volume_size = 100
      volume_type = "gp3"
    }
  }

}


resource "aws_autoscaling_group" "this" {
  name                 = "${local.secret_resource_prefix}-${aws_launch_template.ecs_launch_template.name}"
  depends_on           = [aws_launch_template.ecs_launch_template]
  vpc_zone_identifier  = [for subnet in data.aws_subnet.public : subnet.id]
  launch_template {
    name = aws_launch_template.ecs_launch_template.name
  }

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
      values = [var.frontend_dns]
    }
  }
}

resource "aws_lb_target_group" "ec2_frontend" {
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.the_vpc.id

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
  slow_start           = 180
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
      values = [var.backend_dns]
    }
  }
}

resource "aws_lb_target_group" "ec2_backend" {
  port        = 8000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.the_vpc.id

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
  slow_start           = 180
}


resource "random_id" "frontend_public_secret" {
  byte_length = 16
}
