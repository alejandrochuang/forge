# Genera un sufijo numérico aleatorio (ej. 4829)
resource "random_integer" "acr_suffix" {
  min = 1000
  max = 9999
}

resource "azurerm_container_registry" "acr" {
  # El nombre será algo como: forgeacr4829
  name                = "${var.project}acr${random_integer.acr_suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic" # Versión barata para laboratorio
  admin_enabled       = false   # Por seguridad, usaremos identidades gestionadas luego
  tags                = var.tags
}
