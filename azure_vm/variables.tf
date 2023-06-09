variable "subscriptionId" {
  type     = string
  nullable = false

  description = "The ID of the Azure Subscription containing the Cromwell installation."
}

variable "resourceGroupName" {
  type     = string
  nullable = false

  description = "The name of the Azure Resource Group containing the Cromwell installation."
}

variable "logAnalyticsWorkspaceName" {
  type     = string
  nullable = false

  description = "The name of the Log Analytics Workspace created by the CromwellOnAzure script."
}

variable "virtualNetworkName" {
  type     = string
  nullable = false

  description = "The name of the Azure Virtual Network created by the CromwellOnAzure script."
}

variable "virtualMachineName" {
  type     = string
  nullable = false

  description = "The name of the Azure Virtual Machine created by the CromwellOnAzure script."
}

variable "storageAccountName" {
  type     = string
  nullable = false

  description = "The name of the Azure Storage Account generated by the CromwellOnAzure script."
}

variable "cromwellExecutionsStorageContainerName" {
  type     = string
  nullable = false
  default  = "cromwell-executions"

  description = "The name of the Azure Storage Container used for Cromwell execution logs (generated by the CromwellOnAzure script)."
}

variable "subnetIpMask" {
  type    = string
  default = "10.1.2.0/23"

  description = "The IP/mask for a new subnet for the generated Azure Container App. Only change this if you have encounter problems with the default."
}

variable "prefix" {
  type     = string
  nullable = false
  default  = "coa"

  description = "The prefix used in names of resources generated by this Terraform configuration. Defaults to 'coa'."
}
