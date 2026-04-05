# Intent-Driven Agentic CI/CD: Building a CI/CD Factory that Understands What You Want to Deploy

> **Series:** Engineering Platforms for the Agentic AI Era  
> The full loop: declare intent → agent scaffolds → CI validates → CD deploys

---

## The Two-Repo Architecture

Before diving in, it is important to understand the two-repo model that powers this demo:

```
┌─────────────────────────────────────────────────────────────┐
│  FACTORY TEMPLATE (the platform)                            │
│  github.com/agentic-platform-labs/agentic-cicd-factory-template │
│                                                             │
│  • All reusable CI/CD workflow patterns                     │
│  • Copilot agents (@terraform-module-expert, etc.)          │
│  • Guardrail linter (contract_lint.py)                      │
│  • Setup scripts (OIDC bootstrap, backend, environments)    │
│  • Skills library                                           │
│                                                             │
│  ← Any team "uses this template" to create their repo       │
└─────────────────────────────────────────────────────────────┘
                          ↓  "Use this template"
┌─────────────────────────────────────────────────────────────┐
│  CONSUMER REPO (the intent processor)                       │
│  github.com/Dhineshkumarganesan/agenticcicdwftfstaticwebkv  │
│                                                             │
│  • cicd/contract.yml  ← developer declares WHAT to deploy  │
│  • infra/envs/        ← agent writes the HOW (Terraform)   │
│  • Own Azure credentials (OIDC, tfstate backend)            │
│  • Own GitHub Environments (dev / test / prod)              │
│                                                             │
│  ← This is where Blog 3 happens                            │
└─────────────────────────────────────────────────────────────┘
```

The factory template is the **engine** — it provides all the patterns, agents, and guardrails. The consumer repo is the **driver** — it declares business intent and the factory's CI/CD machinery does the rest. Each consumer repo has its own isolated Azure identity (OIDC), its own tfstate backend, and its own deployment environments.

---

## Overview

We built the factory template and onboarded the consumer repo from it. We close the loop — a developer types a **natural language prompt** in the consumer repo, a Copilot agent reads the `contract.yml` intent file, scaffolds real Terraform, and the CI/CD pipeline deploys a Storage Account static website to **dev**, **test**, and **prod** on Azure — all without touching a single workflow file.

### What we built

| Layer | Component | Repo |
|---|---|---|
| Intent | `cicd/contract.yml` — declares what to deploy | Consumer |
| Agent | `@terraform-module-expert` — reads contract, writes Terraform | Factory (agent definition) |
| CI | GitHub Actions — fmt → validate → plan (all 3 envs) | Consumer (runs factory patterns) |
| CD | GitHub Actions — deploy dev → test → prod (progressive) | Consumer (runs factory patterns) |
| Destroy | GitHub Actions — manual destroy with `DESTROY` confirmation gate | Consumer (runs factory patterns) |
| Cloud | Azure Storage Account with static website hosting, LRS, West Europe | Consumer's Azure subscription |

---

## Step 1 — Declare Intent in `contract.yml`

Before writing a single line of Terraform, we declare **what** we want in `cicd/contract.yml`. This is the single source of truth that both the agent and the CI guardrail linter read.

```yaml
resources:
  - type: storage_account
    purpose: static_website_hosting
    replication: LRS
    region: westeurope
    environments: [dev, test, prod]
```

We also ensured the `allowed_registries` included the `azure` GitHub Actions org so the OIDC login action passes contract lint:

```yaml
guardrails:
  allowed_registries:
    actions:
      - github.com/actions
      - github.com/azure          # azure/login for OIDC
      - github.com/bridgecrewio
      - github.com/github
      - github.com/hashicorp
```

> **📸 Screenshot:** `cicd/contract.yml` open in VS Code showing the `resources:` block

---

## Step 2 — Prompt the Agent

With intent declared, we typed a single prompt into GitHub Copilot Chat in VS Code:

```
@terraform-module-expert
Read cicd/contract.yml. Scaffold the declared resources into:
  infra/envs/dev/main.tf
  infra/envs/test/main.tf
  infra/envs/prod/main.tf

Use azurerm_resource_group + azurerm_storage_account with:
- Standard LRS, StorageV2, westeurope
- Static website enabled (index.html / 404.html)
- HTTPS only, TLS 1.2 minimum
- Tags via locals block

Also update each outputs.tf with: resource_group_name,
storage_account_name, static_website_url.
```

