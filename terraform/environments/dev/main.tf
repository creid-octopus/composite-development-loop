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
    key                  = "creid-devloop-dev.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Single module instance — this root owns the dev environment exclusively.
# No -target needed: applying here only ever touches dev resources.
# Octopus runbook points to this directory for dev environment provisioning.

module "web_app" {
  source          = "../../module"
  environment     = "dev"
  location        = var.location
  resource_prefix = var.resource_prefix
  sku_name        = var.sku_name
}
