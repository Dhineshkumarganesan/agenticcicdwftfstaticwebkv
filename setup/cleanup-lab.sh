#!/usr/bin/env bash
# cleanup-lab.sh
# Destroys Azure lab resources — infra (via destroy workflow) and Terraform state.
#
# Steps 3 & 4 (OIDC App Registration + GitHub Environments) are intentionally
# excluded — they are repo-level, cost nothing, and are reusable across future labs.
#
# Required env vars:
#   REPO                   — format: owner/repo
#   SUBSCRIPTION_ID        — Azure subscription ID
#   TFSTATE_RESOURCE_GROUP — resource group containing the tfstate storage account
#
# Optional env vars:
#   RUN_DESTROY_WORKFLOW   — "true" to trigger destroy.yml via GitHub Actions first (default: false)
#   ENVIRONMENT            — environment to destroy via workflow (default: all)

set -euo pipefail

: "${REPO:?Set REPO=owner/repo}"
: "${SUBSCRIPTION_ID:?Set SUBSCRIPTION_ID}"
: "${TFSTATE_RESOURCE_GROUP:?Set TFSTATE_RESOURCE_GROUP}"

RUN_DESTROY_WORKFLOW="${RUN_DESTROY_WORKFLOW:-false}"
ENVIRONMENT="${ENVIRONMENT:-all}"

echo "═══════════════════════════════════════════════════════"
echo "  Agentic CI/CD Factory — Lab Cleanup"
echo "  Repo:              ${REPO}"
echo "  Subscription:      ${SUBSCRIPTION_ID}"
echo "  TFState RG:        ${TFSTATE_RESOURCE_GROUP}"
echo "  Destroy workflow:  ${RUN_DESTROY_WORKFLOW}"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── Step 1: trigger GitHub Actions destroy workflow ───────────────────────────
if [[ "$RUN_DESTROY_WORKFLOW" == "true" ]]; then
  echo "▶ [1/2] Triggering destroy workflow (environment: ${ENVIRONMENT})..."
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
  echo "▶ [1/2] Skipping destroy workflow (RUN_DESTROY_WORKFLOW != true)"
fi

# ── Step 2: Delete the Terraform state resource group ────────────────────────
echo ""
echo "▶ [2/2] Deleting tfstate resource group: ${TFSTATE_RESOURCE_GROUP}"
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

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  ✅  DONE — Azure lab resources removed.              ║"
echo "║                                                       ║"
echo "║  Kept (reusable, zero cost):                          ║"
echo "║    • OIDC App Registration  — reuse for next lab      ║"
echo "║    • GitHub Environments    — reuse for next lab      ║"
echo "╚═══════════════════════════════════════════════════════╝"

