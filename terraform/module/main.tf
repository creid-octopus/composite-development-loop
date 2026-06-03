locals {
  name_base = "${var.resource_prefix}-${var.environment}"

  # Tags applied to the production web app slot for Octopus Cloud Target Discovery.
  # Octopus uses these to register the app as a deployment target automatically.
  cloud_target_discovery_tags = {
    "octopus-environment" = var.environment
    "octopus-role"        = "development-loop"
    "octopus-project"     = "Composite Development Loop"
  }

  # Feature slot gets a distinct environment tag so Octopus discovers it separately.
  feature_slot_tags = {
    "octopus-environment" = "${var.environment}-feature"
    "octopus-role"        = "development-loop"
    "octopus-project"     = "Composite Development Loop"
  }
}

# ── Random suffix ────────────────────────────────────────────────────────────────
# Appended to the web app name for global uniqueness. Keepers ensure the suffix
# stays stable across re-applies as long as the environment label doesn't change.

resource "random_string" "suffix" {
  length  = 5
  special = false
  keepers = {
    environment = var.environment
  }
}

# ── Resource Group ───────────────────────────────────────────────────────────────
# Each module instance owns its own resource group, so targeted teardown
# (terraform destroy -target=module.web_app_dev) cleans up everything cleanly.

resource "azurerm_resource_group" "rg" {
  name     = local.name_base
  location = var.location
}

# ── App Service Plan ─────────────────────────────────────────────────────────────

resource "azurerm_service_plan" "plan" {
  name                = "${local.name_base}-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.sku_name
}

# ── Web App (production slot) ────────────────────────────────────────────────────

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
    APP_ENV                  = var.environment
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  https_only = true
  tags       = local.cloud_target_discovery_tags
}

# ── Feature Slot ─────────────────────────────────────────────────────────────────
# Used for feature branch deployments. Octopus discovers this as a separate target
# via the feature_slot_tags (octopus-environment = "<env>-feature").

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
    APP_ENV                  = "${var.environment}-feature"
    WEBSITE_RUN_FROM_PACKAGE = "1"
  }

  https_only = true
  tags       = local.feature_slot_tags
}
