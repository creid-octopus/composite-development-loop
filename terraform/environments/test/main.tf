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
    key                  = "creid-devloop-test.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Single module instance — this root owns the test environment exclusively.
# No -target needed: applying here only ever touches test resources.
# Octopus runbook points to this directory for test environment provisioning.

module "web_app" {
  source          = "../../module"
  environment     = "test"
  location        = var.location
  resource_prefix = var.resource_prefix
  sku_name        = var.sku_name
}
