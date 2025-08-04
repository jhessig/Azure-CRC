variable "tld_name" {
  default = "cloud"
}

variable "sld_name" {
  default = "hessig"
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