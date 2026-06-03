# devloop-demo

Sample project for an inner development loop demo using **Octopus Deploy** and **Azure Web Apps**.

## Structure

```
.
├── terraform/
│   ├── main.tf                  # monorepo root — development + test modules, use -target
│   ├── variables.tf
│   ├── outputs.tf
│   ├── octopus.tfvars           # tokenized vars for Octopus CD runs
│   ├── terraform.tfvars.example # copy to local.tfvars for local testing
│   ├── README.md
│   ├── module/                  # reusable module — one env per instance
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── environments/            # alternative: isolated root per environment
│       ├── dev/                 #   plain apply, no -target needed
│       └── test/
├── src/                         # Node.js/Express demo app
│   ├── server.js
│   └── package.json
└── .github/
    └── workflows/
        ├── ci.yml               # every push/PR → build + package, no Octopus
        └── publish.yml          # main push → full release; manual dispatch → feature publish
```

## Infrastructure

Two approaches are provided — both use the same `module/` definition. See `terraform/README.md` for the full breakdown and tradeoffs.

**Monorepo root with `-target`** (mirrors a common customer pattern):

```bash
cd terraform
cp terraform.tfvars.example local.tfvars
# edit local.tfvars — set resource_prefix and location
terraform init
terraform apply -var-file=local.tfvars -target=module.web_app_development
terraform apply -var-file=local.tfvars -target=module.web_app_test
```

**Separate environment roots** (directory is the targeting mechanism):

```bash
cd terraform/environments/dev
terraform init && terraform apply -var-file=octopus.tfvars
```

Each environment provisions a resource group, App Service Plan, Linux Web App, and a **feature** deployment slot — so feature-branch builds deploy without needing a second app instance.

After apply, check outputs:

```bash
# Monorepo root
terraform output -json webapp_configuration | jq '.development.app_url'
terraform output -json webapp_configuration | jq '.test.app_url'

# Environment root
cd terraform/environments/dev && terraform output
```

## Running locally

```bash
cd src
npm install
npm run dev          # uses node --watch for live reload
```

The app reads build metadata from `.build-env` (stamped by CI) and falls back to sensible local defaults when the file isn't present. Visit `http://localhost:3000` to see the deployment dashboard.

## Branch → deployment flow

| Trigger | Workflow | Octopus version | Deploy target |
|---|---|---|---|
| Any push / PR | `ci.yml` | n/a (not published) | — validates only |
| Push to `main` | `publish.yml` | `1.0.<run>` | Development (auto), staging/prod via lifecycle |
| Manual dispatch on `feature/**` | `publish.yml` | `0.0.0-feature-<slug>.<n>` | Feature slot (manual trigger in Octopus) |

### Planned expansion

The branch model is designed to grow towards:
`individual_dev_story/**` → `feature/**` → `main`

Each layer adds a composable deployment activity in Octopus without changing the mainline release process.

## GitHub secrets required

| Secret | Description |
|---|---|
| `OCTOPUS_SERVER_URL` | Your Octopus instance URL |
| `OCTOPUS_API_KEY` | Service account API key with package push + release create permissions |
| `OCTOPUS_SPACE` | Octopus space name or ID |

## Teardown

```bash
# Monorepo root — tear down one environment
cd terraform
terraform destroy -var-file=local.tfvars -target=module.web_app_development

# Environment root — tear down in isolation
cd terraform/environments/dev
terraform destroy -var-file=octopus.tfvars
```
