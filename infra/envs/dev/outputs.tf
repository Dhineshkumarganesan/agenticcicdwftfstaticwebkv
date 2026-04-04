# Outputs — added alongside resources scaffolded via @terraform-module-expert

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.web.name
}

output "static_website_url" {
  description = "Static website primary endpoint URL"
  value       = azurerm_storage_account.web.primary_web_endpoint
}
