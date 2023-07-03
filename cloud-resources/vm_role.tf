resource "aws_iam_role" "model_task_role" {
  name = "${local.app_name}-model"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # The EC2 instance needs to assume this role
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      { # The ECS container spawned inside the EC2 container needs to assume the same role as their host
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "model_task_role" {
  name = aws_iam_role.model_task_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "*"
        ]
        Effect   = "Allow"
        Resource = ["*"]
    }]
  })
}

resource "aws_iam_policy_attachment" "runner_task_role" {
  roles      = [aws_iam_role.model_task_role.name]
  policy_arn = aws_iam_policy.model_task_role.arn
  name       = aws_iam_policy.model_task_role.name
}


resource "aws_iam_instance_profile" "runner_task_role" {
  name = aws_iam_role.model_task_role.name
  role = aws_iam_role.model_task_role.name
}


resource "aws_iam_role" "model_execution_role" {
  name = "${local.app_name}-execution-ec2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}


resource "aws_iam_policy" "model_execution_role" {
  name = aws_iam_role.model_execution_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = ["*"]
    }]
  })
}

resource "aws_iam_policy_attachment" "model_execution_role" {
  roles      = [aws_iam_role.model_execution_role.name]
  policy_arn = aws_iam_policy.model_execution_role.arn
  name       = aws_iam_policy.model_execution_role.name
}
