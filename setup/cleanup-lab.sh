#!/usr/bin/env bash
# cleanup-lab.sh
# Complete teardown of all lab resources — Azure infra, tfstate, OIDC app registration,
# and GitHub Environments. One script, nothing left behind.
#
# Required env vars:
#   REPO                   — format: owner/repo
#   SUBSCRIPTION_ID        — Azure subscription ID
#   TFSTATE_RESOURCE_GROUP — resource group containing the tfstate storage account
#   AZURE_CLIENT_ID        — App Registration application (client) ID for OIDC
#
# Optional env vars:
#   RUN_DESTROY_WORKFLOW   — "true" to trigger destroy.yml via GitHub Actions first (default: false)
#   ENVIRONMENT            — environment to destroy via workflow (default: all)

set -euo pipefail

: "${REPO:?Set REPO=owner/repo}"
: "${SUBSCRIPTION_ID:?Set SUBSCRIPTION_ID}"
: "${TFSTATE_RESOURCE_GROUP:?Set TFSTATE_RESOURCE_GROUP}"
: "${AZURE_CLIENT_ID:?Set AZURE_CLIENT_ID to the OIDC app registration client ID}"

RUN_DESTROY_WORKFLOW="${RUN_DESTROY_WORKFLOW:-false}"
ENVIRONMENT="${ENVIRONMENT:-all}"

echo "═══════════════════════════════════════════════════════"
echo "  Agentic CI/CD Factory — Complete Lab Cleanup"
echo "  Repo:              ${REPO}"
echo "  Subscription:      ${SUBSCRIPTION_ID}"
echo "  TFState RG:        ${TFSTATE_RESOURCE_GROUP}"
echo "  OIDC App Client:   ${AZURE_CLIENT_ID}"
echo "  Destroy workflow:  ${RUN_DESTROY_WORKFLOW}"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── Step 1: trigger GitHub Actions destroy workflow ───────────────────────────
if [[ "$RUN_DESTROY_WORKFLOW" == "true" ]]; then
  echo "▶ [1/4] Triggering destroy workflow (environment: ${ENVIRONMENT})..."
  gh workflow run destroy.yml \
    -R "$REPO" \
    -f environment="${ENVIRONMENT}" \
    -f confirm="DESTROY"
  echo "  Waiting for destroy workflow to complete..."
  sleep 15
  RUN_ID=$(gh run list -R "$REPO" --workflow=destroy.yml --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$RUN_ID" -R "$REPO" --exit-status || {
    echo "⚠  Destroy workflow did not complete successfully. Continuing cleanup..."
  }
else
  echo "▶ [1/4] Skipping destroy workflow (RUN_DESTROY_WORKFLOW != true)"
fi

# ── Step 2: Delete the Terraform state resource group ────────────────────────
echo ""
echo "▶ [2/4] Deleting tfstate resource group: ${TFSTATE_RESOURCE_GROUP}"
echo "  (Removes the Terraform state storage account and all state files)"
echo ""
read -rp "  Type 'yes' to confirm deletion of ${TFSTATE_RESOURCE_GROUP}: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted — no resources deleted."
  exit 0
fi

az account set --subscription "$SUBSCRIPTION_ID"
az group delete --name "$TFSTATE_RESOURCE_GROUP" --yes --no-wait
echo "  Deletion submitted (async). Waiting for completion..."
az group wait --name "$TFSTATE_RESOURCE_GROUP" --deleted --timeout 600 || \
  echo "⚠  Wait timed out — check Azure portal to confirm deletion."
echo "  ✓ Tfstate resource group deleted."

# ── Step 3: Delete the OIDC App Registration ─────────────────────────────────
echo ""
echo "▶ [3/4] Deleting Entra App Registration (client ID: ${AZURE_CLIENT_ID})..."
APP_NAME=$(az ad app show --id "${AZURE_CLIENT_ID}" --query "displayName" -o tsv 2>/dev/null || echo "unknown")
echo "  App name: ${APP_NAME}"
az ad app delete --id "${AZURE_CLIENT_ID}"
echo "  ✓ App registration deleted."

# ── Step 4: Remove GitHub Environments ───────────────────────────────────────
echo ""
echo "▶ [4/4] Removing GitHub Environments (dev, test, prod) from ${REPO}..."
for env in dev test prod; do
  STATUS=$(gh api --method DELETE "/repos/${REPO}/environments/${env}" 2>&1 && echo "deleted" || echo "not found / already removed")
  echo "  ${env}: ${STATUS}"
done
echo "  ✓ GitHub Environments removed."

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  ✅  COMPLETE — All lab resources have been removed.  ║"
echo "║                                                       ║"
echo "║  Azure infra:       destroyed via workflow            ║"
echo "║  Terraform state:   deleted (${TFSTATE_RESOURCE_GROUP})"
echo "║  OIDC app reg:      deleted (${AZURE_CLIENT_ID})      ║"
echo "║  GitHub Envs:       dev / test / prod removed         ║"
echo "╚═══════════════════════════════════════════════════════╝"

