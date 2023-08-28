resource "random_password" "postgres_master_password" {
  length  = 48
  special = false
}

resource "aws_db_subnet_group" "postgres" {
  name_prefix = "qimia-ai-${var.env}"
  subnet_ids  = [for subnet in aws_subnet.private : subnet.id]
}


resource "aws_security_group" "allow_tls" {
  name_prefix = "Qimia AI DB - ${var.env}"
  description = "Allow access to the Qimia AI database"
  vpc_id      = aws_vpc.the_vpc.id

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
  cluster_identifier        = "${local.app_name}-db"
  availability_zones        = [for zone_letter in ["a", "b", "c"] : "${var.region}${zone_letter}"]
  database_name             = "test_db"
  master_username           = "postgres"
  master_password           = random_password.postgres_master_password.result
  engine                    = "aurora-postgresql"
  engine_version            = "14.7"
  db_subnet_group_name      = aws_db_subnet_group.postgres.name
  vpc_security_group_ids    = [aws_security_group.allow_tls.id]
  final_snapshot_identifier = "${local.app_name}-${random_id.snapshot_identifier.id}"

}

resource "aws_rds_cluster_instance" "writer" {
  cluster_identifier  = aws_rds_cluster.postgres.cluster_identifier
  instance_class      = "db.t3.medium"
  publicly_accessible = false
  engine              = aws_rds_cluster.postgres.engine
  engine_version      = aws_rds_cluster.postgres.engine_version
}

resource "aws_rds_cluster_instance" "reader" {
  cluster_identifier  = aws_rds_cluster.postgres.cluster_identifier
  instance_class      = "db.t3.medium"
  publicly_accessible = false
  engine              = aws_rds_cluster.postgres.engine
  engine_version      = aws_rds_cluster.postgres.engine_version
}

## The master username for postgres
resource "aws_secretsmanager_secret" "postgres_master_username" {
  name = "${local.secret_resource_prefix}database_master_username"
}

resource "aws_secretsmanager_secret_version" "postgres_master_username" {
  secret_id     = aws_secretsmanager_secret.postgres_master_username.id
  secret_string = aws_rds_cluster.postgres.master_username
}


## The master password for postgres
resource "aws_secretsmanager_secret" "postgres_master_password" {
  name = "${local.secret_resource_prefix}database_master_password"
}

resource "aws_secretsmanager_secret_version" "postgres_master_password" {
  secret_id     = aws_secretsmanager_secret.postgres_master_password.id
  secret_string = aws_rds_cluster.postgres.master_password
}



## The master password for postgres
resource "aws_secretsmanager_secret" "postgres_host" {
  name = "${local.secret_resource_prefix}postgres_host"
}

resource "aws_secretsmanager_secret_version" "postgres_host" {
  secret_id     = aws_secretsmanager_secret.postgres_host.id
  secret_string = "${aws_rds_cluster.postgres.endpoint}:5432"
}
