resource "aws_ecs_task_definition" "service" {
  family = "${local.app_name}-task"
  container_definitions = jsonencode([
    {
      name      = "${local.app_name}-task"
      image     = "906856305748.dkr.ecr.eu-central-1.amazonaws.com/qimia-ai-dev:latest"
      cpu       = 2048
      memory    = 1024 * 12
      essential = true
      environment = [
        {
          name  = "S3_MODEL_PATH",
          value = "s3://${data.aws_s3_object.model_binary.id}"
        }
      ]
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
          containerPort = 8000
          hostPort      = 8000
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 1024 * 12
  task_role_arn            = aws_iam_role.task_role.arn
  execution_role_arn       = aws_iam_role.execution_role.arn

}


resource "aws_ecs_service" "runner_service" {
  name            = local.app_name
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_service.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = "${local.app_name}-task"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 120
}
