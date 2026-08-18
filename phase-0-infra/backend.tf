terraform {
  backend "azurerm" {
    resource_group_name  = "forge-tfstate-rg"
    storage_account_name = "forgetfstate290065001"
    container_name       = "tfstate"
    key                  = "forge-infra.tfstate"
  }
}
