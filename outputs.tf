output "account_id" {
  description = "Account which terraform was run on"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  value = var.region
}

output "ns_records" {
  description = "Name server records of the Backstage hosted zone"
  value       = aws_route53_zone.backstage.name_servers
}

output "backstage_url" {
  description = "URL for accessing Backstage"
  value       = "https://${local.domain_name}"
}
