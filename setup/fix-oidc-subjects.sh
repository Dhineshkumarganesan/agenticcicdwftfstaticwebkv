#!/usr/bin/env bash
# fix-oidc-subjects.sh
# Updates all 5 Azure federated identity credentials to use correct GitHub owner casing.
# Usage: APP_OBJECT_ID=<your-app-object-id> bash setup/fix-oidc-subjects.sh

set -euo pipefail

: "${APP_OBJECT_ID:?Set APP_OBJECT_ID before running this script}"

OWNER="Dhineshkumarganesan"
REPO="agenticcicdwftfstaticwebkv"
ISSUER="https://token.actions.githubusercontent.com"
AUD="api://AzureADTokenExchange"

update_fic() {
  local cred_name="$1"
  local subject="$2"
  echo "Updating: $cred_name"
  printf '{"issuer":"%s","subject":"%s","audiences":["%s"]}' \
    "$ISSUER" "$subject" "$AUD" > /tmp/fic_update.json
  az ad app federated-credential update \
    --id "$APP_OBJECT_ID" \
    --federated-credential-id "$cred_name" \
    --parameters @/tmp/fic_update.json
  echo "Done: $cred_name"
}

update_fic "github-${REPO}-main" "repo:${OWNER}/${REPO}:ref:refs/heads/main"
update_fic "github-${REPO}-pr"   "repo:${OWNER}/${REPO}:pull_request"
update_fic "github-${REPO}-dev"  "repo:${OWNER}/${REPO}:environment:dev"
update_fic "github-${REPO}-test" "repo:${OWNER}/${REPO}:environment:test"
update_fic "github-${REPO}-prod" "repo:${OWNER}/${REPO}:environment:prod"

echo ""
echo "All 5 federated credentials updated successfully."
