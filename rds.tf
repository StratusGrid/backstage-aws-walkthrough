resource "random_password" "master" {
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name}-pg-password"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.backstage_key.arn
}

resource "aws_secretsmanager_secret_version" "password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.master.result
}

resource "aws_db_subnet_group" "backstage" {
  name       = local.name
  subnet_ids = module.vpc_microservices.database_subnets
}

resource "aws_rds_cluster" "postgresql" {
  cluster_identifier                  = local.name
  engine                              = "aurora-postgresql"
  availability_zones                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  db_subnet_group_name                = aws_db_subnet_group.backstage.name
  database_name                       = replace(local.name, "-", "")
  final_snapshot_identifier           = "${local.name}-${lower(random_string.random.result)}"
  master_username                     = replace(local.name, "-", "")
  master_password                     = aws_secretsmanager_secret_version.password.secret_string
  backup_retention_period             = 5
  vpc_security_group_ids              = [aws_security_group.ingress_from_ecs.id]
  preferred_backup_window             = "07:00-09:00"
  copy_tags_to_snapshot               = true
  storage_encrypted                   = true
  iam_database_authentication_enabled = true
  kms_key_id                          = aws_kms_key.backstage_key.arn
}

resource "aws_iam_role" "rds_monitoring_role" {
  name = "rds_monitoring_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "rds_monitoring_policy" {
  name = "rds_monitoring_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:CreateLogStream"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_policy_attachment" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = aws_iam_policy.rds_monitoring_policy.arn
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count                           = 2
  identifier                      = "${local.name}-${count.index}"
  cluster_identifier              = aws_rds_cluster.postgresql.id
  instance_class                  = "db.t4g.medium"
  engine                          = aws_rds_cluster.postgresql.engine
  engine_version                  = aws_rds_cluster.postgresql.engine_version
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.backstage_key.arn
  auto_minor_version_upgrade      = true
  monitoring_interval             = 5
  monitoring_role_arn             = aws_iam_role.rds_monitoring_role.arn
}
