variable "project" {
  description = "Prefijo del proyecto"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "resource_group_name" {
  description = "Nombre del Resource Group (viene del módulo network)"
  type        = string
}

variable "tags" {
  description = "Etiquetas comunes"
  type        = map(string)
}
