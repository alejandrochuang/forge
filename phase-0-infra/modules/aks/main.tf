resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.project}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project}-aks"
  kubernetes_version  = var.kubernetes_version

  # Seguridad: Solo tu IP puede lanzar comandos kubectl
  api_server_access_profile {
    authorized_ip_ranges = [var.admin_ip_cidr]
  }
  # Ajustes de seguridad y Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    vnet_subnet_id = var.aks_subnet_id
  }
  # NUEVO BLOQUE: Evitar conflicto de IPs
  network_profile {
    network_plugin = "kubenet"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
    pod_cidr       = "10.244.0.0/16"
  }
  # Azure le asignará una identidad gestionada (un "usuario" invisible) al clúster
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Permiso para que el clúster pueda descargar imágenes del ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
