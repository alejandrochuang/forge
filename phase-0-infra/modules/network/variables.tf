variable "project" {
  description = "Prefijo del proyecto"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "tags" {
  description = "Etiquetas de los recursos"
  type        = map(string)
}

variable "vnet_address_space" {
  description = "Rango de IPs para la Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "Rango de IPs para la subred del clúster AKS"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}
