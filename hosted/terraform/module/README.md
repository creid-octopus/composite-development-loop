# module/

Reusable Terraform module that provisions a single Azure Web App environment. Called twice from the root — once for `dev`, once for `test` — each instance is fully isolated.

## Resources created

| Resource | Purpose |
|---|---|
| `azurerm_resource_group` | Owns all resources in this environment — destroy the module, destroy everything |
| `azurerm_service_plan` | Linux App Service Plan (S1 or configured SKU) |
| `azurerm_linux_web_app` | Production slot — mainline releases deploy here |
| `azurerm_linux_web_app_slot` (`feature`) | Feature slot — branch builds deploy here manually |
| `random_string` | 5-char suffix appended to the web app name for global uniqueness |

## Octopus Cloud Target Discovery

Both the web app and feature slot are tagged for Octopus Cloud Target Discovery. Octopus uses these tags to register deployment targets automatically without manual configuration.

| Resource | `octopus-environment` tag |
|---|---|
| Web App | `dev` / `test` |
| Feature Slot | `dev-feature` / `test-feature` |

Both slots also carry `octopus-role = "development-loop"` and `octopus-project = "Composite Development Loop"`.

## Inputs

| Variable | Required | Default | Description |
|---|---|---|---|
| `environment` | yes | — | Short label used in resource names and tags (`dev`, `test`) |
| `location` | yes | — | Azure region |
| `resource_prefix` | yes | — | Prefix for all resource names |
| `sku_name` | no | `S1` | App Service Plan SKU — must support slots |

## Outputs

| Output | Description |
|---|---|
| `resource_group_name` | Name of the resource group (useful for az CLI targeting) |
| `app_name` | Web App name — used as the Octopus deployment target name |
| `app_url` | Production slot URL |
| `feature_slot_url` | Feature slot URL |

## Usage

This module is not intended to be called directly. See the root [`README.md`](../README.md) for `terraform apply` and `-target` usage.
