output "resource_group_name" {
  description = "Resource group containing all demo resources"
  value       = azurerm_resource_group.rg.name
}

output "app_url" {
  description = "Production slot URL"
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "feature_slot_url" {
  description = "Feature slot URL (for branch-based test deployments)"
  value       = "https://${azurerm_linux_web_app_slot.feature.default_hostname}"
}

output "app_name" {
  description = "Web App name — used in Octopus deployment targets"
  value       = azurerm_linux_web_app.app.name
}
