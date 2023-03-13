# Cromwell on Azure

## Overview
The DNAstack Cromwell installer uses Microsoft's [Cromwell on Azure](https://github.com/microsoft/CromwellOnAzure)
installer and Terraform to create an installation of Cromwell using Azure Virtual Machines, Container Apps,
and Azure Batch, in Azure resource group.

An Azure Container App is used as the ingress for all requests to Cromwell, and calling this service requires an
Azure Active Directory token from a pre-configured Azure Application Registration.

### Resource Layout
The following represents the layout of resources, where items in italics are created as part of this installation:

* Active Directory Tenant
  * Azure Subscription
    * _Resource Group_
      * _Virtual Network_
      * _Virtual Machine with disks (OS and storage)_
      * _Managed Identity_
      * _Azure Cosmos DB account_
      * _Storage Account_
      * _Log Analytics Workspace_
      * _Container App with external ingress_
  * _Application Registration (for authentication with ingress)_

## Prerequisites
To run this script, you must have the following prepared:
1. Pick an existing Azure subscription and find its ID
2. Install the `az` and `terraform` command-line tools.
3. _Optional_: Install [jq](https://stedolan.github.io/jq/) &mdash; this is used in documented commands for testing
   your installation, and is not required for installing the engine.

## Installation
1. Run the [CromwellOnAzure script](https://github.com/microsoft/CromwellOnAzure#Deploy-your-instance-of-Cromwell-on-Azure).
   This will require you to have installed the `az` client and authenticated with `az login`.
2. Create file with variable assignments for your installation, `cromwell.tfvars`, replacing `$SUBSCIPTION_ID`,
   `$RESOURCE_GROUP`, `$LOG_ANALYTICS_WORKSPACE`, `$VIRTUAL_NETWORK_NAME`, and `$VIRTUAL_MACHINE_NAME` with literal
   values:

    ```terraform
    subscriptionId            = "$SUBSCRIPTION_ID"
    resourceGroupName         = "$RESOURCE_GROUP"
    logAnalyticsWorkspaceName = "$LOG_ANALYTICS_WORKSPACE"
    virtualNetworkName        = "$VIRTUAL_NETWORK_NAME"
    virtualMachineName        = "$VIRTUAL_MACHINE_NAME"
    ```
   
    * `$SUBSCRIPTION_ID`: use the same ID used when running the Microsoft CromwellOnAzure script.
    * `$RESOURCE_GROUP`: is generated for you by the Microsoft CromwellOnAzure script; consult the output to find the name.
    * `$LOG_ANALYTICS_WORKSPACE`: is generated for you by the Microsoft CromwellOnAzure script; consult the output
      of the CromwellOnAzure script, or run this command using the `$SUBSCRIPTION_ID` and `$RESOURCE_GROUP` from the
      previous points:
      ```bash
      az monitor log-analytics workspace list --subscription $SUBSCRIPTION_ID -g $RESOURCE_GROUP -o json | jq -r '.[].name'
      ```
   * `$VIRTUAL_NETWORK_NAME`: is generated for you by the Microsoft CromwellOnAzure script; consult the output
     of the CromwellOnAzure script, or run this command using the `$SUBSCRIPTION_ID` and `$RESOURCE_GROUP` from the
     previous points:
     ```bash
     az network vnet list --subscription $SUBSCRIPTION_ID -g $RESOURCE_GROUP -o json | jq -r '.[].name'
     ```
   * `$VIRTUAL_MACHINE_NAME`: is generated for you by the Microsoft CromwellOnAzure script; consult the output
     of the CromwellOnAzure script, or run this command using the `$SUBSCRIPTION_ID` and `$RESOURCE_GROUP` from the
     previous points:
     ```bash
     az vm list --subscription $SUBSCRIPTION_ID -g $RESOURCE_GROUP -o json | jq -r '.[].name'
     ```
3. Apply the configuration with your variable assignments:

    ```bash
    terraform apply -var-file=cromwell.tfvars
    ```

   Terraform will print out a plan and ask you to type `yes` before starting. If you are running this for the first
   time, the plan should only add resources (no changes or removals). _Make sure the plan only adds resources
   before accepting!_

## Destroying Installation
Destroying an installation requires two steps:

1. Destroy resources created by Terraform:
    ```bash
    terraform destroy -var-file=cromwell.tfvars
    ```
2. [Delete the resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/delete-resource-group?tabs=azure-powershell)
containing Cromwell.

## Using the Cromwell Installation
### Getting Deployment Information
There are two pieces of information you need to start using your new Cromwell installation:
* The ingress domain name
* The Azure App Registry credentials (ID and secret)

To get the ingress domain name, run:
```bash
az containerapp show \
  --subscription $(terraform output --raw subscriptionId) \
  -g $(terraform output --raw resourceGroup) \
  --name $(terraform output --raw ingress_name) \
  -o json \
  | jq -r '.properties.configuration.ingress.fqdn'
```

To get the Azure App Registry client credentials, run:
```bash
terraform output --raw workbench_client_id
terraform output --raw workbench_client_secret
```

### Sending Requests to Cromwell
To send requests to Cromwell, use the App Registration credentials to obtain an OAuth2 access token, and then use
that as a bearer token for requests to the Cromwell API.

After running terraform, this command can be used to obtain an access token and assign it to an environment variable:
```bash
ACCESS_TOKEN="$(
  curl -X POST "https://login.microsoftonline.com/$(terraform output --raw tenantId)/oauth2/v2.0/token" \
    -u "$(terraform output --raw workbench_client_id):$(terraform output --raw workbench_client_secret)" \
    -d grant_type=client_credentials \
    -d scope="$(terraform output --raw workbench_client_id)/.default" \
    | jq -r '.access_token'
)"
```

You'll need to look up the domain name of the ingress route. This command assigns it to a variable:
```bash
CROMWELL_DOMAIN="$(
az containerapp show \
  --subscription $(terraform output --raw subscriptionId) \
  -g $(terraform output --raw resourceGroup) \
  --name $(terraform output --raw ingress_name) \
  -o json \
  | jq -r '.properties.configuration.ingress.fqdn'
)"
```

Now you can send an authenticated request to the Cromwell API:
```bash
curl "https://${CROMWELL_DOMAIN}/api/ga4gh/wes/v1/service-info" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```