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
  default = "Canada Central"
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