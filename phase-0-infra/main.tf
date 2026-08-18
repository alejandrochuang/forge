# 1. Llamamos al módulo de Red
module "network" {
  source   = "./modules/network"
  project  = var.project
  location = var.location
  tags     = var.tags
}

# 2. Llamamos al módulo del Container Registry (ACR)
module "acr" {
  source              = "./modules/acr"
  project             = var.project
  location            = var.location
  resource_group_name = module.network.resource_group_name # Conectado a la red
  tags                = var.tags
}

# 3. Llamamos al módulo de Kubernetes (AKS)
module "aks" {
  source              = "./modules/aks"
  project             = var.project
  location            = var.location
  resource_group_name = module.network.resource_group_name # Conectado a la red
  aks_subnet_id       = module.network.aks_subnet_id       # Conectado a la subred
  acr_id              = module.acr.acr_id                  # Conectado al ACR

  # Variables que vienen del archivo terraform.tfvars o variables.tf
  admin_ip_cidr      = var.admin_ip_cidr
  node_count         = var.node_count
  node_vm_size       = var.node_vm_size
  kubernetes_version = var.kubernetes_version
  tags               = var.tags
}
