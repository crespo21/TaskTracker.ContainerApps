# Load configuration from the setup script
if (Test-Path "azure-config.ps1") {
    . .\azure-config.ps1
    Write-Host "Configuration loaded from azure-config.ps1"
} else {
    Write-Host "Error: azure-config.ps1 not found. Please run setup-azure-resources-fixed-v2.ps1 first."
    exit 1
}

Write-Host "Deploying Container App with configuration:"
Write-Host "Resource Group: $RESOURCE_GROUP"
Write-Host "Environment: $ENVIRONMENT"
Write-Host "Backend API Name: $BACKEND_API_NAME"
Write-Host "Container Registry: $AZURE_CONTAINER_REGISTRY_NAME"
Write-Host "Target Port: $TARGET_PORT"

# Check if Dockerfile exists
if (-not (Test-Path "Dockerfile")) {
    Write-Host "Error: Dockerfile not found in current directory."
    Write-Host "Please ensure you're in the correct directory: TasksTracker.TasksManager.Backend.Api"
    exit 1
}

# Build and push the Docker image to ACR
Write-Host "`nBuilding and pushing Docker image to ACR..."
try {
    az acr build `
        --registry $AZURE_CONTAINER_REGISTRY_NAME `
        --image "tasksmanager/$BACKEND_API_NAME" `
        --file 'Dockerfile' .
    
    if ($LASTEXITCODE -ne 0) {
        throw "ACR build failed"
    }
} catch {
    Write-Host "Error: Failed to build and push Docker image to ACR"
    Write-Host $_.Exception.Message
    exit 1
}

# Create and deploy the Container App
Write-Host "`nCreating and deploying Container App..."
try {
    $fqdn = az containerapp create `
        --name $BACKEND_API_NAME `
        --resource-group $RESOURCE_GROUP `
        --environment $ENVIRONMENT `
        --image "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io/tasksmanager/$BACKEND_API_NAME" `
        --registry-server "$AZURE_CONTAINER_REGISTRY_NAME.azurecr.io" `
        --target-port $TARGET_PORT `
        --ingress 'external' `
        --min-replicas 1 `
        --max-replicas 3 `
        --cpu 0.25 `
        --memory 0.5Gi `
        --query properties.configuration.ingress.fqdn `
        --output tsv

    if ($LASTEXITCODE -ne 0) {
        throw "Container app creation failed"
    }
} catch {
    Write-Host "Error: Failed to create Container App"
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host "`n=== Container App Deployed Successfully ==="
Write-Host "Container App Name: $BACKEND_API_NAME"
Write-Host "FQDN: $fqdn"
Write-Host "Full URL: https://$fqdn"
Write-Host "`nYou can now test your API at:"
Write-Host "  - API Base: https://$fqdn/api/tasks"
Write-Host "  - OpenAPI: https://$fqdn/openapi/v1.json"
Write-Host "  - Health Check: https://$fqdn/health"

Write-Host "`nExample API calls:"
Write-Host "  GET https://$fqdn/api/tasks?createdBy=test.user"
Write-Host "  POST https://$fqdn/api/tasks"