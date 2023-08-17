locals {
  common_tags = {
    Environment = var.env_name
    Application = var.application_name
    Developer   = "StratusGrid"
    Provisioner = "Terraform"
    SourceRepo  = var.source_repo
  }
}
