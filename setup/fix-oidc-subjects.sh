#!/usr/bin/env bash
# fix-oidc-subjects.sh
# Deletes and recreates all 5 federated identity credentials with correct GitHub owner casing.
# Usage: APP_OBJECT_ID=<app-object-id> bash setup/fix-oidc-subjects.sh

set -euo pipefail
: "${APP_OBJECT_ID:?Set APP_OBJECT_ID before running}"

OWNER="Dhineshkumarganesan"
REPO="agenticcicdwftfstaticwebkv"
ISSUER="https://token.actions.githubusercontent.com"
AUD="api://AzureADTokenExchange"
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
