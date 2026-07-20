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

## Future considerations — OCI-native supply chain

The current supply chain approach uses GitHub-native tooling:
- `actions/attest-build-provenance` for SLSA provenance (stored in GitHub's attestation store)
- Trivy SBOM packaged as a zip and pushed to the Octopus built-in feed
- Verification via `gh attestation verify` (requires GitHub API access at verify time)

This works well for a GitHub-centric pipeline but is platform-tied. The direction the ecosystem is moving is **OCI-native supply chain** — everything attached to the image digest in the registry, verifiable without GitHub:

### Cosign (Sigstore)

[Cosign](https://github.com/sigstore/cosign) signs images and attaches signatures as OCI referrers in the registry. Unlike `actions/attest-build-provenance`, signatures live in GHCR alongside the image and are verifiable with the `cosign` CLI alone — no GitHub API required.

```bash
# Sign the image after push (in GHA, using keyless/OIDC)
cosign sign --yes ghcr.io/<owner>/<repo>@<digest>

# Verify anywhere
cosign verify ghcr.io/<owner>/<repo>:<tag> \
  --certificate-identity-regexp="https://github.com/<owner>/<repo>/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

Cosign and `actions/attest-build-provenance` are complementary: GitHub Attestations for SLSA provenance (GitHub-native, feeds `gh attestation verify`), Cosign for registry-portable signatures. Many production pipelines use both.

### OCI-attached SBOM (ORAS / Cosign attach)

Rather than packaging the SBOM as a zip pushed to Octopus, the SBOM can be attached directly to the image digest as an OCI referrer using [ORAS](https://oras.land) or Cosign:

```bash
# Attach SBOM to image (Cosign)
cosign attach sbom --sbom sbom.spdx.json ghcr.io/<owner>/<repo>@<digest>

# Or via ORAS
oras attach ghcr.io/<owner>/<repo>@<digest> \
  --artifact-type application/spdx+json \
  sbom.spdx.json
```

The SBOM then travels with the image in the registry — pull the image, the SBOM is co-located and fetchable by digest. Tools like `docker scout`, Grype, and any OCI-referrers-aware tool can discover and consume it without any separate distribution mechanism.

This is the emerging standard for container-native supply chain, but requires the consuming tooling (e.g. Octopus Deploy) to support OCI referrers for it to replace the packaged SBOM approach in a deployment pipeline.

### Why not now

- Octopus Deploy's OCI referrer support is not yet mature — the packaged SBOM approach is more reliable for the current demo pipeline
- Cosign keyless signing via OIDC works well in GHA but adds verification complexity in CD steps
- The current `actions/attest-build-provenance` + `gh attestation verify` approach is sufficient where GitHub API access is already required (e.g. for attestation validation in the Octopus pipeline)

## Future considerations — OIDC auth for Octopus

### Current approach

Workflows authenticate to Octopus using a long-lived `OCTOPUS_API_KEY` secret stored in GitHub. This works but carries the standard risks of static credentials: manual rotation, potential for key leakage, and no automatic expiry.

### What OIDC enables

GitHub Actions can request a short-lived OIDC token from GitHub's identity provider (`https://token.actions.githubusercontent.com`) — a signed JWT that asserts "this code is running in workflow X, repo Y, branch Z, right now." Octopus can be configured to trust this issuer, exchanging the GitHub token for a scoped Octopus access token that expires when the workflow run ends. No static secret is stored, no rotation schedule is needed, and a leaked token is useless after the run completes.

### What changes

**In Octopus:** Create a service account (Settings → Users → Service Accounts) with an OIDC identity configured for the GitHub org/repo. Grant it the permissions the workflows need (push packages, create releases, deploy). Note the service account ID.

**In GitHub:** Store the service account ID as a repo variable or secret. Add `id-token: write` to workflow permissions (already present in `build-image.yml` for attestation).

**In each workflow:** Add `OctopusDeploy/login@v1` before any Octopus step, remove `api_key` from all subsequent Octopus actions:

```yaml
permissions:
  id-token: write   # required for OIDC token request

- name: Login to Octopus Deploy
  uses: OctopusDeploy/login@v1
  with:
    server: ${{ vars.OCTOPUS_SERVER_URL }}
    service_account_id: ${{ vars.OCTOPUS_SERVICE_ACCOUNT_ID }}

# All subsequent Octopus steps — no api_key needed
- uses: OctopusDeploy/push-package-action@v4
  with:
    server: ${{ vars.OCTOPUS_SERVER_URL }}
    space: ${{ secrets.OCTOPUS_SPACE }}
    packages: ...
```

### Workflows affected

- `publish.yml` — `id-token: write` permission + login step + remove `api_key` from four steps
- `testbed-package.yml` — same pattern, three steps
- `build-image.yml` — already has `id-token: write`; login step needed if/when SBOM push lands here

### Why deferred

Blocked on Octopus service account configuration in the current instance — permissions need to be set up before the workflow changes can be tested. No design changes needed; this is purely an implementation step when access is available.

## Teardown

```bash
# Monorepo root
cd terraform
terraform destroy -var-file=local.tfvars -target=module.web_app_development

# Environment root
cd terraform/environments/dev
terraform destroy -var-file=octopus.tfvars
```
