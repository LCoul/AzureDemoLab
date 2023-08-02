# https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-group-policy-powershell
# Run the script in PowerShell as administrator
Clear-Host

# 1. CONNECT TO AZURE
Write-Host "Connecting to Azure..." -ForegroundColor Yellow
Connect-AzAccount -WarningAction SilentlyContinue | Out-Null
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

# 2. Register resource providers
Write-Host "Registering resource providers" -ForegroundColor Yellow
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridCompute | Out-Null
Register-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration | Out-Null
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity | Out-Null
Register-AzResourceProvider -ProviderNamespace Microsoft.AzureArcData | Out-Null


$resourceGroup = Read-Host "Provide a resourcegroup name for your deployment"
while ($resourceGroup -eq "") {
    Write-Host "You must enter a name for your new resource group" -ForegroundColor Yellow
    $resourceGroup = Read-Host "Provide a name for your new resource group" 
}
$resourceGroup = $resourceGroup + (Get-Random -Minimum 100000 -Maximum 1000000)
$location = Read-Host "Provide a location for your deployment (e.g. West US, WestUS, East US,EastUS2, etc.)"
$locations = @("eastus", "eastus2", "westus", "westus2", "east us", "east us 2", "west us", "west us 2")
while ($locations -notcontains $location.ToLower()) {
    Write-Host "You must enter a valid location" -ForegroundColor Yellow
    $location = Read-Host "Provide a location for your deployment (e.g. West US, WestUS, East US,EastUS2, etc.)"
}
# 3. Create a resource group
Write-Host "Creating a resource group" -ForegroundColor Yellow
New-AzResourceGroup -Name $resourceGroup -Location $location | Out-Null

# 4. Create a remote share
Write-Host "Creating a remote share" -ForegroundColor Yellow
$path = "$env:HOMEDRIVE\AzureArc"
If(!(Test-Path -PathType container $path))
{
      New-Item -ItemType Directory -Path $path
}
New-SmbShare -Name "AzureArc" -Path $path -FullAccess "$env:USERDOMAIN\$env:USERNAME" | Out-Null
$RemoteShare = (Get-SmbShare | Where-Object { $_.Name -eq "AzureArc" }).Name

Write-Host "Downloading the Azure Connected Machine Agent and the Arc enabled servers group policy" -ForegroundColor Yellow
Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile "$path\AzureConnectedMachineAgent.msi"
Write-Host "Downloading the Azure Connected Machine Agent and the Arc enabled servers group policy" -ForegroundColor Yellow
Invoke-WebRequest -Uri "https://github.com/Azure/ArcEnabledServersGroupPolicy/releases/download/1.0.5/ArcEnabledServersGroupPolicy_v1.0.5.zip" -OutFile "$path\ArcEnabledServersGroupPolicy_v1.0.5.zip"

Write-Host "Extracting the Arc enabled servers group policy from the archive file" -ForegroundColor Yellow
Expand-Archive -LiteralPath "$($path)\ArcEnabledServersGroupPolicy_v1.0.5.zip" -DestinationPath $path
Set-Location -Path "$($path)\ArcEnabledServersGroupPolicy_v1.0.5"



Write-Host "Creating a service principal" -ForegroundColor Yellow
$ArcServerOnboardingDetail = New-Item -ItemType File -Path "$path\ArcServerOnboarding.txt"
$ServicePrincipal = New-AzADServicePrincipal -DisplayName "Arc server onboarding account" -Role "Azure Connected Machine Onboarding"
$ServicePrincipal | Format-Table AppId, @{ Name = "Secret"; Expression = { $_.PasswordCredentials.SecretText } }

$AppId = $ServicePrincipal.AppId
$Secret = $ServicePrincipal.PasswordCredentials.SecretText

$DC = Get-ADDomainController
$DomainFQDN = $DC.Domain
$ReportServerFQDN = $DC.HostName
$TenantId = $subs[$subRank - 1].TenantId

.\DeployGPO.ps1 -DomainFQDN $DomainFQDN `
-ReportServerFQDN $ReportServerFQDN `
-ArcRemoteShare $RemoteShare `
-ServicePrincipalSecret $Secret `
-ServicePrincipalClientId $AppId `
-SubscriptionId $subId `
-ResourceGroup $resourceGroup `
-Location $Location `
-TenantId $TenantId

"Service Principal ID: $($AppId)`n------------------------------------------------------------------" | Out-File -FilePath $ArcServerOnboardingDetail
"Service Principal Secret: $($Secret)`n------------------------------------------------------------------`n" | Out-File -FilePath $ArcServerOnboardingDetail -Append
".\DeployGPO.ps1 -DomainFQDN $DomainFQDN `
-ReportServerFQDN $ReportServerFQDN `
-ArcRemoteShare $RemoteShare `
-ServicePrincipalSecret $Secret `
-ServicePrincipalClientId $AppId `
-SubscriptionId $subId `
-ResourceGroup $resourceGroup `
-Location $Location `
-TenantId $TenantId" | Out-File -FilePath $ArcServerOnboardingDetail -Append

Write-Host -ForegroundColor Green "The AppId, Secret, and the onboarding script have been saved to $ArcServerOnboardingDetail"
Write-Host

