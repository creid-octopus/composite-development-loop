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

  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "octotfstate"
    container_name       = "terraform-state"
    key                  = "creid-devloop.tfstate"
  }
}

provider "azurerm" {
  # Use the Azure CLI for authentication to ensure the correct subscription is used
  features {}
}

# ── Development environment ──────────────────────────────────────────────────────
# Standalone resource group, app service plan, web app, and feature slot.
# Environment label and Octopus discovery tags are computed inside the module.
# Target individually: terraform apply -target=module.web_app_dev

module "web_app_dev" {
  source          = "./module"
  environment     = "dev"
  location        = var.location
  resource_prefix = var.resource_prefix
  sku_name        = var.sku_name
}

# ── Test environment ─────────────────────────────────────────────────────────────
# Stable environment — mainline releases auto-deploy here via Octopus.
# Target individually: terraform apply -target=module.web_app_test

module "web_app_test" {
  source          = "./module"
  environment     = "test"
  location        = var.location
  resource_prefix = var.resource_prefix
  sku_name        = var.sku_name
}
