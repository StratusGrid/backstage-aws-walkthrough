resource "random_password" "master" {
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${local.name}-pg-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.master.result
}

resource "aws_db_subnet_group" "backstage" {
  name = local.name
  subnet_ids = module.vpc_microservices.database_subnets
}

resource "aws_rds_cluster" "postgresql" {
  cluster_identifier      = local.name
  engine                  = "aurora-postgresql"
  availability_zones      = ["us-east-1a", "us-east-1b", "us-east-1c"]
  db_subnet_group_name    = aws_db_subnet_group.backstage.name
  database_name           = replace(local.name, "-", "")
  final_snapshot_identifier = "${local.name}-${lower(random_string.random.result)}"
  master_username         = replace(local.name, "-", "")
  master_password         = aws_secretsmanager_secret_version.password.secret_string
  backup_retention_period = 5
  vpc_security_group_ids  = [aws_security_group.ingress_from_ecs.id]
  preferred_backup_window = "07:00-09:00"
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = 2
  identifier         = "${local.name}-${count.index}"
  cluster_identifier = aws_rds_cluster.postgresql.id
  instance_class     = "db.t4g.medium"
  engine             = aws_rds_cluster.postgresql.engine
  engine_version     = aws_rds_cluster.postgresql.engine_version
}