The agent read `contract.yml`, checked existing skeleton files, and scaffolded all three environments in one shot — resource group, storage account, outputs, and a tags `locals` block.

> **📸 Screenshot:** Copilot Chat panel showing the `@terraform-module-expert` prompt and agent response

> **📸 Screenshot:** VS Code file explorer showing `infra/envs/dev/main.tf` with scaffolded resources

---

## Step 3 — CI Pipeline Validates All Three Environments

Pushing the scaffolded Terraform to `main` automatically triggered the CI pipeline:

```
✅ Contract Lint (guardrails)
✅ IaC Security Scan (Checkov)
✅ Generate SBOM
✅ Terraform CI — dev  (fmt → validate → plan)
✅ Terraform CI — test (fmt → validate → plan)
✅ Terraform CI — prod (fmt → validate → plan)
```

Each Terraform CI job:
1. Authenticates to Azure via **OIDC** (no stored credentials)
2. Runs `terraform init` pointing at the shared backend state
3. Runs `terraform validate` — proves the config is syntactically correct
4. Runs `terraform plan -out=tfplan.binary` — confirms what Azure *would* create
5. Uploads the plan artifact for audit

> **📸 Screenshot:** GitHub Actions CI run — all 6 jobs green

> **📸 Screenshot:** Terraform plan output for dev showing `+azurerm_resource_group.main` and `+azurerm_storage_account.web`

### Contract Lint — Runtime Guardrails

The `Contract Lint` job runs `scripts/contract_lint.py` which validates every workflow file against `cicd/contract.yml` guardrails:

- All GitHub Actions SHA-pinned (supply chain protection)
- No `contents:write` permissions (least privilege)
- `security-events:write` scoped to job level only
- All action orgs on the allowed-registries list

> **📸 Screenshot:** Contract Lint job output — all guardrail checks passed ✓

---

## Step 4 — CD Pipeline Deploys dev → test → prod

A second prompt triggered a real infrastructure change that kicked off CD:

```
@terraform-module-expert
CI has passed. Please standardise tag keys to underscore 
convention across all envs (managed_by, source_repo) 
and push to main to trigger CD.
```

The agent updated all 3 `main.tf` files and pushed — CD triggered automatically:

```
✅ Deploy → dev   (terraform apply)
✅ Deploy → test  (terraform apply, after dev succeeded)
✅ Deploy → prod  (terraform apply, after test succeeded)
```

Each CD job:
1. Authenticates to Azure using the **environment-scoped OIDC credential**
   - dev job uses `environment:dev` federated credential
   - test job uses `environment:test` federated credential  
   - prod job uses `environment:prod` federated credential
2. Runs `terraform init` to connect to the remote state backend
3. Runs `terraform apply -auto-approve`

> **📸 Screenshot:** GitHub Actions CD run — all 3 deploy jobs green (dev → test → prod in sequence)

> **📸 Screenshot:** Azure Portal — Resource Groups `rg-agfactory-dev`, `rg-agfactory-test`, `rg-agfactory-prod` created

> **📸 Screenshot:** Azure Portal — Storage Account `stagfactorydev` with Static website enabled

---

## Step 5 — Destroy (Manual Gate)

The Destroy workflow is `workflow_dispatch`-only — it cannot be triggered by a code push or an agent. This is intentional:

> **Automated deploys. Manual destroys.**

To destroy all three environments:

1. Go to **Actions → Destroy → Run workflow**
2. Select **environment:** `all`
3. Type **confirm:** `DESTROY`
4. Click Run workflow

```
✅ Safety Check  (verifies "DESTROY" was typed)
✅ Destroy → dev
✅ Destroy → test
✅ Destroy → prod
```

> **📸 Screenshot:** GitHub Actions Destroy workflow dispatch inputs (environment=all, confirm=DESTROY)

> **📸 Screenshot:** Destroy run — all 4 jobs green

> **📸 Screenshot:** Azure Portal — Resource Groups deleted / no longer present

---

## OIDC Setup — The Critical Prerequisite

Before CI/CD can authenticate to Azure, you need to configure **Workload Identity Federation**. This replaces stored secrets with short-lived OIDC tokens — a security best practice.

### App Registration & Federated Credentials

