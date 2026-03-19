data "azurerm_key_vault" "key_vault" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_rg
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/function-app/"
  output_path = "${path.module}/functions.zip"
}
