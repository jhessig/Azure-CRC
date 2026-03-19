output "storage_url" {
  value     = "https://${azurerm_storage_account.storage.primary_web_host}"
  sensitive = true
}

output "api_url" {
  value     = "https://${azurerm_linux_function_app.linux_function_app.name}.azurewebsites.net/api/visitor_count"
  sensitive = true
}

output "env_tag" {
  value = var.env_tag
}
