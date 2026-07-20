# composite-development-loop

Demo project for an inner development loop built on **Octopus Deploy**, **Azure Web Apps**, and **Kubernetes**. Covers infrastructure provisioning, multi-target deployments, container image delivery, and supply chain security in a single walkthrough repo.

## Directory structure

```
.
├── src/                         # Node.js/Express app
│   ├── server.js                # serves build info at / and /health
│   └── package.json
│
├── Dockerfile                   # multi-stage: --target debug (node:24-slim)
│                                #              --target release (distroless)
│
├── k8s/                         # Kubernetes manifests, one folder per environment
│   ├── development/
│   │   ├── configmap.yaml       # APP_ENV and runtime config
│   │   ├── deployment.yaml      # image ref, probes, resource limits
│   │   └── service.yaml         # LoadBalancer → port 80
│   ├── test/
│   └── production/
│
├── terraform/
│   ├── main.tf                  # monorepo root — development + test modules
│   ├── variables.tf
│   ├── outputs.tf
│   ├── octopus.tfvars           # variable file for Octopus CD runs
│   ├── terraform.tfvars.example # copy to local.tfvars for local testing
│   ├── module/                  # reusable module — one env per instance
│   └── environments/            # alternative: isolated root per environment
│       ├── dev/
│       └── test/
│
├── octopus_base_package/        # minimal package for Octopus scenario testing
│   ├── hello-world.sh
│   ├── hello-world.ps1
│   └── VERSION                  # base version for testbed-package.yml bumps
│
├── .octopus/                    # Octopus Config as Code (CaC) — deployment process,
│   └── ...                      # variables, and runbooks tracked in source control
│
└── .github/
    ├── dependabot.yml           # weekly grouped updates for all GHA action versions
    └── workflows/
        ├── ci.yml
        ├── publish.yml
        ├── build-image.yml
        └── testbed-package.yml
```

## Workflows

| Workflow | Trigger | Intent |
|---|---|---|
| `ci.yml` | Every push and PR | Build, package, and filesystem vulnerability scan. No Octopus interaction. Acts as an always-on dry run — if this passes, the code is publishable. |
| `publish.yml` | Push to `main` (src/** only) or manual dispatch | Packages the app, pushes to Octopus built-in feed, creates a release, and auto-deploys to Development on main. Feature branches via dispatch only. |
| `build-image.yml` | Push to `main` (src/** or Dockerfile) or manual dispatch | Builds and pushes a container image to GHCR. Main builds use the `release` (distroless) target and are attested. Feature/RC images are manual dispatch — pick the branch and `debug` target in the GitHub UI. Also runs a Trivy image scan after push. |
| `testbed-package.yml` | Manual dispatch only | Pushes a minimal package to Octopus for scenario testing (variable behaviour, channel routing, etc.). Supports version bump, prerelease tag, and exact version override inputs. |

## Built artifacts

| Artifact | Produced by | Format | Destination |
|---|---|---|---|
| App package | `publish.yml` | `.zip` | Octopus built-in feed |
| Container image | `build-image.yml` | OCI image | `ghcr.io/<owner>/<repo>` |
| Testbed package | `testbed-package.yml` | `.zip` | Octopus built-in feed |
| Vulnerability report | `ci.yml`, `build-image.yml` | SARIF | GitHub Security tab |
| Build provenance | `build-image.yml` (main only) | SLSA attestation | GitHub attestation store |

### Image tags

Each image build produces two tags — no `latest`:

```
ghcr.io/<owner>/<repo>:1.0.42              # semver — use in Octopus references
ghcr.io/<owner>/<repo>:1.0.42-sha-a1b2c3d  # SHA-pinned — use in k8s manifests
```

Verify release attestation:
```bash
gh attestation verify oci://ghcr.io/<owner>/<repo>:1.0.42 --repo <owner>/<repo>
```

## Infrastructure (Terraform)

Two approaches are provided — both use the same `module/` definition. See `terraform/README.md` for tradeoffs.

**Monorepo root with `-target`** (mirrors a common customer pattern):

```bash
cd terraform
cp terraform.tfvars.example local.tfvars
terraform init
terraform apply -var-file=local.tfvars -target=module.web_app_development
terraform apply -var-file=local.tfvars -target=module.web_app_test
```

**Separate environment roots** (directory is the targeting mechanism):

```bash
cd terraform/environments/dev
terraform init && terraform apply -var-file=octopus.tfvars
```

Each environment provisions a resource group, App Service Plan, Linux Web App, and a **feature** deployment slot. Check outputs after apply:

```bash
# Monorepo root
terraform output -json webapp_configuration | jq '.development.app_url'

# Environment root
cd terraform/environments/dev && terraform output
```

## Running locally

```bash
cd src && npm install && npm run dev
```

Visits `http://localhost:3000` — the app reads build metadata from `.build-env` (stamped by CI) and falls back to local defaults when the file isn't present. The `/health` endpoint returns the full build info as JSON.

For the container:

```bash
# Debug image (has shell)
docker build --target debug -t devloop-demo:local .
docker run -p 3000:3000 -e APP_ENV=local devloop-demo:local

# Release image (distroless)
docker build --target release -t devloop-demo:local .
docker run -p 3000:3000 -e APP_ENV=local devloop-demo:local
```

## GitHub secrets required

| Secret | Description |
|---|---|
| `OCTOPUS_SERVER_URL` | Octopus instance URL |
| `OCTOPUS_API_KEY` | API key with package push + release create permissions |
| `OCTOPUS_SPACE` | Space name or ID |

`GITHUB_TOKEN` is used automatically by `build-image.yml` for GHCR — no configuration needed.

## Teardown

```bash
# Monorepo root
cd terraform
terraform destroy -var-file=local.tfvars -target=module.web_app_development

# Environment root
cd terraform/environments/dev
terraform destroy -var-file=octopus.tfvars
```
