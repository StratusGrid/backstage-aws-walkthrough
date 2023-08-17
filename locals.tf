locals {
  name        = "${var.env_name}-${var.application_name}"
  domain_name = "${local.name}.${var.backstage_domain_name}"
  is_prod     = var.env_name == "prd" ? true : false
  all_tags = merge(local.common_tags, local.sg_tags)
}
