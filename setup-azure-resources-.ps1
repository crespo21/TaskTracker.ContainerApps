# Create a random, 6-digit, Azure safe string
$RANDOM_STRING=-join ((97..122) + (48..57) | Get-Random -Count 6 | ForEach-Object { [char]$_})
$RESOURCE_GROUP="rg-proof-of-concepts"
$LOCATION="southafricanorth"
$ENVIRONMENT="cae-tasks-tracker"
$WORKSPACE_NAME="law-tasks-tracker-$RANDOM_STRING"
$APPINSIGHTS_NAME="appi-tasks-tracker-$RANDOM_STRING"
$BACKEND_API_NAME="tasksmanager-backend-api"
$AZURE_CONTAINER_REGISTRY_NAME="crtaskstracker$RANDOM_STRING"
$VNET_NAME="vnet-tasks-tracker"
$TARGET_PORT=8080

# Display all variables
Write-Host "Azure Resource Configuration:"
Write-Host "Random String: $RANDOM_STRING"
Write-Host "Resource Group: $RESOURCE_GROUP"
Write-Host "Location: $LOCATION"
Write-Host "Environment: $ENVIRONMENT"
Write-Host "Workspace Name: $WORKSPACE_NAME"
Write-Host "App Insights Name: $APPINSIGHTS_NAME"
Write-Host "Backend API Name: $BACKEND_API_NAME"
Write-Host "Container Registry Name: $AZURE_CONTAINER_REGISTRY_NAME"
Write-Host "VNet Name: $VNET_NAME"
Write-Host "Target Port: $TARGET_PORT"

# Register required resource providers and features
Write-Host "`nRegistering Azure resource providers and features..."
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights

# Register Application Insights workspace feature
az feature register --name AIWorkspacePreview --namespace microsoft.insights

# Wait for feature registration (this can take a few minutes)
Write-Host "Waiting for feature registration to complete..."
do {
    Start-Sleep -Seconds 10
    $featureState = az feature show --name AIWorkspacePreview --namespace microsoft.insights --query properties.state --output tsv
    Write-Host "Feature registration state: $featureState"
} while ($featureState -ne "Registered")

# Create a resource group to hold all the resources for the Azure Container Apps environment.
Write-Host "`nCreating resource group..."
az group create `
    --name $RESOURCE_GROUP `
    --location $LOCATION

# Create a virtual network (VNet) to secure our container apps.
Write-Host "`nCreating virtual network..."
az network vnet create `
    --name $VNET_NAME `
    --resource-group $RESOURCE_GROUP `
    --address-prefix 10.0.0.0/16 `
    --subnet-name ContainerAppSubnet `
    --subnet-prefix 10.0.0.0/27

# Azure Container Apps requires management of the subnet, so we must delegate exclusive control.
Write-Host "`nConfiguring subnet delegation..."
az network vnet subnet update `
    --name ContainerAppSubnet `
    --resource-group $RESOURCE_GROUP `
    --vnet-name $VNET_NAME `
    --delegations Microsoft.App/environments

# Retrieve the Azure Container App subnet resource ID
$ACA_ENVIRONMENT_SUBNET_ID = az network vnet subnet show `
    --name ContainerAppSubnet `
    --resource-group $RESOURCE_GROUP `
    --vnet-name $VNET_NAME `
    --query id `
    --output tsv

Write-Host "Subnet ID: $ACA_ENVIRONMENT_SUBNET_ID"

# Create an Azure Log Analytics workspace
Write-Host "`nCreating Log Analytics workspace..."
az monitor log-analytics workspace create `
    --resource-group $RESOURCE_GROUP `
    --workspace-name $WORKSPACE_NAME `
    --location $LOCATION

# Get Log Analytics workspace ID and key
$WORKSPACE_ID = az monitor log-analytics workspace show `
    --resource-group $RESOURCE_GROUP `
    --workspace-name $WORKSPACE_NAME `
    --query customerId `
    --output tsv

$WORKSPACE_SECRET = az monitor log-analytics workspace get-shared-keys `
    --resource-group $RESOURCE_GROUP `
    --workspace-name $WORKSPACE_NAME `
    --query primarySharedKey `
    --output tsv

Write-Host "Workspace ID: $WORKSPACE_ID"

# Create Application Insights instance (without workspace integration for now)
Write-Host "`nCreating Application Insights..."
az monitor app-insights component create `
    --app $APPINSIGHTS_NAME `
    --location $LOCATION `
    --resource-group $RESOURCE_GROUP `
    --application-type web

