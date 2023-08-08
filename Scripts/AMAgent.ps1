# https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-manage?tabs=azure-powershell#install
# https://learn.microsoft.com/en-us/powershell/module/az.connectedmachine/get-azconnectedmachine?view=azps-10.1.0
# https://learn.microsoft.com/en-us/powershell/module/az.connectedmachine/new-azconnectedmachineextension?view=azps-10.1.0

function New-AzureMonitorWindowsAgent {
    [CmdletBinding()]
    param ()

    $azConnectedMachine = Get-AzConnectedMachine
    $machineNames = @($azConnectedMachine.Name)
    $resourceGroupName = ($azConnectedMachine | Select-Object -Property ResourceGroupName -Unique).ResourceGroupName
    $location = ($azConnectedMachine | Select-Object -Property Location -Unique).Location

    foreach ($machineName in $machineNames) {
        New-AzConnectedMachineExtension -Name AzureMonitorWindowsAgent `
            -ExtensionType AzureMonitorWindowsAgent `
            -Publisher Microsoft.Azure.Monitor `
            -ResourceGroupName $resourceGroupName `
            -MachineName $machineName `
            -Location $location `
            -EnableAutomaticUpgrade
    }
}
New-AzureMonitorWindowsAgent -Verbose

<#
$azConnectedMachine = Get-AzConnectedMachine
$extension = @()
$resourceGroupName = ($azConnectedMachine | Select-Object -Property ResourceGroupName -Unique).ResourceGroupName
$location = ($azConnectedMachine | Select-Object -Property Location -Unique).Location
$machineNames = @($azConnectedMachine.Name)
foreach ($machineName in $machineNames) {
    $extension += Get-AzConnectedMachineExtension -ResourceGroupName $resourceGroupName -MachineName $machineName
}
$extension | Format-Table @{n="Machine";e={$machineName}}, @{n="ResourceGroupName";e={$resourceGroupName}}, @{n="Location";e={$location}}, Name, ProvisioningState, Publisher
#>