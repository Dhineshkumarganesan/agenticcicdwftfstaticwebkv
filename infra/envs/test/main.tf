terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    # Injected at runtime via -backend-config flags in CI.
    # See docs/ONBOARDING.md for the bootstrap scripts that create this backend.
  }
}

provider "azurerm" {
  features {}
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  tags = merge(var.tags, {
    environment = var.environment
    project     = var.project
    managed_by  = "terraform"
    source_repo = "agenticcicdwftfstaticwebkv"
  })
}

# ---------------------------------------------------------------------------
# Resources — scaffolded via @terraform-module-expert Copilot agent
# Source: cicd/contract.yml → type: storage_account, purpose: static_website_hosting
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}-${var.environment}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "web" {
  name                     = "st${var.project}${var.environment}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  static_website {
    index_document     = "index.html"
    error_404_document = "404.html"
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.web.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}