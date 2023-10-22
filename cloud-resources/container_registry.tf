resource "aws_ecr_repository" "app_repo" {
  name = "${var.project}-${var.env}"
}

resource "aws_ecr_repository" "model_repo" {
  name = "${var.project}-zmq-model-${var.env}"
}

resource "aws_ecr_repository" "model_gpu_repo" {
  name = "${var.project}-zmq-model-gpu-${var.env}"
}

resource "aws_ecr_repository" "python_web" {
  name = "${var.project}-web-python-${var.env}"
}

resource "aws_ecr_repository" "frontend_repo" {
  name = "${var.project}-frontend-${var.env}"
}

resource "aws_ecr_repository" "frontend_zmq_repo" {
  name = "${var.project}-frontend-zmq-${var.env}"
}