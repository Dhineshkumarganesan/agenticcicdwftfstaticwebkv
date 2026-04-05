# Security Policy

## Reporting a Vulnerability

Please do not report security vulnerabilities through public GitHub Issues.

Use **Security → Advisories → Report a vulnerability** in this repository, or contact the maintainer via their GitHub profile.

Reports will be reviewed on a best-effort basis.

---

## Scope

This policy applies to:

- Hardcoded credentials in any committed file
- Insecure defaults in generated workflows or Terraform
- OIDC / authentication misconfigurations
- Excessive permissions in workflows or Azure RBAC
- Supply chain risks in GitHub Actions usage

---

## Security Positioning of This Repository

This repository is designed as a **secure-by-default reference implementation** of an Agentic CI/CD pattern.

It intentionally demonstrates:

- OIDC authentication (no long-lived secrets)
- Minimal GitHub workflow permissions
- SHA-pinned GitHub Actions (supply chain protection)
- Azure RBAC model (no access policies for Key Vault)
- Remote Terraform state with locking and encryption
- Separation of intent (consumer) and execution (factory) for governance enforcement

Before using in shared or enterprise environments, teams should review RBAC assignments and align configurations with their organization’s security policies.

---

## Security Defaults in This Template

| Principle | Implementation |
|---|---|
| No long-lived secrets | OIDC only |
| Minimal permissions | `contents: read` at workflow level, `id-token: write` per job |
| Supply chain protection | All GitHub Actions pinned to commit SHAs |
| No hardcoded IDs | Azure identifiers via GitHub Secrets/Variables |
| Secure state | Azure Storage encryption with blob-level locking |

---

MIT License. Not affiliated with Microsoft or GitHub.
