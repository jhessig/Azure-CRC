terraform {
  backend "azurerm" {}
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.107.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

data "azurerm_key_vault" "key_vault" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_rg
}

resource "random_string" "build_id" {
  length  = 10
  upper   = false
  special = false
}
### Set up front end.
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}-${var.env_tag}-rg-${random_string.build_id.result}"
  location = var.azure_region
  tags = {
    environment = var.env_tag
  }
}

resource "azurerm_dns_zone" "zone" {
  name                = "${var.sld_name}.${var.tld_name}"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_storage_account" "storage" {
  #checkov:skip=CKV2_AZURE_1:The storage account is a public static content host.
  #checkov:skip=CKV2_AZURE_33:The storage account is a public static content host.
  #checkov:skip=CKV2_AZURE_40:The storage account is a public static content host.
  #checkov:skip=CKV2_AZURE_41:The storage account is a public static content host.
  #checkov:skip=CKV2_AZURE_47:The storage account is a public static content host.
  #checkov:skip=CKV_AZURE_59:The storage account is a public static content host.
  #checkov:skip=CKV_AZURE_190:The storage account is a public static content host.
  account_replication_type = "GRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.rg.location
  name                     = "${var.resource_group_name}storage${random_string.build_id.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  min_tls_version          = "TLS1_2"
  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 10
    }
    hour_metrics {
      enabled               = true
      include_apis          = true
      version               = "1.0"
      retention_policy_days = 10
    }
    minute_metrics {
      enabled               = true
      include_apis          = true
      version               = "1.0"
      retention_policy_days = 10
    }
  }
}

# resource "azurerm_storage_blob" "blob" {
#   for_each               = fileset("${path.root}/static/", "**/*")
#   name                   = trimprefix(each.key, "static/")
#   storage_account_name   = azurerm_storage_account.storage.name
#   storage_container_name = "$web"
#   type                   = "Block"
#   content_type           = (length(regexall(".*\\.html$", each.key)) > 0 ? "text/html" : "application/octet-stream")
#   source                 = "${path.root}/static/${each.key}"
# }

