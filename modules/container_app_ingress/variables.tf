variable "subscriptionId" {
  type     = string
  nullable = false
}

variable "resourceGroupName" {
  type     = string
  nullable = false
}

variable "logAnalyticsWorkspaceName" {
  type     = string
  nullable = false
}

variable "virtualNetworkName" {
  type     = string
  nullable = false
}

variable "cromwellIpAddress" {
  type     = string
  nullable = false
}

variable "storageAccountName" {
  type     = string
  nullable = false
}

variable "cromwellExecutionsStorageContainerName" {
  type     = string
  nullable = false
}

variable "subnetIpMask" {
  type    = string
  default = "10.1.2.0/23"
}

variable "prefix" {
  type     = string
  nullable = false
  default  = "coa"
}
