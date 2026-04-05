# Agentic CI/CD Consumer Reference Implementation

> **Audience:** Application teams and engineers who want to deploy cloud resources without writing CI/CD pipelines.  
> **Status:** Reference consumer repository demonstrating intent-driven deployment using a contract.

---

## 🚀 What this repository is

This repository contains **no CI/CD pipeline logic**.

Instead, it declares **deployment intent** using a single file: `contract.yml`.

That intent is interpreted by the **Agentic CI/CD Factory**, which decides:

- What needs to be deployed
- Which Terraform modules to use
- Which workflows must run
- What governance and validations to apply

> 👉 You describe *what* you want to deploy.  
> 👉 The factory decides *how* it is deployed.

This repository demonstrates what a real project looks like when CI/CD is **intent-driven, not pipeline-driven**.

---

## 📜 Intent Declaration via `contract.yml`

There are no pipelines to write in this repository.

You only describe the infrastructure you want.  
The factory interprets this contract and generates the required CI/CD behavior automatically.

This is the core idea behind **Agentic CI/CD**.

---

Not affiliated with Microsoft or GitHub. No warranty. MIT License.

---

[![CI](https://github.com/dhineshkumarganesan/agentic-cicd-factory-template/actions/workflows/ci.yml/badge.svg)](https://github.com/dhineshkumarganesan/agentic-cicd-factory-template/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OIDC Auth](https://img.shields.io/badge/Auth-OIDC%20only-green)](docs/ONBOARDING.md)
[![No Secrets](https://img.shields.io/badge/Secrets-Zero%20hardcoded-green)](SECURITY.md)

 ## What it is
 
 This repository is a real-world application that consumes the Agentic Reference (or 
Starter) CI/CD Factory. It leverages:
 
 - **GitHub Actions** — CI (lint, validate, plan), CD (deploy), Destroy, orchestrated 
by the factory
 - **Terraform** — Remote state on Azure Blob Storage, OIDC authentication (no stored 
secrets)
 - **Azure** — Deploys resources like Resource Groups, Static Websites (Storage 
Account), and Key Vault (RBAC)
 - **Agentic patterns** — Safe outputs, minimal permissions, SHA-pinned actions, 
job-level OIDC
 
 This repo shows how to adopt and operate with the Agentic Factory for secure, 
production-grade deployments.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| `az` CLI | ≥ 2.55 | https://learn.microsoft.com/cli/azure/install-azure-cli |
| `gh` CLI | ≥ 2.40 | https://cli.github.com |
| `jq` | ≥ 1.6 | `brew install jq` / `apt install jq` |
| `terraform` | ≥ 1.6 | https://developer.hashicorp.com/terraform/install |

**Azure permissions required:**
- Create App Registrations (Entra)
- Create Service Principals
- `Owner` or `Contributor` + `User Access Administrator` on the target subscription

**GitHub permissions required:**
- Repo admin (to set secrets, variables, branch protection, environments)
- GitHub Free plan is sufficient
 - GitHub Copilot CLI — Requires an active Copilot license (Get Copilot)
---

## How to use Agentic Reference (or Starter) CI/CD Factory — Public Template

> See [docs/ONBOARDING.md](docs/ONBOARDING.md) for the full walkthrough with explanations.

## Repo structure

```
.
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                         # PR validation: lint, scan, plan (all 3 envs)
│   │   ├── cd.yml                         # Deploy: dev → test → prod
│   │   ├── destroy.yml                    # Destroy (manual trigger, gated)
│   │   ├── _reusable-tf-ci.yml            # Reusable: TF fmt/validate/plan
│   │   ├── _reusable-deploy-azure-tf.yml  # Reusable: TF apply with OIDC
│   │   └── _reusable-destroy-azure-tf.yml # Reusable: TF destroy with OIDC
│   ├── agents/
│   │   ├── terraform-module-expert.agent.md    # Scaffold any Azure resource
│   │   ├── terraform-coordinator.agent.md      # Routes between agents
│   │   ├── terraform-security.agent.md         # Security review
│   │   ├── azure-architecture-reviewer.agent.md# WAF/CAF compliance
│   │   └── terraform-provider-upgrade.agent.md # Safe provider upgrades
│   ├── skills/
│   │   ├── azure-verified-modules/        # AVM reference patterns
│   │   ├── azure-architecture-review/     # Architecture review patterns
│   │   ├── github-actions-terraform/      # CI/CD pipeline patterns
│   │   ├── terraform-provider-upgrade/    # Provider upgrade patterns
│   │   ├── terraform-security-scan/       # Security scan patterns
│   │   └── drawio-mcp-diagramming/        # Architecture diagram generation
│   └── copilot-instructions.md            # Azure architecture guidance for Copilot
├── infra/
│   └── envs/
│       ├── dev/                           # Development environment
│       │   ├── main.tf                    # Resources scaffolded via @terraform-module-expert
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── test/                          # Test environment
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── prod/                          # Production environment
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── cicd/
│   └── contract.yml                       # Pipeline guardrails declaration
├── scripts/
│   └── contract_lint.py                   # Validates contract.yml in CI
├── setup/                                 # ← Run these to onboard a new repo
│   ├── onboard-agenticcicd-newrepo.sh     # ← Start here (runs all below)
│   ├── azure-oidc-bootstrap-one-sp.sh     # Create Entra App + OIDC creds
│   ├── terraform-backend-bootstrap.sh     # Create TF state storage
│   ├── github-secrets-bootstrap.sh        # Set GitHub secrets + variables
│   ├── create-github-environments.sh      # Create dev/test/prod environments
│   ├── branch-protection-main.sh          # Apply main branch protection
│   ├── patch-tfstate-keys.sh              # Rename TF state key paths
│   └── cleanup-lab.sh                     # Destroy all resources
├── docs/
│   ├── ONBOARDING.md                      # Detailed onboarding walkthrough
│   └── TROUBLESHOOTING.md                 # Common issues and fixes
├── .gitignore
├── LICENSE
└── SECURITY.md
```

---

## Security defaults

| Principle | Implementation |
|-----------|---------------|
| No long-lived secrets | OIDC only (`id-token: write` per-job) |
| Minimal permissions | `contents: read` default; `write` never at workflow level |
| SHA-pinned actions | All `uses:` references pinned to commit SHAs |
| No hardcoded IDs | All Azure IDs via GitHub Secrets/Variables |
| State encryption | Azure Storage Server-Side Encryption (default) |
| KV RBAC enabled | No vault access policy model — RBAC only |

---

## License

MIT — see [LICENSE](LICENSE).  
Not affiliated with Microsoft or GitHub.
