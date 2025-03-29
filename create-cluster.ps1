# Variables
$resourceGroup = "acdnd-c4-project"
$clusterName = "udacity-cluster"
$subscriptionId = "8f6db795-24df-4745-8066-e8241a289b77"

# Create AKS cluster
Write-Host "Step 1 - Creating AKS cluster $clusterName"
# For users working in their personal Azure account
# Note: This will not work for Cloud Lab users due to Log Analytics workspace restrictions
az aks create `
    --resource-group $resourceGroup `
    --name $clusterName `
    --node-count 1 `
    --enable-addons monitoring `
    --generate-ssh-keys

# For Cloud Lab users
az aks create `
    --resource-group $resourceGroup `
    --name $clusterName `
    --node-count 1 `
    --generate-ssh-keys

# Cloud Lab users log analytics workspace setup
az aks enable-addons -a monitoring -n $clusterName -g $resourceGroup `
--workspace-resource-id "/subscriptions/$subscriptionId/resourcegroups/$resourceGroup/providers/microsoft.operationalinsights/workspaces/Project5LogWks"

Write-Host "AKS cluster created: $clusterName"

# Connect to AKS cluster
Write-Host "Step 2 - Getting AKS credentials"

az aks get-credentials `
    --resource-group $resourceGroup `
    --name $clusterName `
    --verbose

Write-Host "Verifying connection to $clusterName"

kubectl get nodes

# Deploy to AKS cluster (optional)
# Write-Host "Deploying to AKS cluster"
# kubectl apply -f azure-vote.yaml