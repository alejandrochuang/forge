output "resource_group_name" {
  description = "Nombre del Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Localización del Resource Group"
  value       = azurerm_resource_group.rg.location
}

output "aks_subnet_id" {
  description = "ID de la subred para AKS"
  value       = azurerm_subnet.aks_subnet.id
}