```bash
# Create the app registration
az ad app create --display-name "agenticcicdwftfstaticwebkv-oidc"

# Assign Contributor role to the service principal
az role assignment create \
  --assignee <APP_CLIENT_ID> \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

Five federated credentials are required — one per GitHub Actions OIDC context:

| Credential Name | Subject | When Used |
|---|---|---|
| `...-main` | `repo:Owner/Repo:ref:refs/heads/main` | CI (branch push) |
| `...-pr` | `repo:Owner/Repo:pull_request` | CI (pull request) |
| `...-dev` | `repo:Owner/Repo:environment:dev` | CD deploy-dev |
| `...-test` | `repo:Owner/Repo:environment:test` | CD deploy-test |
| `...-prod` | `repo:Owner/Repo:environment:prod` | CD deploy-prod |

### ⚠️ Lesson Learned — Case Sensitivity

GitHub sends the **exact-case** username in OIDC subject claims. Azure AD matching is **case-sensitive**.

```
# Wrong (lowercase d — will fail):
repo:dhineshkumarganesan/agenticcicdwftfstaticwebkv:ref:refs/heads/main

# Correct (capital D — matches GitHub):
repo:Dhineshkumarganesan/agenticcicdwftfstaticwebkv:ref:refs/heads/main
```

`az ad app federated-credential update` **silently fails** on subject changes. Always use the provided repair script:

```bash
# If OIDC breaks — one command fix:
AZURE_CLIENT_ID=<your-app-client-id> bash setup/fix-oidc-subjects.sh
# Wait 2 minutes for Azure AD propagation, then re-run CI
```

The script auto-resolves the object ID from the client ID — no manual ID hunting required.

### ⚠️ Lesson Learned — Wrong App Object ID

When patching federated credentials, always derive the object ID from the **same `AZURE_CLIENT_ID`** used in the GitHub secret. Using an unrelated object ID silently patches the wrong app.

> **📸 Screenshot:** Azure Portal — App Registration "agenticcicdwftfstaticwebkv-oidc" → Federated credentials tab showing all 5 credentials

---

## Architecture — How It All Fits Together

```
cicd/contract.yml          ← single source of truth
        │
        ▼
@terraform-module-expert   ← Copilot agent reads contract, writes Terraform
        │
        ▼
git push to main
        │
        ├──► CI Pipeline
        │     ├─ Contract Lint (guardrails enforcement)
        │     ├─ IaC Security Scan (Checkov)
        │     ├─ SBOM generation
        │     └─ Terraform fmt / validate / plan × 3 envs
        │
        └──► CD Pipeline  (triggered by infra/** changes)
              ├─ Deploy → dev   (OIDC: environment:dev)
              ├─ Deploy → test  (OIDC: environment:test, after dev)
              └─ Deploy → prod  (OIDC: environment:prod, after test)
```

> **📸 Screenshot:** GitHub Actions tab showing CI and CD runs side by side

---

## GitHub Secrets & Variables Required

| Name | Type | Value |
|---|---|---|
| `AZURE_CLIENT_ID` | Secret | App Registration Application (client) ID |
| `AZURE_TENANT_ID` | Secret | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Secret | Azure Subscription ID |
| `TFSTATE_RESOURCE_GROUP` | Variable | Resource group holding TF state storage account |
| `TFSTATE_STORAGE_ACCOUNT` | Variable | Storage account name for Terraform state |
| `TFSTATE_CONTAINER` | Variable | Blob container name for Terraform state |

---

## Key Takeaways

1. **Declare intent, not implementation** — `contract.yml` is the human-readable contract. The agent handles the Terraform boilerplate.

2. **Guardrails are enforced in CI** — `contract_lint.py` catches permission drift, unallowed registries, and missing SHA pins before anything reaches Azure.

3. **OIDC is the right auth pattern** — no stored Azure credentials anywhere. Each environment has its own scoped federated credential.

4. **Automated deploys, manual destroys** — the destroy workflow requires a human to type `DESTROY`. No agent can accidentally tear down production.

5. **The agent is not magic** — it reads your contract and writes standard Terraform. You review, you own it, CI validates it before it touches cloud.

---

## Repository Links

| Role | Repo | Description |
|---|---|---|
| **Factory template** | [agentic-platform-labs/agentic-cicd-factory-template](https://github.com/agentic-platform-labs/agentic-cicd-factory-template) | The platform — reusable CI/CD patterns, agents, guardrails, setup scripts |
| **Consumer repo** | [Dhineshkumarganesan/agenticcicdwftfstaticwebkv](https://github.com/Dhineshkumarganesan/agenticcicdwftfstaticwebkv) | demo — Storage Account intent declared and deployed from this repo |


---

