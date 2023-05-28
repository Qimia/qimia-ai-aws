resource "aws_ecs_task_definition" "service" {
  family = "${local.resource_name_prefix}-task"
  container_definitions = jsonencode([
    {
      name      = "${local.resource_name_prefix}-task"
      image     = "906856305748.dkr.ecr.eu-central-1.amazonaws.com/abdullahrepo:asdqwe"
      cpu       = 256
      memory    = 2048
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region = local.region
          awslogs-stream-prefix =local.resource_name_prefix
        }
      }

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 2048
  task_role_arn = aws_iam_role.task_role.arn
  execution_role_arn = aws_iam_role.execution_role.arn

}


resource "aws_ecs_service" "runner_service" {
  name            = local.app_name
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = [for subnet in aws_subnet.public: subnet.id]
    assign_public_ip = true
    security_groups = [aws_security_group.ecs_service.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = "${local.resource_name_prefix}-task"
    container_port   = 8080
  }

  health_check_grace_period_seconds = 120
}
