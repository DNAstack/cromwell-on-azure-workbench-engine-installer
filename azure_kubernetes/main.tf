terraform {
  required_version = ">=1.3.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.47.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.18.1"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscriptionId
}

data "azurerm_resource_group" "group" {
  name = var.resourceGroupName
}

data "azurerm_kubernetes_cluster" "cluster" {
  resource_group_name = var.resourceGroupName
  name                = var.kubernetesClusterName
}

data "azurerm_virtual_network" "vnet" {
  resource_group_name = var.resourceGroupName
  name                = var.virtualNetworkName
}

resource "azurerm_role_assignment" "cluster_vnet_role" {
  count = length(data.azurerm_kubernetes_cluster.cluster.kubelet_identity)

  principal_id         = data.azurerm_kubernetes_cluster.cluster.kubelet_identity[count.index].object_id
  scope                = data.azurerm_resource_group.group.id
  role_definition_name = "Network Contributor"

  skip_service_principal_aad_check = true
}

provider "kubernetes" {
  host = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host

  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
}

resource "random_string" "namespace_suffix" {
  length  = 8
  special = false
}

resource "kubernetes_service" "ingress" {
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

  depends_on = [azurerm_role_assignment.cluster_vnet_role]
}

module "ingress" {
  source = "../modules/container_app_ingress"

  subscriptionId                         = var.subscriptionId
  resourceGroupName                      = var.resourceGroupName
  logAnalyticsWorkspaceName              = var.logAnalyticsWorkspaceName
  virtualNetworkName                     = var.virtualNetworkName
  cromwellIpAddress                      = kubernetes_service.ingress.status.0.load_balancer.0.ingress.0.ip
  storageAccountName                     = var.storageAccountName
  cromwellExecutionsStorageContainerName = var.cromwellExecutionsStorageContainerName
}