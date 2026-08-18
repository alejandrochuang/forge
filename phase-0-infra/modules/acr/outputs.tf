output "acr_id" {
  description = "ID del Container Registry"
  value       = azurerm_container_registry.acr.id
}

output "acr_login_server" {
  description = "URL del servidor (ej. forgeacr1234.azurecr.io)"
  value       = azurerm_container_registry.acr.login_server
}
