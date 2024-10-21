output "tenantId" {
  value = module.ingress.tenantId
}

output "subscriptionId" {
  value = var.subscriptionId
}

output "resourceGroup" {
  value = var.resourceGroupName
}

output "storageAccount" {
  value = var.storageAccountName
}

output "workbench_client_id" {
  value = module.ingress.workbench_client_id
}

output "workbench_client_secret" {
  value     = module.ingress.workbench_client_secret
  sensitive = true
}

output "ingress_name" {
  value = module.ingress.ingress_name
}

output "ingress_url" {
  value = module.ingress.ingress_url
}