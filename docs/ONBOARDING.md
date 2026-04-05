# Consumer Onboarding Guide (Using the Agentic CI/CD Factory)

This guide shows how an application repository onboards to the **Agentic CI/CD Factory**.

> You do **not** write pipelines here.  
> You only declare deployment intent in `contract.yml` and run the onboarding script.  

---

## Step 1 — Create your app repository from the Factory template

Use the **Agentic CI/CD Factory Template** as your starting point:

```bash
gh repo create my-app \
  --template dhineshkumarganesan/agentic-cicd-factory-template \
  --public
gh repo clone my-app
cd my-app
```
---

2. **Edit `cicd/contract.yml`**
   
Declare your deployment intent (resources, environments, regions).
This is the only place you declare intent — the Factory will interpret it into CI/CD workflows automatically.

   Example:
   
   resource: static-website
   environment: dev-test-prod
   region: westeurope
   
   This is the only place you declare intent. The Factory interprets this into CI/CD workflows automatically.

4. **Set environment variables**  
   Configure Azure subscription, tenant, TF state, GitHub owner/repo, etc.

  export SUBSCRIPTION_ID=""
  export TENANT_ID=""
  export LOCATION="westeurope"
  
  export GITHUB_OWNER=""
  export GITHUB_REPO="my-app"
  
  export TFSTATE_RESOURCE_GROUP="rg-tfstate-my-app"
  export TFSTATE_STORAGE_ACCOUNT="sttfstatemyapp"   # must be globally unique
  export TFSTATE_CONTAINER="tfstate"
  
  # Optional: override GitHub users who approve prod deployments
  export PROD_REVIEWERS_USERS="alice,bob"

6. **Run the onboarding script**  
   Executes OIDC setup, TF backend, GitHub secrets, environments, and branch protection.

   bash setup/onboard-agenticcicd-newrepo.sh

8. **Trigger CI**  
   Push any change or run manually: `gh workflow run ci.yml`.
    gh workflow run ci.yml
    gh run watch

   CI includes: IaC security scan, Terraform fmt/validate/plan (all environments).

10. **Trigger CD (deploy)**

   Deploy environments in sequence (dev → test → prod):
   
   Deploy dev → test → prod: `gh workflow run cd.yml -f environment=all`.
     gh workflow run cd.yml -f environment=all
     gh run watch

  Prod requires manual approval from configured reviewers.


12. **Verify and Cleanup**  

  Verify deployment:

    gh run view --log | grep -E "website_endpoint|key_vault"

    az storage account show \
    -n "<your-storage-account-name>" \
    -g "<your-resource-group-name>" \
    --query "primaryEndpoints.web" -o tsv

   Cleanup resources (optional):

    export RUN_DESTROY_WORKFLOW=true
    bash setup/cleanup-lab.sh

  Optionally remove the Entra App Registration:
  
    APP_ID=$(az ad app list --display-name "${GITHUB_REPO}-oidc" --query "[0].appId" -o tsv)
    az ad app delete --id "$APP_ID"

##  Security Notes

OIDC only — no long-lived secrets stored in GitHub
Workflow contents: read; id-token: write per deploy job only
GitHub Actions pinned to full commit SHAs
Terraform state in Azure Storage with blob-level locking
KV RBAC enabled — no vault access policy

⚠️ This is a reference template. Review all RBAC assignments and replace placeholders before production use.
