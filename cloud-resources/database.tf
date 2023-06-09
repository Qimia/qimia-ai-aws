resource "random_password" "postgres_master_password" {
  length  = 48
  special = false
}

resource "aws_db_subnet_group" "postgres" {
  count      = var.create_shared_resources ? 1 : 0
  name_prefix = "qimia-ai-${var.env}"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]
}


resource "aws_security_group" "allow_tls" {
  count       = var.create_shared_resources ? 1 : 0
  name_prefix = "Qimia AI DB - ${var.env}"
  description = "Allow access to the Qimia AI database"
  vpc_id      = aws_vpc.the_vpc.id


  ingress {
    security_groups = [aws_security_group.ecs_service.id]
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "Qimia AI DB"
    Env  = var.env
  }
}

resource "random_id" "snapshot_identifier" {
  byte_length = 4
}


resource "aws_rds_cluster" "postgres" {
  count                     = var.create_shared_resources ? 1 : 0
  cluster_identifier        = "${local.app_name}-db"
  availability_zones        = [for zone_letter in ["a", "b", "c"] : "${var.region}${zone_letter}"]
  database_name             = "test_db"
  master_username           = "postgres"
  master_password           = random_password.postgres_master_password.result
  engine                    = "aurora-postgresql"
  engine_version            = "14.7"
  db_subnet_group_name      = aws_db_subnet_group.postgres[0].name
  vpc_security_group_ids    = [aws_security_group.allow_tls[0].id]
  final_snapshot_identifier = "${local.app_name}-${random_id.snapshot_identifier.id}"

}

resource "aws_rds_cluster_instance" "writer" {
  cluster_identifier = aws_rds_cluster.postgres[0].cluster_identifier
  instance_class     = "db.t3.medium"
  publicly_accessible = false
  engine =  aws_rds_cluster.postgres[0].engine
  engine_version =  aws_rds_cluster.postgres[0].engine_version
}

resource "aws_rds_cluster_instance" "reader" {
  cluster_identifier = aws_rds_cluster.postgres[0].cluster_identifier
  instance_class     = "db.t3.medium"
  publicly_accessible = false
  engine =  aws_rds_cluster.postgres[0].engine
  engine_version =  aws_rds_cluster.postgres[0].engine_version
}

## The master username for postgres
resource "aws_secretsmanager_secret" "postgres_master_username" {
  count = var.create_shared_resources ? 1 : 0
  name  = "${local.secret_resource_prefix}database_master_username"
}

resource "aws_secretsmanager_secret_version" "postgres_master_username" {
  count         = var.create_shared_resources ? 1 : 0
  secret_id     = aws_secretsmanager_secret.postgres_master_username[0].id
  secret_string = aws_rds_cluster.postgres[0].master_username
}


## The master password for postgres
resource "aws_secretsmanager_secret" "postgres_master_password" {
  count = var.create_shared_resources ? 1 : 0
  name  = "${local.secret_resource_prefix}database_master_password"
}

resource "aws_secretsmanager_secret_version" "postgres_master_password" {
  count         = var.create_shared_resources ? 1 : 0
  secret_id     = aws_secretsmanager_secret.postgres_master_password[0].id
  secret_string = aws_rds_cluster.postgres[0].master_password
}



## The master password for postgres
resource "aws_secretsmanager_secret" "postgres_host" {
  count = var.create_shared_resources ? 1 : 0
  name  = "${local.secret_resource_prefix}postgres_host"
}

resource "aws_secretsmanager_secret_version" "postgres_host" {
  count         = var.create_shared_resources ? 1 : 0
  secret_id     = aws_secretsmanager_secret.postgres_host[0].id
  secret_string = "${aws_rds_cluster.postgres[0].endpoint}:5432"
}
