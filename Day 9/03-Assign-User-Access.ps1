$ErrorActionPreference = 'Stop'

# -----------------------------
# Input variables
# -----------------------------
$ResourceGroup = 'dwp-lab-rg'
$VmName        = 'vm-fin-avd-01'
$AppGroupName  = 'DAG-POOL-FIN-01'
$UserUpn       = 'p17@zippyops.in'

Write-Host 'Resolving resource scopes...'
$VmId = az vm show -g $ResourceGroup -n $VmName --query id -o tsv
$AppGroupId = az desktopvirtualization applicationgroup show -g $ResourceGroup -n $AppGroupName --query id -o tsv

Write-Host 'Assigning Virtual Machine User Login on VM scope...'
az role assignment create --assignee $UserUpn --role 'Virtual Machine User Login' --scope $VmId | Out-Null

Write-Host 'Assigning Desktop Virtualization User on app group scope...'
az role assignment create --assignee $UserUpn --role 'Desktop Virtualization User' --scope $AppGroupId | Out-Null

Write-Host 'Verifying access role assignments...'
az role assignment list `
  --assignee $UserUpn `
  --all `
  --query "[?roleDefinitionName=='Virtual Machine User Login' || roleDefinitionName=='Desktop Virtualization User'].{role:roleDefinitionName,scope:scope}" `
  -o table
