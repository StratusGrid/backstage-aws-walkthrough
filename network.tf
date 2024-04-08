resource "aws_route53_zone" "backstage" {
  name = var.backstage_domain_name
}

resource "aws_route53_record" "backstage" {
  zone_id = aws_route53_zone.backstage.zone_id
  name    = local.name
  type    = "A"

  alias {
    name                   = aws_alb.backstage.dns_name
    zone_id                = aws_alb.backstage.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = local.domain_name
  validation_method = "DNS"
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = aws_route53_zone.backstage.zone_id
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
}

resource "aws_eip" "nat_gw" {
  for_each = toset(module.vpc_microservices.azs)
  domain   = "vpc"

  tags = merge(
    local.common_tags,
    {
      "Name" = "${local.name}-nat-gw"
    },
  )
}

module "vpc_microservices" {
  source  = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=7666869d9ca7ff658f5bd10a29dea53bde5dc464"
  name    = "${local.name}-vpc"
  cidr    = "10.${var.vpc_cidr_octet}.0.0/19"

  azs = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = [
    "10.${var.vpc_cidr_octet}.0.0/23",
    "10.${var.vpc_cidr_octet}.2.0/23",
    "10.${var.vpc_cidr_octet}.4.0/23"
  ]
  database_subnets = [
    "10.${var.vpc_cidr_octet}.10.0/24",
    "10.${var.vpc_cidr_octet}.11.0/24",
    "10.${var.vpc_cidr_octet}.12.0/24"
  ]
  public_subnets = [
    "10.${var.vpc_cidr_octet}.20.0/23",
    "10.${var.vpc_cidr_octet}.22.0/23",
    "10.${var.vpc_cidr_octet}.24.0/23"
  ]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  reuse_nat_ips        = true
  external_nat_ip_ids  = toset([for nat_gw in aws_eip.nat_gw : nat_gw.id])
  enable_dns_hostnames = true

  enable_vpn_gateway           = false
  create_database_subnet_group = true #Needs to be made before any RDS to eliminate count cannot be computed error.

  tags = merge(local.common_tags, {})
  public_subnet_tags = {
    "subnet_type" = "public"
  }
  private_subnet_tags = {
    "subnet_type" = "private"
  }
  database_subnet_tags = {
    "subnet_type" = "database"
  }
  database_subnet_group_tags = {
    "Name" = "${local.name}-database-subnet-group"
  }
}

resource "aws_security_group" "https" {
  name        = "https-${local.name}"
  description = "HTTPS traffic"
  vpc_id      = module.vpc_microservices.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description = "Allow ingress on 443"
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = [var.allowed_cidr]
  }
}

resource "aws_security_group" "egress_all" {
  name        = "egress-all-${local.name}"
  description = "Allow all outbound traffic"
  vpc_id      = module.vpc_microservices.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress_from_lb" {
  name        = "ingress-from-lb-${local.name}"
  description = "Allow ingress from lb"
  vpc_id      = module.vpc_microservices.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description = "Allow ingress on 3000"
    from_port       = 3000
    to_port         = 3000
    protocol        = "TCP"
    security_groups = [aws_security_group.https.id]
  }
}

resource "aws_security_group" "ingress_from_ecs" {
  name        = "ingress-from-ecs-${local.name}"
  description = "Allow ingress from ecs"
  vpc_id      = module.vpc_microservices.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description = "Allow ingress on 5432"
    from_port       = 5432
    to_port         = 5432
    protocol        = "TCP"
    security_groups = [aws_security_group.ingress_from_lb.id]
  }
}
