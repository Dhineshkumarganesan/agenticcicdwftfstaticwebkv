#!/usr/bin/env bash
# fix-oidc-subjects.sh
# Deletes and recreates all 5 federated identity credentials with correct GitHub owner casing.
#
# Usage (preferred — derives object ID automatically from client ID):
#   AZURE_CLIENT_ID=<appId> bash setup/fix-oidc-subjects.sh
#
# Usage (manual override):
#   APP_OBJECT_ID=<objectId> bash setup/fix-oidc-subjects.sh

set -euo pipefail

OWNER="Dhineshkumarganesan"
REPO="agenticcicdwftfstaticwebkv"
ISSUER="https://token.actions.githubusercontent.com"
AUD="api://AzureADTokenExchange"

# Derive APP_OBJECT_ID from AZURE_CLIENT_ID (appId) if not explicitly provided.
# This ensures credentials always land on the same app that GitHub Actions authenticates against.
if [ -z "${APP_OBJECT_ID:-}" ]; then
  : "${AZURE_CLIENT_ID:?Provide either AZURE_CLIENT_ID (appId) or APP_OBJECT_ID (objectId)}"
  echo "Resolving object ID from AZURE_CLIENT_ID=${AZURE_CLIENT_ID}..."
  APP_OBJECT_ID=$(az ad app show --id "${AZURE_CLIENT_ID}" --query "id" -o tsv)
  echo "Resolved APP_OBJECT_ID=${APP_OBJECT_ID}"
fi

BASE="https://graph.microsoft.com/v1.0/applications/${APP_OBJECT_ID}/federatedIdentityCredentials"

recreate_fic() {
  local name="$1" subject="$2"
  echo "Processing: $name"

  # Get credential ID by name
  CRED_ID=$(az rest --method GET --uri "$BASE" \
    --query "value[?name=='${name}'].id" -o tsv 2>/dev/null || true)

  if [ -n "$CRED_ID" ]; then
    echo "  Deleting old credential (id: $CRED_ID)..."
    az rest --method DELETE --uri "${BASE}/${CRED_ID}"
  fi

  echo "  Creating new credential with subject: $subject"
  az rest --method POST --uri "$BASE" \
    --headers "Content-Type=application/json" \
    --body "{\"name\":\"${name}\",\"issuer\":\"${ISSUER}\",\"subject\":\"${subject}\",\"audiences\":[\"${AUD}\"]}"
  echo "  Done: $name"
}

recreate_fic "github-${REPO}-main" "repo:${OWNER}/${REPO}:ref:refs/heads/main"
recreate_fic "github-${REPO}-pr"   "repo:${OWNER}/${REPO}:pull_request"
recreate_fic "github-${REPO}-dev"  "repo:${OWNER}/${REPO}:environment:dev"
recreate_fic "github-${REPO}-test" "repo:${OWNER}/${REPO}:environment:test"
recreate_fic "github-${REPO}-prod" "repo:${OWNER}/${REPO}:environment:prod"

echo ""
echo "Verifying final state:"
az rest --method GET --uri "$BASE" --query "value[].{name:name,subject:subject}" -o table