# Get Application Insights instrumentation key and connection string
$APPINSIGHTS_INSTRUMENTATION_KEY = az monitor app-insights component show `
    --app $APPINSIGHTS_NAME `
    --resource-group $RESOURCE_GROUP `
    --query instrumentationKey `
    --output tsv

$APPINSIGHTS_CONNECTION_STRING = az monitor app-insights component show `
    --app $APPINSIGHTS_NAME `
    --resource-group $RESOURCE_GROUP `
    --query connectionString `
    --output tsv

Write-Host "Application Insights Instrumentation Key: $APPINSIGHTS_INSTRUMENTATION_KEY"
Write-Host "Application Insights Connection String: $APPINSIGHTS_CONNECTION_STRING"

# Create an Azure Container Registry (ACR) instance
Write-Host "`nCreating Azure Container Registry..."
az acr create `
    --resource-group $RESOURCE_GROUP `
    --name $AZURE_CONTAINER_REGISTRY_NAME `
    --sku Basic `
    --location $LOCATION `
    --admin-enabled true

# Get ACR login server
$ACR_LOGIN_SERVER = az acr show `
    --resource-group $RESOURCE_GROUP `
    --name $AZURE_CONTAINER_REGISTRY_NAME `
    --query loginServer `
    --output tsv

Write-Host "ACR Login Server: $ACR_LOGIN_SERVER"

# Create an Azure Container Apps Environment (simplified without Application Insights for now)
Write-Host "`nCreating Container Apps Environment..."
az containerapp env create `
    --name $ENVIRONMENT `
    --resource-group $RESOURCE_GROUP `
    --location $LOCATION `
    --logs-workspace-id $WORKSPACE_ID `
    --logs-workspace-key $WORKSPACE_SECRET `
    --infrastructure-subnet-resource-id $ACA_ENVIRONMENT_SUBNET_ID

Write-Host "`n=== Azure Resources Created Successfully ==="
Write-Host "Resource Group: $RESOURCE_GROUP"
Write-Host "Location: $LOCATION"
Write-Host "VNet Name: $VNET_NAME"
Write-Host "Subnet ID: $ACA_ENVIRONMENT_SUBNET_ID"
Write-Host "Log Analytics Workspace: $WORKSPACE_NAME"
Write-Host "Workspace ID: $WORKSPACE_ID"
Write-Host "Application Insights: $APPINSIGHTS_NAME"
Write-Host "Container Registry: $AZURE_CONTAINER_REGISTRY_NAME"
Write-Host "ACR Login Server: $ACR_LOGIN_SERVER"
Write-Host "Container Apps Environment: $ENVIRONMENT"

# Save configuration to file for deployment script
$config = @"
`$RESOURCE_GROUP="$RESOURCE_GROUP"
`$ENVIRONMENT="$ENVIRONMENT"
`$BACKEND_API_NAME="$BACKEND_API_NAME"
`$AZURE_CONTAINER_REGISTRY_NAME="$AZURE_CONTAINER_REGISTRY_NAME"
`$TARGET_PORT=$TARGET_PORT
"@

$config | Out-File -FilePath "azure-config.ps1" -Encoding UTF8

Write-Host "`nConfiguration saved to azure-config.ps1"
Write-Host "`nNext steps:"
Write-Host "1. Run the deployment script to build and deploy your container"
Write-Host "2. powershell -ExecutionPolicy Bypass -File deploy-container-app-v2.ps1"