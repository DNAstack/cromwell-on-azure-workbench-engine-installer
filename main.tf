terraform {
  required_version = ">=1.3.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.110.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.25.0"
    }
  }
}

data "azurerm_resource_group" "group" {
  name = var.resourceGroupName
}

data "azurerm_virtual_network" "vnet" {
  resource_group_name = var.resourceGroupName
  name                = var.virtualNetworkName
}

resource "random_string" "namespace_suffix" {
  length  = 8
  special = false
}

resource "kubernetes_service_v1" "ingress" {
  metadata {
    namespace     = var.kubernetesNamespace
    generate_name = "ingress"
    annotations   = {
      "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
    }
  }
  spec {
    type = "LoadBalancer"

    selector = var.cromwellPodSelector

    port {
      name        = "cromwell-http"
      port        = 8000
      protocol    = "TCP"
      target_port = 8000
    }
  }
}

module "ingress" {
  source = "./modules/container_app_ingress"

  subscriptionId                         = var.subscriptionId
  resourceGroupName                      = var.resourceGroupName
  logAnalyticsWorkspaceName              = var.logAnalyticsWorkspaceName
  virtualNetworkName                     = var.virtualNetworkName
  cromwellIpAddress                      = kubernetes_service_v1.ingress.status.0.load_balancer.0.ingress.0.ip
  storageAccountName                     = var.storageAccountName
  cromwellExecutionsStorageContainerName = var.cromwellExecutionsStorageContainerName
  additional_buckets                     = var.additional_buckets
  required_tags                          = var.required_tags
}
