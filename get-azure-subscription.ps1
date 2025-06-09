# Retrieve the currently active Azure subscription ID
$AZURE_SUBSCRIPTION_ID = az account show --query id --output tsv

# Set a specific Azure Subscription ID (if you have multiple subscriptions)
# $AZURE_SUBSCRIPTION_ID = "<Your Azure Subscription ID>" # Your Azure Subscription id which you can find on the Azure portal
# az account set --subscription $AZURE_SUBSCRIPTION_ID

Write-Output $AZURE_SUBSCRIPTION_ID
