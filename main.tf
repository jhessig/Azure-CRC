terraform {
  backend "azurerm" {}
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
  required_version = ">= 1.1.0"
}

resource "random_string" "storage_id" {
  length  = 10
  upper   = false
  special = false
}

provider "azurerm" {
  features {}
}

### Set up front end.
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}-${var.env_tag}-rg"
  location = "eastus"
  tags = {
    environment = var.env_tag
  }
}

resource "azurerm_dns_zone" "zone" {
  name                = "${var.sld_name}.${var.tld_name}"
  resource_group_name = azurerm_resource_group.rg.name
}

output "name_servers" {
  description = "The nameservers for the DNS zone"
  value       = azurerm_dns_zone.zone.name_servers
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
  name                     = "${var.resource_group_name}storage${random_string.storage_id.result}"
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

resource "azurerm_storage_blob" "blob" {
  for_each               = fileset("${path.root}/static/", "**/*")
  name                   = trimprefix(each.key, "static/")
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = (length(regexall(".*\\.html$", each.key)) > 0 ? "text/html" : "application/octet-stream")
  source                 = "${path.root}/static/${each.key}"
}

resource "azurerm_cdn_profile" "cdn_profile" {
  location            = azurerm_resource_group.rg.location
  name                = "${var.resource_group_name}-cdn-profile-${var.env_tag}"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "cdn_endpoint" {
  location            = azurerm_resource_group.rg.location
  name                = "${var.sld_name}-${var.tld_name}-${var.resource_group_name}-${var.env_tag}"
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
  name     = "${var.resource_group_name}-${var.env_tag}-api-rg"
  location = "eastus"
  tags = {
    environment = var.env_tag
  }
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
  location            = azurerm_resource_group.api_rg.location
  name                = "${var.resource_group_name}-cosmos-${var.env_tag}-${random_string.storage_id.result}"
  offer_type          = "Standard"
  resource_group_name = azurerm_resource_group.api_rg.name
  kind                = "GlobalDocumentDB"
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

resource "azurerm_storage_account" "api_storage" {
  account_replication_type = "GRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.api_rg.location
  name                     = "${var.resource_group_name}apistorage${random_string.storage_id.result}"
  resource_group_name      = azurerm_resource_group.api_rg.name
  min_tls_version          = "TLS1_2"
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

resource "azurerm_app_service_plan" "app_service_plan" {
  name                = "azure-functions-${var.resource_group_name}-${var.env_tag}"
  location            = azurerm_resource_group.api_rg.location
  resource_group_name = azurerm_resource_group.api_rg.name
  kind                = "Linux"
  reserved            = true
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
  lifecycle {
    ignore_changes = [
      kind
    ]
  }
}

resource "azurerm_function_app" "function_app" {
  name                       = "${var.resource_group_name}-${var.env_tag}-azure-function"
  location                   = azurerm_resource_group.api_rg.location
  resource_group_name        = azurerm_resource_group.api_rg.name
  app_service_plan_id        = azurerm_app_service_plan.app_service_plan.id
  storage_account_name       = azurerm_storage_account.api_storage.name
  storage_account_access_key = azurerm_storage_account.api_storage.primary_access_key
  os_type                    = "linux"
  version                    = "~4"
  app_settings {
    FUNCTIONS_WORKER_RUNTIME = "python"
  }
  site_config {
    linux_fx_version = "python|3.11"
  }
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
  value = "https://${azurerm_storage_account.storage.primary_web_host}"
}

output "env_tag" {
  value = var.env_tag
}