resource "azurerm_key_vault_secret" "storage_account" {
  name         = "storage-account-name"
  value        = azurerm_storage_account.storage.name
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

resource "azurerm_key_vault_secret" "storage_key" {
  name         = "storage-account-key"
  value        = azurerm_storage_account.storage.primary_access_key
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

resource "azurerm_cdn_profile" "cdn_profile" {
  location            = azurerm_resource_group.rg.location
  name                = "${var.resource_group_name}-${var.env_tag}-cdnpf-${random_string.build_id.result}"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "cdn_endpoint" {
  ### AZURE CDN RETIRES September 30, 2027.
  location            = azurerm_resource_group.rg.location
  name                = "${var.resource_group_name}-${var.env_tag}-cdnep-${random_string.build_id.result}"
  profile_name        = azurerm_cdn_profile.cdn_profile.name
  resource_group_name = azurerm_resource_group.rg.name
  origin_host_header  = azurerm_storage_account.storage.primary_web_host
  is_http_allowed     = false
  origin {
    host_name = azurerm_storage_account.storage.primary_web_host
    name      = "${var.resource_group_name}-${var.env_tag}-cdn-origin"
  }
  optimization_type = "GeneralWebDelivery"
}

resource "azurerm_dns_a_record" "a_root" {
  name                = "@"
  zone_name           = azurerm_dns_zone.zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  target_resource_id  = azurerm_cdn_endpoint.cdn_endpoint.id
}

resource "azurerm_dns_cname_record" "www_cname" {
  name                = "www"
  zone_name           = azurerm_dns_zone.zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = azurerm_cdn_endpoint.cdn_endpoint.fqdn
}

resource "azurerm_dns_cname_record" "cdn_cname" {
  name                = "cdnverify"
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  zone_name           = azurerm_dns_zone.zone.name
  record              = "cdnverify.${azurerm_cdn_endpoint.cdn_endpoint.fqdn}"
}



### Set up API.
resource "azurerm_resource_group" "api_rg" {
  name     = "${var.resource_group_name}-${var.env_tag}-apirg-${random_string.build_id.result}"
  location = var.azure_region
  tags = {
    environment = var.env_tag
  }
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
  #checkov:skip=CKV_AZURE_99: "Ensure Cosmos DB accounts have restricted access" Review access restrictions TODO
  #checkov:skip=CKV_AZURE_100:Accepting default key management.
  #checkov:skip=CKV_AZURE_101: "Ensure that Azure Cosmos DB disables public network access" Review public access. TODO
  #checkov:skip=CKV_AZURE_140:Local authentication can only be disabled when using the SQL API.

  location                           = azurerm_resource_group.api_rg.location
  name                               = "${var.resource_group_name}-cosmos-${var.env_tag}-${random_string.build_id.result}"
  offer_type                         = "Standard"
  resource_group_name                = azurerm_resource_group.api_rg.name
  kind                               = "GlobalDocumentDB"
  public_network_access_enabled      = true
  access_key_metadata_writes_enabled = false
  consistency_policy {
    consistency_level = "Session"
  }
  capabilities {
    name = "EnableServerless"
  }
  capabilities {
    name = "EnableTable"
  }
  geo_location {
    failover_priority = 0
    location          = azurerm_resource_group.rg.location
  }
}

resource "azurerm_cosmosdb_table" "cosmosdb_table" {
  name                = "functions-cosmos-table"
  resource_group_name = azurerm_resource_group.api_rg.name
  account_name        = azurerm_cosmosdb_account.cosmosdb.name
}

resource "azurerm_storage_account" "api_storage" {
  #checkov:skip=CKV2_AZURE_1:Accepting default key management.
  #checkov:skip=CKV2_AZURE_33:Delaying private endpoint setup. TODO
  #checkov:skip=CKV2_AZURE_40:Cannot disable shared access key.
  #checkov:skip=CKV2_AZURE_41: "Ensure storage account is configured with SAS expiration policy" Review feasiblity TODO
  #checkov:skip=CKV2_AZURE_47: "Ensure storage account is configured without blob anonymous access" Review TODO
  #checkov:skip=CKV_AZURE_59: "Ensure that Storage accounts disallow public access" Review public access TODO
  #checkov:skip=CKV_AZURE_190: "Ensure that Storage blobs restrict public access" Review public access TODO
  account_replication_type = "GRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.api_rg.location
  name                     = "${var.resource_group_name}apistorage${random_string.build_id.result}"
  resource_group_name      = azurerm_resource_group.api_rg.name
  min_tls_version          = "TLS1_2"
  //allow_nested_items_to_be_public = false
  //public_network_access_enabled   = false
  //shared_access_key_enabled       = true
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
  //sas_policy {
  //  expiration_period = "90.00:00:00"
  //  expiration_action = "Log"
  //}
  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 10
    }
    hour_metrics {
      enabled               = true
      include_apis          = true
      version               = "1.0"
      retention_policy_days = 10
    }
    minute_metrics {
      enabled               = true
      include_apis          = true
      version               = "1.0"
      retention_policy_days = 10
    }
  }
}

resource "azurerm_service_plan" "service_plan" {
  #checkov:skip=CKV_AZURE_212:Scaling requires support request.
  #checkov:skip=CKV_AZURE_225:Zone redundancy requires premium account.
  name                = "azure-functions-${var.resource_group_name}-${var.env_tag}"
  resource_group_name = azurerm_resource_group.api_rg.name
  location            = azurerm_resource_group.api_rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/function-app/"
  output_path = "${path.module}/functions.zip"
}

resource "azurerm_linux_function_app" "linux_function-app" {
  #checkov:skip=CKV_AZURE_221: "Ensure that Azure Function App public network access is disabled" Review public access TODO
  name                          = "${var.resource_group_name}-${var.env_tag}-function-${random_string.build_id.result}"
  resource_group_name           = azurerm_resource_group.api_rg.name
  location                      = azurerm_resource_group.api_rg.location
  storage_account_name          = azurerm_storage_account.api_storage.name
  storage_account_access_key    = azurerm_storage_account.api_storage.primary_access_key
  service_plan_id               = azurerm_service_plan.service_plan.id
  https_only                    = true
  public_network_access_enabled = true
  app_settings = {
    "ENABLE_ORYX_BUILD"              = "true"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "AzureWebJobsFeatureFlags"       = "EnableWorkerIndexing"
    COSMOS_ENDPOINT                  = azurerm_cosmosdb_account.cosmosdb.endpoint
    COSMOS_KEY                       = azurerm_cosmosdb_account.cosmosdb.secondary_key
    COSMOS_DATABASE_NAME             = "TablesDB"
    COSMOS_CONTAINER_NAME            = azurerm_cosmosdb_table.cosmosdb_table.name
    COSMOS_CONN_STRING               = "AccountEndpoint=${azurerm_cosmosdb_account.cosmosdb.endpoint};AccountKey=${azurerm_cosmosdb_account.cosmosdb.primary_key};"
  }
  site_config {
    application_stack {
      python_version = "3.9"
    }
  }
  zip_deploy_file = data.archive_file.function.output_path
}

### Set CDN custom domains.
resource "azurerm_cdn_endpoint_custom_domain" "www" {
  count           = var.env_tag == "prod" ? 1 : 0
  name            = "www-domain"
  host_name       = "www.${var.sld_name}.${var.tld_name}"
  cdn_endpoint_id = azurerm_cdn_endpoint.cdn_endpoint.id
  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
  }
  depends_on = [azurerm_dns_cname_record.www_cname]
}

resource "azurerm_cdn_endpoint_custom_domain" "root" {
  count           = var.env_tag == "prod" ? 1 : 0
  name            = "root-domain"
  host_name       = "${var.sld_name}.${var.tld_name}"
  cdn_endpoint_id = azurerm_cdn_endpoint.cdn_endpoint.id
  depends_on      = [azurerm_dns_cname_record.cdn_cname]
}

output "storage_url" {
  value     = "https://${azurerm_storage_account.storage.primary_web_host}"
  sensitive = true
}

output "env_tag" {
  value = var.env_tag
}