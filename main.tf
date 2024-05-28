terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    random = {
      source = "hashicorp/random"
      version = "3.4.3"
    }
  }
  required_version = ">= 1.1.0"
}

resource "random_string" "storage_id" {
  length = 14
  upper   = false
  special = false
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "crcrg"
  location = "eastus"
}

resource "azurerm_dns_zone" "zone" {
  name                = "hessig.cloud"
  resource_group_name = azurerm_resource_group.rg.name
}

# resource "azurerm_dns_a_record" "a_record" {
#   name                = "www"
#   zone_name           = azurerm_dns_zone.zone.name
#   resource_group_name = azurerm_resource_group.rg.name
#   ttl                 = 300
#   records             = ["x.x.x.x"]
# }

output "name_servers" {
  description = "The nameservers for the DNS zone"
  value       = azurerm_dns_zone.zone.name_servers
}

resource "azurerm_storage_account" "storage" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.rg.location
  name                     = "crcstorage${random_string.storage_id.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  static_website {
    index_document = "index.html"
    error_404_document = "404.html"
  }
}

resource "azurerm_storage_blob" "blob" {
  for_each = fileset("${path.root}/static/", "**/*" )
  name                   = trimprefix(each.key, "static/")
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type = (length(regexall(".*\\.html$", each.key)) > 0 ? "text/html" : "application/octet-stream")
  source = "${path.root}/static/${each.key}"
}

resource "azurerm_cdn_profile" "cdn_profile" {
  location            = azurerm_resource_group.rg.location
  name                = "crc-cdn-profile"
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "cdn_endpoint" {
  location            = azurerm_resource_group.rg.location
  name                = "hessig-crc"
  profile_name        = azurerm_cdn_profile.cdn_profile.name
  resource_group_name = azurerm_resource_group.rg.name
  origin_host_header = azurerm_storage_account.storage.primary_web_host
  origin {
    host_name = azurerm_storage_account.storage.primary_web_host
    name      = "crc-cdn-origin"
  }
  optimization_type = "GeneralWebDelivery"
}


resource "azurerm_dns_cname_record" "cname" {
  name                = "www"
  zone_name           = azurerm_dns_zone.zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  record              = azurerm_cdn_endpoint.cdn_endpoint.fqdn
}

