resource "aws_secretsmanager_secret" "gitlab_credentials" {
  count = var.create_shared_resources ? 1 : 0
  name = "${local.secret_resource_prefix}gitlab_oauth"
}

data "aws_secretsmanager_secret_version" gitlab_credentials {
  secret_id = aws_secretsmanager_secret.gitlab_credentials[0].id
}

locals {
  branch_name = lookup({
    "prod" = "main",
    "dev" = "main"
  }, var.env)
}

resource "aws_amplify_app" "frontend" {
  count = var.create_shared_resources ? 1 : 0
  name       = local.app_name
  repository = "https://gitlab.com/qimiaio/qimia-ai-dev/qimia-ai-frontend"
  environment_variables = {
    ENV = var.env
    API_URL = "http://${aws_secretsmanager_secret_version.lb_url.secret_string}"
  }
  iam_service_role_arn = aws_iam_role.ssr_role.arn
  platform = "WEB"
  access_token = data.aws_secretsmanager_secret_version.gitlab_credentials.secret_string
}


resource "aws_amplify_branch" "branch" {
  app_id      = aws_amplify_app.frontend[0].id
  branch_name = local.branch_name
  framework = "Next.js - SSR"
  display_name = var.env
  stage = "EXPERIMENTAL"
}


### IAM Service Role


data "aws_iam_policy_document" "ssr_role" {
  statement {
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.region}:${var.account}:log-group:/aws/amplify/*:log-stream:*"]
  }
  statement {
    actions = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:${var.region}:${var.account}:log-group:/aws/amplify/*"]
  }
  statement {
    actions = ["logs:DescribeLogGroups"]
    resources = ["arn:aws:logs:${var.region}:${var.account}:log-group:*"]
  }
}

resource "aws_iam_policy" "ssr_role" {
  policy = data.aws_iam_policy_document.execution_role.json
}

resource "aws_iam_role" "ssr_role" {
  name = "${local.app_name}-ssr"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "amplify.amazonaws.com"
          }
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "ssr_role" {
  policy_arn = aws_iam_policy.ssr_role.arn
  role       = aws_iam_role.ssr_role.id
}

###