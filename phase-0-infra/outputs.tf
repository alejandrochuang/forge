output "resource_group" {
  description = "Nombre del Resource Group principal"
  value       = module.network.resource_group_name
}

output "acr_login_server" {
  description = "Servidor de nuestro Container Registry"
  value       = module.acr.acr_login_server
}

output "aks_cluster_name" {
  description = "Nombre del clúster de Kubernetes"
  value       = module.aks.aks_name
}

output "kube_config_command" {
  description = "Comando rápido para configurar kubectl en tu terminal"
  value       = "az aks get-credentials --resource-group ${module.network.resource_group_name} --name ${module.aks.aks_name} --overwrite-existing"
}
