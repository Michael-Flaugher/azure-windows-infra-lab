output "resource_group" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "workspace_id" {
  description = "Log Analytics Workspace ID -- save for Part 3"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "workspace_key" {
  description = "Log Analytics primary key -- save for Part 3"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}
