# devloop-demo

Sample project for an inner development loop demo using **Octopus Deploy** and **Azure Web Apps**.

## Structure

```
.
├── terraform/               # Azure infrastructure (azurerm)
│   ├── main.tf              #   Web App + feature deployment slot
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── src/                     # Node.js/Express demo app
│   ├── server.js
│   └── package.json
└── .github/
    └── workflows/
        ├── feature-build.yml    # feature/** → pre-release package → Octopus
        └── main-release.yml     # main → stable release → Octopus → auto-deploy to Test
```

## Infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars as needed
terraform init
terraform apply
```

Terraform creates a resource group, an App Service Plan, a Linux Web App, and a **feature** deployment slot on the same app — so feature-branch builds deploy without needing a second app instance.

After `apply`, check outputs for the URLs:

```bash
terraform output app_url          # production slot
terraform output feature_slot_url # feature slot
```

## Running locally

```bash
cd src
npm install
npm run dev          # uses node --watch for live reload
```

The app reads build metadata from environment variables (set by CI) and falls back to sensible local defaults. Visit `http://localhost:3000` to see the deployment dashboard.

## Branch → deployment flow

| Branch pattern | Workflow | Octopus version | Deploy target |
|---|---|---|---|
| `feature/**` | `feature-build.yml` | `0.0.0-feature-<slug>.<n>` | Feature slot (manual trigger) |
| `main` | `main-release.yml` | `1.0.<run>` | Test (auto), staging/prod via lifecycle |

### Planned expansion

The branch model is designed to grow towards:
`individual_dev_story/**` → `feature/**` → `main`

Each layer adds a composable deployment activity in Octopus without changing the mainline release process.

## GitHub secrets required

| Secret | Description |
|---|---|
| `OCTOPUS_SERVER_URL` | Your Octopus instance URL |
| `OCTOPUS_API_KEY` | Service account API key with package push + release create permissions |

## Teardown

```bash
cd terraform
terraform destroy
```
