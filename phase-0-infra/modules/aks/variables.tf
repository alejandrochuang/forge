variable "project" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }

variable "aks_subnet_id" {
  description = "ID de la subred donde vivirán los nodos"
  type        = string
}

variable "acr_id" {
  description = "ID del Container Registry para darle permisos de lectura"
  type        = string
}

variable "admin_ip_cidr" {
  description = "IP autorizada para acceder al API de Kubernetes"
  type        = string
}

variable "node_count" { type = number }
variable "node_vm_size" { type = string }
variable "kubernetes_version" { type = string }
