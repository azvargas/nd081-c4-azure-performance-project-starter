# Variables
$resourceGroup = "acdnd-c4-project"
$location = "westus"
$osType = "Ubuntu2204"
$vmssName = "udacity-vmss"
$adminName = "udacityadmin"
$randomEnd = Get-Random
$storageAccount = "udacitydiag$randomEnd"
$bePoolName = "$vmssName-bepool"
$lbName = "$vmssName-lb"
$lbRule = "$lbName-network-rule"
$nsgName = "$vmssName-nsg"
$vnetName = "$vmssName-vnet"
$subnetName = "$vnetName-subnet"
$probeName = "tcpProbe"
$vmSize = "Standard_B1ls"
$storageType = "Standard_LRS"

# Create Resource Group
Write-Output "STEP 0 - Creating resource group $resourceGroup..."
az group create `
    --name $resourceGroup `
    --location $location `
    --verbose
Write-Output "Resource group created: $resourceGroup"

# Create Storage Account
Write-Output "STEP 1 - Creating storage account $storageAccount..."
az storage account create `
    --name $storageAccount `
    --resource-group $resourceGroup `
    --location $location `
    --sku $storageType
Write-Output "Storage account created: $storageAccount"

# Create Network Security Group
Write-Output "STEP 2 - Creating network security group $nsgName..."
az network nsg create `
    --resource-group $resourceGroup `
    --name $nsgName `
    --verbose
Write-Output "Network security group created: $nsgName"

# Create VM Scale Set
Write-Output "STEP 3 - Creating VM scale set $vmssName..."
az vmss create `
    --resource-group $resourceGroup `
    --name $vmssName `
    --image $osType `
    --vm-sku $vmSize `
    --nsg $nsgName `
    --subnet $subnetName `
    --vnet-name $vnetName `
    --backend-pool-name $bePoolName `
    --storage-sku $storageType `
    --load-balancer $lbName `
    --custom-data cloud-init.txt `
    --upgrade-policy-mode automatic `
    --admin-username $adminName `
    --generate-ssh-keys `
    --verbose
Write-Output "VM scale set created: $vmssName"

# Associate NSG with VMSS Subnet
Write-Output "STEP 4 - Associating NSG: $nsgName with subnet: $subnetName..."
az network vnet subnet update `
    --resource-group $resourceGroup `
    --name $subnetName `
    --vnet-name $vnetName `
    --network-security-group $nsgName `
    --verbose
Write-Output "NSG: $nsgName associated with subnet: $subnetName"

# Create Health Probe
Write-Output "STEP 5 - Creating health probe $probeName..."
az network lb probe create `
    --resource-group $resourceGroup `
    --lb-name $lbName `
    --name $probeName `
    --protocol tcp `
    --port 80 `
    --interval 5 `
    --threshold 2 `
    --verbose
Write-Output "Health probe created: $probeName"

# Create Network Load Balancer Rule
Write-Output "STEP 6 - Creating network load balancer rule $lbRule..."
az network lb rule create `
    --resource-group $resourceGroup `
    --name $lbRule `
    --lb-name $lbName `
    --probe-name $probeName `
    --backend-pool-name $bePoolName `
    --backend-port 80 `
    --frontend-ip-name loadBalancerFrontEnd `
    --frontend-port 80 `
    --protocol tcp `
    --verbose
Write-Output "Network load balancer rule created: $lbRule"

# Add Port 80 to Inbound Rule in NSG
Write-Output "STEP 7 - Adding port 80 to NSG $nsgName..."
az network nsg rule create `
    --resource-group $resourceGroup `
    --nsg-name $nsgName `
    --name Port_80 `
    --destination-port-ranges 80 `
    --direction Inbound `
    --priority 100 `
    --verbose
Write-Output "Port 80 added to NSG: $nsgName"

# Add Port 22 to Inbound Rule in NSG
Write-Output "STEP 8 - Adding port 22 to NSG $nsgName..."
az network nsg rule create `
    --resource-group $resourceGroup `
    --nsg-name $nsgName `
    --name Port_22 `
    --destination-port-ranges 22 `
    --direction Inbound `
    --priority 110 `
    --verbose
Write-Output "Port 22 added to NSG: $nsgName"

Write-Output "VMSS script completed!"