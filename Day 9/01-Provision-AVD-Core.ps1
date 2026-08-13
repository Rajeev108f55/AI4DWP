$ErrorActionPreference = 'Stop'

# -----------------------------
# Input variables
# -----------------------------
$SubscriptionId = '8d8da22c-cbf0-4314-bc16-246725646a4f'
$ResourceGroup  = 'dwp-lab-rg'
$Location       = 'centralus'

$HostPoolName   = 'POOL-FIN-01'
$WorkspaceName  = 'FinBridge-Workspace'
$AppGroupName   = 'DAG-POOL-FIN-01'

$VnetName       = 'vnet-fin-avd-01'
$SubnetName     = 'snet-sessionhosts'
$VnetPrefix     = '10.50.0.0/16'
$SubnetPrefix   = '10.50.1.0/24'

$VmName         = 'vm-fin-avd-01'
$VmSize         = 'Standard_B2ms'
$VmImage        = 'MicrosoftWindowsDesktop:windows-11:win11-24h2-avd:latest'
$AdminUser      = 'localavdadmin'
$AdminPassword  = 'Dwp!ChangeThisBeforeUse#2026'
$PublicIpName   = 'pip-fin-avd-01'
$NsgName        = 'nsg-fin-avd-01'

Write-Host 'Setting subscription context...'
az account set --subscription $SubscriptionId

Write-Host 'Installing/updating AVD extension and registering providers...'
az extension add --name desktopvirtualization --upgrade | Out-Null
az provider register --namespace Microsoft.DesktopVirtualization | Out-Null
az provider register --namespace Microsoft.Compute | Out-Null
az provider register --namespace Microsoft.Network | Out-Null

Write-Host 'Creating host pool...'
az desktopvirtualization hostpool create `
  --resource-group $ResourceGroup `
  --name $HostPoolName `
  --location $Location `
  --host-pool-type Pooled `
  --load-balancer-type BreadthFirst `
  --max-session-limit 5 `
  --preferred-app-group-type Desktop `
  --start-vm-on-connect true `
  --custom-rdp-property "targetisaadjoined:i:1;enablerdsaadauth:i:1" | Out-Null

Write-Host 'Creating workspace...'
az desktopvirtualization workspace create `
  --resource-group $ResourceGroup `
  --name $WorkspaceName `
  --location $Location `
  --friendly-name $WorkspaceName | Out-Null

Write-Host 'Creating desktop application group...'
$HostPoolId = az desktopvirtualization hostpool show -g $ResourceGroup -n $HostPoolName --query id -o tsv
az desktopvirtualization applicationgroup create `
  --resource-group $ResourceGroup `
  --name $AppGroupName `
  --location $Location `
  --application-group-type Desktop `
  --host-pool-arm-path $HostPoolId `
  --friendly-name 'POOL-FIN-01 Desktop App Group' | Out-Null

Write-Host 'Linking app group to workspace...'
$AppGroupId = az desktopvirtualization applicationgroup show -g $ResourceGroup -n $AppGroupName --query id -o tsv
az desktopvirtualization workspace update `
  -g $ResourceGroup `
  -n $WorkspaceName `
  --application-group-references $AppGroupId | Out-Null

Write-Host 'Creating network...'
az network vnet create `
  -g $ResourceGroup `
  -n $VnetName `
  --location $Location `
  --address-prefixes $VnetPrefix `
  --subnet-name $SubnetName `
  --subnet-prefixes $SubnetPrefix | Out-Null

Write-Host 'Creating session host VM with Trusted Launch...'
az vm create `
  -g $ResourceGroup `
  -n $VmName `
  --location $Location `
  --image $VmImage `
  --size $VmSize `
  --vnet-name $VnetName `
  --subnet $SubnetName `
  --public-ip-address $PublicIpName `
  --public-ip-sku Standard `
  --nsg $NsgName `
  --nsg-rule RDP `
  --admin-username $AdminUser `
  --admin-password $AdminPassword `
  --security-type TrustedLaunch `
  --enable-secure-boot true `
  --enable-vtpm true `
  --license-type Windows_Client | Out-Null

Write-Host 'Enabling system-assigned identity and AAD login extension...'
az vm identity assign -g $ResourceGroup -n $VmName | Out-Null
az vm extension set `
  --resource-group $ResourceGroup `
  --vm-name $VmName `
  --name AADLoginForWindows `
  --publisher Microsoft.Azure.ActiveDirectory | Out-Null

Write-Host 'Restarting VM to apply identity/extension state...'
az vm restart -g $ResourceGroup -n $VmName | Out-Null

Write-Host 'Core provisioning complete.'
