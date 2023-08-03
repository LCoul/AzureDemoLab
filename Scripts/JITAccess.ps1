function Enable-JITAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [string]$Location,
        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId,
        [Parameter(Mandatory = $false)]
        [string]$VMName
    )

    Clear-Host
    <#Write-Verbose "Checking the installation status of the PowerShellGet module"
    Write-Verbose "Checking the installation status of the Azure PowerShell module"

    # Checking the installation status of PowerShellGet and Azure PowerShell modules
    if (-not(Get-Module -Name PowerShellGet -ListAvailable)) {
        Write-Warning -Message ('PowerShellGet module not installed. Attempting to install...')
        Install-Module -Name PowerShellGet -AllowClobber -Scope CurrentUser -Force
    }
    if (-not(Get-Module -Name az -ListAvailable)) {
        Write-Warning -Message ('Az module not installed. Attempting to install...')
        Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
    }
    # Importing the PowerShellGet and Azure PowerShell modules
    Write-Verbose "Importing the PowerShellGet and Azure PowerShell modules"
    Import-Module -Name PowerShellGet -ErrorAction SilentlyContinue | Out-Null
    Import-Module -Name Az -ErrorAction SilentlyContinue | Out-Null
    #>

    # Connect to Azure
    Write-Verbose "Connecting to Azure"
    Connect-AzAccount -WarningAction SilentlyContinue | Out-Null
    
    # Select a subscription
    Write-Verbose "Getting available subscriptions"
    Write-Host -ForegroundColor Green "`nAvailable subscription(s)"
    $azSubscriptions = (Get-AzSubscription).Name
    $subNumbers = @()
    for ($i = 0; $i -lt $azSubscriptions.Count; $i++) {
        "$($i+1). $($azSubscriptions[$i])"
        $subNumbers += $i + 1
    }
    
    Write-Host
    $subNumber = Read-Host "Select a subscription"
    while ($subNumber -notin $subNumbers) {
        Write-Host "Enter a correct subscription number. The number must be between 1 and $($subNumbers.Count)" -ForegroundColor Yellow
        $subNumber = Read-Host "Select a subscription"
    }
    $subName = $azSubscriptions[$subNumber - 1]
    $selectionSubscription = Get-AzSubscription | Where-Object { $_.Name -eq $subName }
    $subscriptionId = $selectionSubscription.Id
    Write-Verbose "Setting the tenant, subscription, and environment for cmdlets to use in the current session"
    Set-AzContext -SubscriptionId $subscriptionId | Out-Null
    
    # Select a resource group
    Write-Verbose "Getting available resource groups with virtual machines in $subName subscription"
    $azRGs = @()
    $azRGs += Get-AzVM | Select-Object -ExpandProperty ResourceGroupName -Unique
    if ($azRGs.Count -eq 0) {
        Write-Host "No resource groups found with virtual machines in $subName subscription. Exiting..." -ForegroundColor Yellow
        break
    }
    else {
        Write-Host -ForegroundColor Green "`nAvailable resource groups(s) with virtual machines in $subName subscription"
        $rgNumbers = @()
        for ($i = 0; $i -lt $azRGs.Count; $i++) {
            "$($i+1). $($azRGs[$i])"
            $rgNumbers += $i + 1
        }
    }

    
    Write-Host
    $rgNumber = Read-Host "Select a resource group"
    while ($rgNumber -notin $rgNumbers) {
        Write-Host "Enter a correct resource group number. The number must be between 1 and $($rgNumbers.Count)" -ForegroundColor Yellow
        $rgNumber = Read-Host "Select a resource group"
    }
    $ResourceGroupName = $azRGs[$rgNumber - 1]
    $location = (Get-AzResourceGroup -Name $ResourceGroupName).Location
    
    Write-Host
    Write-Host -ForegroundColor Cyan "The resource group $ResourceGroupName in the subscription $subName will be used for your deployment"
    
    # Select a VM to enable JIT access
    Write-Verbose "Getting available virtual machines in $ResourceGroupName resource group"
    $azVMs = Get-AzVM | Where-Object { $_.ResourceGroupName -eq $ResourceGroupName }
    $vmNumbers = @()
    for ($i = 0; $i -lt $azVMs.Count; $i++) {
        "$($i+1).`t$($azVMs[$i].Name)`t[$($azVMs[$i].StorageProfile.OsDisk.OsType)]"
        $vmNumbers += $i + 1
    }

    Write-Host
    $vmNumber = Read-Host "Select a VM to enable JIT access"
    while ($vmNumber -notin $vmNumbers) {
        Write-Host "Enter a correct VM number. The number must be between 1 and $($vmNumbers.Count)" -ForegroundColor Yellow
        $vmNumber = Read-Host "Select a VM"
    }
    $VMName = $azVMs[$vmNumber - 1].Name
    
    $VMOSType = $azVMs[$vmNumber - 1].StorageProfile.OsDisk.OsType
    
    $Ports = @("3389", "22")
    $SelectedPorts = @()

    if($VMOSType -eq "Windows") {
        Write-Output "Windows VM selected, TCP port 3389 will be opened for Just-In-Time access"
        $SelectedPorts += $Ports[0]
        $Ports += "3389"
    }
    elseif ($VMOSType -eq "Linux") {
        Write-Output "Linux VM selected, TCP port 22 will be opened for Just-In-Time access"
        $SelectedPorts += $Ports[1]
        $Ports += "22"
    }

    if ($SelectedPorts.Count -eq 0) {
        Write-Host "No ports selected for JIT access on VM $VMName. Exiting..." -ForegroundColor Yellow
        break    
    }

        $AccessTime = Read-Host "Enter the access time in hours (default is 1 hour)"
        if ($AccessTime -eq "") {
            $AccessTime = 1
        }
        else {
            while ($AccessTime -lt 1 -or $AccessTime -gt 8) {
                Write-Host "Enter a correct access time. The time must be between 1 and 8 hours" -ForegroundColor Yellow
                $AccessTime = Read-Host "Enter the access time in hours (default is 1 hour)"
            }
        }

    Write-Verbose "Enabling JIT access for $VMName for $AccessTime hour(s) on:"
    $SelectedPorts | ForEach-Object { Write-Host "TCP port: $_" -ForegroundColor Cyan }

    # Assign a variable that holds the just-in-time VM access rules for a VM:
    $JitPolicy = (@{
            id    = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$VMName";
            ports = @()
        })

    foreach ($port in $SelectedPorts) {
        $JitPolicy.ports += @{
            number                     = $port;
            protocol                   = "*";
            allowedSourceAddressPrefix = @("*");
            maxRequestAccessDuration   = "PT$($AccessTime)H"
        }
    }

    # Insert the VM just-in-time VM access rules into an array:
    $JitPolicyArr = @($JitPolicy)

    # Configure the just-in-time VM access rules on the selected VM:
    Set-AzJitNetworkAccessPolicy -Kind "Basic" -Location $Location -Name $VMName -ResourceGroupName $ResourceGroupName -VirtualMachine $JitPolicyArr | Out-Null

    # Configure the VM request access properties:
    $time = (Get-Date).ToUniversalTime()
    $IPAddress = (Invoke-WebRequest -uri "https://api.ipify.org/").Content
    $JitPolicyVm = (@{
            id    = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$VMName";
            ports = @()
        })

    foreach ($port in $SelectedPorts) {
        $JitPolicyVm.ports += @{
            number                     = $port;
            endTimeUtc                 = $time.AddHours($AccessTime);
            allowedSourceAddressPrefix = @($IPAddress)
        }
    }

    # Insert the VM access request parameters in an array:     
    $JitPolicyArr = @($JitPolicyVm)

    # Send the request access (use the resource ID from step 1)
    Start-AzJitNetworkAccessPolicy -ResourceId "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Security/locations/$Location/jitNetworkAccessPolicies/$VMName" -VirtualMachine $JitPolicyArr | Out-Null

    Write-Host "JIT access enabled for virtual machine $VMName`n" -ForegroundColor Green

    $VMPublicIP = ((Get-AzNetworkInterface ).IpConfigurations.PublicIpAddress.Id | Foreach-Object -Process {$_.Split('/')| Select-Object -Last 1} | 
    Foreach-Object -Process {Get-AzPublicIpAddress -Name $_}).IpAddress
    Write-Host "Public IP address of the VM $VMName is $VMPublicIP" -ForegroundColor Cyan
}
Enable-JITAccess -Verbose