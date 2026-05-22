terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  # Use the Azure CLI for authentication to ensure the correct subscription is used
  features {}
}

locals {
  name_base = "${var.resource_prefix}-${var.environment}"
}

# -- Random ID for uniqueness -──────────────────────────────────────────────────────────────

resource "random_string" "suffix" {
  length  = 5
  special = false
}

# ── Resource Group ──────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "rg" {
  name     = local.name_base
  location = var.location
}

# ── App Service Plan ────────────────────────────────────────────────────────────

resource "azurerm_service_plan" "plan" {
  name                = "${local.name_base}-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.sku_name
}

# ── Web App ─────────────────────────────────────────────────────────────────────

resource "azurerm_linux_web_app" "app" {
  name                = "${local.name_base}-app-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.plan.location
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    application_stack {
      node_version = "24-lts"
    }
    always_on = true
  }

  app_settings = {
    # Populated by Octopus during deployment
    APP_ENV         = var.environment
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  https_only = true
}

# ── Deployment Slot (feature-branch testing) ────────────────────────────────────

resource "azurerm_linux_web_app_slot" "feature" {
  name           = "feature"
  app_service_id = azurerm_linux_web_app.app.id

  site_config {
    application_stack {
      node_version = "24-lts"
    }
    always_on = true
  }

  app_settings = {
    APP_ENV         = "${var.environment}-feature"
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  https_only = true
}
