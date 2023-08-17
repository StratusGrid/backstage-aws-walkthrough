resource "aws_ecs_cluster" "backstage" {
  name = local.name
}

resource "aws_cloudwatch_log_group" "backstage" {
  name = "/ecs/${local.name}"
}

resource "aws_ecs_service" "backstage" {
  name            = local.name
  task_definition = data.aws_ecs_task_definition.backstage.arn
  cluster         = aws_ecs_cluster.backstage.id
  launch_type     = "FARGATE"
  propagate_tags  = "SERVICE"

  desired_count = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.backstage.arn
    container_name   = local.name
    container_port   = "3000"
  }

  network_configuration {
    assign_public_ip = false

    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_from_lb.id,
    ]

    subnets = module.vpc_microservices.private_subnets
  }
}

data "aws_ecs_task_definition" "backstage" {
  task_definition = aws_ecs_task_definition.backstage.family
}

resource "aws_ecs_task_definition" "backstage" {
  family = local.name

  container_definitions = <<EOF
  [
    {
      "name": "${local.name}",
      "environment": [
        {"name": "BASE_URL", "value": "https://${local.domain_name}"},
        {"name": "APP_CONFIG_app_baseUrl", "value": "https://${local.domain_name}"},
        {"name": "APP_CONFIG_backend_baseUrl", "value": "https://${local.domain_name}"},
        {"name": "PG_USERNAME", "value": "${replace(local.name, "-", "")}"},
        {"name": "PG_ENDPOINT", "value": "${aws_rds_cluster.postgresql.endpoint}"},
        {"name": "ENVIRONMENT", "value": "${var.env_name}"}
      ],
      "image": "${var.docker_image}",
      "secrets": [{
        "name": "PG_PASSWORD",
        "valueFrom": "${aws_secretsmanager_secret.db_password.arn}"
      }],
      "portMappings": [
        {
          "containerPort": 3000
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "${var.region}",
          "awslogs-group": "/ecs/${local.name}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]

EOF

  execution_role_arn = aws_iam_role.backstage.arn
  task_role_arn = aws_iam_role.backstage_task.arn

  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  depends_on               = [aws_secretsmanager_secret_version.password]

  network_mode = "awsvpc"
}

resource "aws_iam_role" "backstage" {
  name               = "${local.name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  inline_policy {
    name   = "policy-${local.name}-secrets"
    policy = data.aws_iam_policy_document.secrets_manager_access.json
  }
}

resource "aws_iam_role" "backstage_task" {
    name               = "${local.name}-task-role"
    assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
    inline_policy {
        name   = "policy-${local.name}-task-templates"
        policy = data.aws_iam_policy_document.template_bucket_access.json
  }
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "secrets_manager_access" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_password.arn]
  }
}

data "aws_iam_policy" "ecs_task_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "template_bucket_access" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.template_bucket.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.template_bucket.arn]
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.backstage.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role.arn
}

resource "aws_lb_target_group" "backstage" {
  name        = local.name
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc_microservices.vpc_id

  health_check {
    enabled = true
    path    = "/catalog"
  }

  depends_on = [aws_alb.backstage]
}

resource "aws_alb" "backstage" {
  name               = local.name
  internal           = false
  load_balancer_type = "application"

  subnets = module.vpc_microservices.public_subnets

  security_groups = [
    aws_security_group.https.id,
    aws_security_group.egress_all.id,
  ]
}

resource "aws_alb_listener" "backstage_http" {
  load_balancer_arn = aws_alb.backstage.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "backstage_https" {
  load_balancer_arn = aws_alb.backstage.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backstage.arn
  }
}
