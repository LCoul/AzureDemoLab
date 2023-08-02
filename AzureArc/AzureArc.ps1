# https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal
# Run the script in PowerShell as administrator
# The script will create a resource group, a remote share, and a service principal for the Arc server onboarding for Windows Servers
Clear-Host
Write-Verbose "Connecting to Azure..."
Connect-AzAccount | Out-Null
$subs = @()
$subs += Get-AzSubscription
if ($subs.Count -eq 0) {
    Write-Host "No subscription found. Exiting..." -ForegroundColor Yellow
    break
}
else {
    Write-Host -ForegroundColor Green "`nAvailable subscription(s)"
    $subRanks = @()
    for ($i = 0; $i -lt $subs.Count; $i++) {
        "$($i+1). $($subs[$i].Name) (ID: $($subs[$i].Id), Tenant ID: $($subs[$i].TenantId))"
        $subRanks += $i + 1
    }
}
Write-Host
$subRank = Read-Host "Select a subscription"
while ($subRank -notin $subRanks) {
    Write-Host "Enter a valid number. The number must be between 1 and $($subRanks.Count)" -ForegroundColor Yellow
    $subRank = Read-Host "Select a subscription"
}

$subName = $subs[$subRank - 1].Name
$subId = $subs[$subRank - 1].Id
Write-Host
Write-Host -ForegroundColor Cyan "Subscription name: `"$subName`" will be use for your deployment" 
Set-AzContext -SubscriptionId $subId | Out-Null

# Register resource providers
Write-Verbose "Registering resource providers"
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridCompute | Out-Null
Register-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration | Out-Null
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity | Out-Null
Register-AzResourceProvider -ProviderNamespace Microsoft.AzureArcData | Out-Null

# Create a resource group
$resourceGroup = Read-Host "Provide a resourcegroup name for your deployment"
while ($resourceGroup -eq "") {
    Write-Host "You must enter a name for your new resource group" -ForegroundColor Yellow
    $resourceGroup = Read-Host "Provide a name for your new resource group" 
}
$resourceGroup = $resourceGroup + (Get-Random -Minimum 100000 -Maximum 1000000)
$location = Read-Host "Provide a location for your deployment (e.g. West US, East US, etc.)"
$locations = @("eastus", "eastus2", "westus", "westus2", "east us", "east us 2", "west us", "west us 2")
while ($locations -notcontains $location.ToLower()) {
    Write-Host "You must enter a valid location" -ForegroundColor Yellow
    $location = Read-Host "Provide a location for your deployment (e.g. West US, WestUS, East US,EastUS2, etc.)"
}
#Create a resourcegroup
Write-Verbose "Creating a resource group"
New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null

Write-Verbose "Creating a remote share"
New-Item -ItemType Directory -Name "AzureArc" -Path "$env:HOMEDRIVE\"
New-SmbShare -Name "AzureArc" -Path "$env:HOMEDRIVE\AzureArc" -FullAccess "$env:USERDOMAIN\$env:USERNAME" | Out-Null
$RemoteShare = (Get-SmbShare | Where-Object { $_.Name -eq "AzureArc" }).Name

Write-Verbose "Creating a service principal"
$ServicePrincipalDetail = New-Item -ItemType File -Path "$env:HOMEDRIVE\$RemoteShare\ArcServerOnboarding.txt"
$ServicePrincipal = New-AzADServicePrincipal -DisplayName "Arc server onboarding account" -Role "Azure Connected Machine Onboarding"
$ServicePrincipal | Format-Table AppId, @{ Name = "Secret"; Expression = { $_.PasswordCredentials.SecretText } }

"Service Principal ID: $($ServicePrincipal.AppId)" | Out-File -FilePath $ServicePrincipalDetail
"Service Principal Secret: $($ServicePrincipal.PasswordCredentials.SecretText)" | Out-File -FilePath $ServicePrincipalDetail -Append

Write-Host -ForegroundColor Yellow "Go to the Azure portal and ."


$DomainFQDN = 
$ReportServerFQDN =
$ArcRemoteShare =
$ServicePrincipalClientId = "$ServicePrincipal.AppId";
$ServicePrincipalSecret = $ServicePrincipal.PasswordCredentials.SecretText;
$SubscriptionId = $subId;
$ResourceGroup = $resourceGroup;
$Location = $location;
$TenantId = $subs[$subRank - 1].TenantId;

.\DeployGPO.ps1 -DomainFQDN dev.lab `
-ReportServerFQDN srv1.dev.lab `
-ArcRemoteShare AzureArc `
-ServicePrincipalSecret $ServicePrincipalSecret `
-ServicePrincipalClientId $ServicePrincipalClientId `
-SubscriptionId 2272a9d6-ae77-4ecb-8852-5c8866ee5a51 `
-ResourceGroup DemoAzureArc929575 `
-Location eastus `
-TenantId 3931f026-9b8a-4d3a-85b9-f8990331fe84

$ServicePrincipal.AppId



Write-Host -ForegroundColor Green "The service principal ID and secret have been saved to $ServicePrincipalDetail"
Write-Host -ForegroundColor Green "Select the following remote share, subscription, resourcegroup, location, and service principal`nwhen you generate the onboarding script from the Azure portal:"
Write-Host -ForegroundColor Cyan "Remote share name: $RemoteShare`nSubscription: $subName`nResource group: $resourceGroup`nLocation: $location`nService principal: $($ServicePrincipal.AppId)"