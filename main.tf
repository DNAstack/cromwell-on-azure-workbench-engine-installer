terraform {
  required_version = ">=1.3.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.47.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "=1.4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "=2.36.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscriptionId
}

provider "azapi" {
}

data azurerm_client_config "current" {}

data "azurerm_resource_group" "default" {
  name = var.resourceGroupName
}

data "azurerm_log_analytics_workspace" "cromwell" {
  name                = var.logAnalyticsWorkspaceName
  resource_group_name = var.resourceGroupName
}

data "azurerm_virtual_network" "cromwell" {
  resource_group_name = data.azurerm_resource_group.default.name
  name                = var.virtualNetworkName
}

resource "azurerm_subnet" "ingress" {
  resource_group_name  = data.azurerm_resource_group.default.name
  virtual_network_name = data.azurerm_virtual_network.cromwell.name
  name                 = "ingress-subnet"
  address_prefixes     = [var.subnetIpMask]
}

data "azurerm_virtual_machine" "cromwell" {
  resource_group_name = data.azurerm_resource_group.default.name
  name                = var.virtualMachineName
}

resource "random_string" "ingress" {
  length  = 8
  upper   = false
  lower   = true
  numeric = true
  special = false

  keepers = {
    prefix : var.prefix
  }
}

locals {
  dns_name_label = "${var.prefix}-ingress-${random_string.ingress.result}"
  domain         = "${local.dns_name_label}.${data.azurerm_resource_group.default.location}.azurecontainer.io"
}

resource "random_string" "storage_suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false

  keepers = {
    prefix : var.prefix
  }
}

resource "azurerm_container_app_environment" "env" {
  name                       = "${var.prefix}-ingress-app-env-${random_string.ingress.result}"
  location                   = data.azurerm_resource_group.default.location
  resource_group_name        = data.azurerm_resource_group.default.name
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.cromwell.id
  infrastructure_subnet_id   = azurerm_subnet.ingress.id
}

resource "azuread_application" "workbench_client" {
  display_name     = "workbench-client-${random_string.ingress.result}"
  identifier_uris  = ["api://workbench-client"]
  owners           = []
  sign_in_audience = "AzureADMyOrg"

  api {
    mapped_claims_enabled          = false
    requested_access_token_version = 2

    known_client_applications = []
  }
}

resource "azuread_application_password" "secret" {
  application_object_id = azuread_application.workbench_client.object_id
}

resource "azapi_resource" "container_app" {
  type      = "Microsoft.App/containerApps@2022-03-01"
  parent_id = data.azurerm_resource_group.default.id
  location  = data.azurerm_resource_group.default.location
  name      = "${var.prefix}-ingress-${random_string.ingress.result}"

  body = jsonencode({
    properties : {
      managedEnvironmentId = azurerm_container_app_environment.env.id

      configuration = {
        activeRevisionsMode = "Single"

        ingress = {
          external      = true
          allowInsecure = false
          targetPort    = 80
          transport     = "Auto"

          traffic = [
            {
              latestRevision = true
              weight         = 100
            }
          ]
        }
      }
      template = {
        containers = [
          {
            name      = "main"
            image     = "nginx:1.23"
            resources = {
              cpu    = 0.25
              memory = "0.5Gi"
            }

            command = [
              "bash",
              "-c",
              templatefile("${path.module}/nginx-entrypoint.sh", {
                nginx_conf : templatefile("${path.module}/reverse_proxy.conf", {
                  ip_address : data.azurerm_virtual_machine.cromwell.private_ip_address,
                  port : 8000
                })
              })
            ]
          }
        ]
        scale = {
          minReplicas = 0
          maxReplicas = 1
        }
      }
    }
  })
}

data "azurerm_subscription" "sub" {
  subscription_id = var.subscriptionId
}

resource "azapi_resource" "auth_config" {
  type      = "Microsoft.App/containerApps/authConfigs@2022-10-01"
  name      = "current"
  parent_id = azapi_resource.container_app.id

  body = jsonencode({
    properties = {
      globalValidation = {
        excludedPaths               = []
        unauthenticatedClientAction = "Return401"
      }
      httpSettings = {
        requireHttps = true
      }
      identityProviders = {
        azureActiveDirectory = {
          enabled = true
          login   = {
            disableWWWAuthenticate = false
            loginParameters        = []
          }
          registration = {
            clientId = azuread_application.workbench_client.application_id
          }
          validation = {
            defaultAuthorizationPolicy = {
              allowedApplications = [
                azuread_application.workbench_client.application_id
              ]
            }
            jwtClaimChecks = {
              allowedClientApplications = [
                azuread_application.workbench_client.application_id
              ]
            }
          }
        }
      }
      platform = {
        enabled = true
      }
    }
  })
}
