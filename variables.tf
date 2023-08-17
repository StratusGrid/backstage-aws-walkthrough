variable "region" {
  description = "AWS Region to target"
  type        = string
}

variable "env_name" {
  description = "Environment name string to be used for decisions and name generation"
  type        = string
}

variable "source_repo" {
  description = "name of repo which holds this code"
  type        = string
}

variable "vpc_cidr_octet" {
  description = "Second CIDR octet for VPC."
  type        = number
}

variable "application_name" {
  description = "The name of the application to deploy."
  type        = string
}

variable "docker_image" {
  description = "The docker image to deploy."
  type        = string
}

variable "allowed_cidr" {
  description = "Allow given IP CIDR access to Backstage."
  type        = string
}

variable "backstage_domain_name" {
  description = "Domain name for Backstage."
  type        = string
}
