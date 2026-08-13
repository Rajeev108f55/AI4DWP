$ErrorActionPreference = 'Stop'

# -----------------------------
# Input variables
# -----------------------------
$SubscriptionId = '8d8da22c-cbf0-4314-bc16-246725646a4f'
$ResourceGroup  = 'dwp-lab-rg'
$HostPoolName   = 'POOL-FIN-01'
$WorkspaceName  = 'FinBridge-Workspace'
$VmName         = 'vm-fin-avd-01'
$UserUpn        = 'p17@zippyops.in'

az account set --subscription $SubscriptionId

Write-Host 'Host pool configuration:'
az desktopvirtualization hostpool show -g $ResourceGroup -n $HostPoolName `
  --query "{name:name,hostPoolType:hostPoolType,loadBalancerType:loadBalancerType,maxSessionLimit:maxSessionLimit}" -o table

Write-Host 'Workspace linkage:'
az desktopvirtualization workspace show -g $ResourceGroup -n $WorkspaceName `
  --query "{name:name,applicationGroupReferences:applicationGroupReferences}" -o json

Write-Host 'Session host VM security and identity:'
az vm show -g $ResourceGroup -n $VmName `
  --query "{name:name,size:hardwareProfile.vmSize,securityType:securityProfile.securityType,secureBoot:securityProfile.uefiSettings.secureBootEnabled,vTPM:securityProfile.uefiSettings.vTpmEnabled,identityType:identity.type}" -o table

Write-Host 'Entra join state from dsregcmd:'
az vm run-command invoke -g $ResourceGroup -n $VmName --command-id RunPowerShellScript `
  --scripts "(dsregcmd /status) | Select-String 'AzureAdJoined|EnterpriseJoined|DomainJoined|Virtual Desktop' | ForEach-Object { `$_.ToString() }" `
  --query "value[0].message" -o tsv

Write-Host 'Live session host status from ARM:'
$SessionHostUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName/sessionHosts?api-version=2024-04-03"
az rest --method get --url $SessionHostUrl `
  --query "value[].{name:name,status:properties.status,lastHeartBeat:properties.lastHeartBeat,allowNewSession:properties.allowNewSession,sessions:properties.sessions,agentVersion:properties.agentVersion}" -o table

Write-Host 'User access role verification:'
az role assignment list --assignee $UserUpn --all `
  --query "[?roleDefinitionName=='Virtual Machine User Login' || roleDefinitionName=='Desktop Virtualization User'].{role:roleDefinitionName,scope:scope}" -o table

Write-Host 'Verification complete.'
