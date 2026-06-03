# terraform/

Provisions two isolated Azure environments (`development` and `test`) for the devloop demo. Each environment is a self-contained module instance with its own resource group, App Service Plan, Web App, and feature deployment slot.

This directory demonstrates **two valid approaches** to multi-environment Terraform — both backed by the same reusable module in `module/`. The approach you use depends on how your pipeline is structured.

## Approaches

### 1. Monorepo root with `-target` (`terraform/`)

Both environments live in a single Terraform root and a single state file. `-target` controls which environment is touched on a given apply. This mirrors a common customer pattern where infrastructure for multiple environments lives together and targeted applies avoid unintended state changes.

```bash
# Touch only development
terraform apply -var-file=local.tfvars -target=module.web_app_development

# Touch only test
terraform apply -var-file=local.tfvars -target=module.web_app_test

# Apply or destroy everything
terraform apply -var-file=local.tfvars
terraform destroy -var-file=local.tfvars
```

Octopus runbook points to `terraform/` and passes `-target` as a parameter.

### 2. Separate environment roots (`terraform/environments/`)

Each environment is its own Terraform root with isolated state. No `-target` needed — the directory is the targeting mechanism. Octopus runbooks point to the relevant folder.

```bash
cd environments/dev
terraform init
terraform apply -var-file=octopus.tfvars

cd environments/test
terraform init
terraform apply -var-file=octopus.tfvars
```

Both roots source the same `../../module`, so the infrastructure definition stays in one place.

## Tradeoffs

| | Monorepo root | Separate roots |
|---|---|---|
| State | Shared | Isolated per environment |
| Targeting | `-target` flag | Directory selection |
| Drift between envs | Visible in one plan | Separate plan per env |
| Adding an environment | New module block | New folder |
| Octopus runbook | One runbook, parameterised target | One runbook per environment |

## What gets created (per environment)

| Resource | development | test |
|---|---|---|
| Resource Group | `<prefix>-development` | `<prefix>-test` |
| App Service Plan | `<prefix>-development-plan` | `<prefix>-test-plan` |
| Web App | `<prefix>-development-app-<suffix>` | `<prefix>-test-app-<suffix>` |
| Feature Slot | `<prefix>-development-app-<suffix>/feature` | `<prefix>-test-app-<suffix>/feature` |

The random suffix is stable across re-applies (keyed on environment label).

## First-time setup (monorepo root)

```bash
cp terraform.tfvars.example local.tfvars
# edit local.tfvars — set your resource_prefix and location
terraform init
```

## First-time setup (environment roots)

```bash
cd environments/dev
terraform init

cd ../test
terraform init
```

Each environment root has its own backend state key and must be initialised independently.

## Outputs

### Monorepo root

`terraform output` returns a `webapp_configuration` map across both environments:

```
webapp_configuration = {
  development = {
    app_name            = "creid-devloop-development-app-ab1cd"
    app_url             = "https://creid-devloop-development-app-ab1cd.azurewebsites.net"
    resource_group_name = "creid-devloop-development"
    slot_url            = "https://creid-devloop-development-app-ab1cd-feature.azurewebsites.net"
  }
  test = { ... }
}
```

```bash
terraform output -json webapp_configuration | jq '.development.app_url'
```

### Environment roots

Each root exposes the same outputs scoped to its own environment:

```bash
cd environments/dev && terraform output
# app_url, feature_slot_url, app_name, resource_group_name
```

## Variables

| Variable | Default | Description |
|---|---|---|
| `location` | `Central US` | Azure region for all resources |
| `resource_prefix` | `creid-devloop` | Prefix applied to all resource names |
| `sku_name` | `S1` | App Service Plan SKU — must support deployment slots |

`environment` is not a variable in any root. It is hardcoded per module instance (`"development"` / `"test"`) so the environment identity is structural, not runtime config.
