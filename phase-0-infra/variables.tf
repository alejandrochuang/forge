variable "subscription_id" {
  description = "ID de la suscripcion de Azure"
  type        = string
}

variable "location" {
  description = "Region de Azure"
  type        = string
  default     = "eastus"
}

variable "project" {
  description = "Prefijo de nombres de recursos"
  type        = string
  default     = "forge"
}

variable "admin_ip_cidr" {
  description = "CIDR autorizado para el API server de AKS (tu IP/32)"
  type        = string
}

variable "node_count" {
  description = "Numero de nodos del pool de AKS"
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "Tamano de VM de los nodos (barato para lab)"
  type        = string
  default     = "Standard_B2s"
}

variable "kubernetes_version" {
  description = "Version de Kubernetes en AKS"
  type        = string
  default     = "1.30"
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default = {
    project     = "forge"
    environment = "lab"
    managed_by  = "terraform"
  }
}
