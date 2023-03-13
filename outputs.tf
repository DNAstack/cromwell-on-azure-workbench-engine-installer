output "tenantId" {
  value = data.azurerm_client_config.current.tenant_id
}

output "subscriptionId" {
  value = var.subscriptionId
}

output "resourceGroup" {
  value = data.azurerm_resource_group.default.name
}

output "workbench_client_id" {
  value = azuread_application.workbench_client.application_id
}

output "workbench_client_secret" {
  value     = azuread_application_password.secret.value
  sensitive = true
}

output "ingress_name" {
  value = azapi_resource.container_app.name
}