variable "domain_name" {
  description = "Domain name for project"
}

variable "resource_group_name" {
  default = "crc"
}

variable "azure_region" {
  default = "Central US"
}

variable "env_tag" {
  description = "Environment variable pass by Github Workflow"
}

variable "key_vault_name" {
  description = "Key Vault Name"
}

variable "key_vault_rg" {
  description = "Key Vault Resource Group"
}

variable "alert_email" {
  description = "E-mail address for Monitor alerts"
}

variable "webhook_url" {
  description = "Webhook for Monitor alerts"
}

variable "alert_sms" {
  description = "Phone number for SMS alerts."
}

variable "cloudflare_api_token" {
  description = "CloudFlare API token for authentication"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "CloudFlare domain zone ID"
  type        = string
  sensitive   = true
}

variable "github_actions_ips" {
  description = "Filtered GitHub Actions IP addresses (CIDR /0-/30 only)"
  type        = list(string)
}