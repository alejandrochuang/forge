output "aks_name" {
  description = "Nombre del clúster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kube_config_raw" {
  description = "Credenciales en crudo para conectar kubectl al clúster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true # Lo marcamos sensible para que no se imprima por pantalla accidentalmente
}
