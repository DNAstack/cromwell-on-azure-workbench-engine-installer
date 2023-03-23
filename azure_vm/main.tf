terraform {
  required_version = ">=1.3.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.47.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscriptionId
}

data "azurerm_virtual_machine" "cromwell" {
  resource_group_name = var.resourceGroupName
  name                = var.virtualMachineName
}

module "ingress" {
  source = "../modules/container_app_ingress"

  subscriptionId            = var.subscriptionId
  resourceGroupName         = var.resourceGroupName
  logAnalyticsWorkspaceName = var.logAnalyticsWorkspaceName
  virtualNetworkName        = var.virtualNetworkName
  cromwellIpAddress         = data.azurerm_virtual_machine.cromwell.private_ip_address
}