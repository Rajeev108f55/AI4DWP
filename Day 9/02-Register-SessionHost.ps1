$ErrorActionPreference = 'Stop'

# -----------------------------
# Input variables
# -----------------------------
$ResourceGroup = 'dwp-lab-rg'
$HostPoolName  = 'POOL-FIN-01'
$VmName        = 'vm-fin-avd-01'

Write-Host 'Generating host pool registration token...'
$Expiry = (Get-Date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
az desktopvirtualization hostpool update `
  -g $ResourceGroup `
  -n $HostPoolName `
  --registration-info expiration-time=$Expiry registration-token-operation=Update | Out-Null

$Token = az desktopvirtualization hostpool retrieve-registration-token -g $ResourceGroup -n $HostPoolName --query token -o tsv
if (-not $Token) {
  throw 'Failed to retrieve host pool registration token.'
}

Write-Host 'Downloading current AVD installers inside the VM...'
# Use current Microsoft fwlink endpoints discovered during troubleshooting.
$DownloadScript = @'
$ProgressPreference = "SilentlyContinue"
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2310011" -OutFile "C:\Windows\Temp\agent.msi" -UseBasicParsing
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2311028" -OutFile "C:\Windows\Temp\boot.msi" -UseBasicParsing
Get-Item C:\Windows\Temp\agent.msi,C:\Windows\Temp\boot.msi | Select-Object FullName,Length
'@
az vm run-command invoke -g $ResourceGroup -n $VmName --command-id RunPowerShellScript --scripts $DownloadScript | Out-Null

Write-Host 'Installing AVD agent with registration token...'
$InstallAgentScript = "cmd /c msiexec /i C:\Windows\Temp\agent.msi /quiet /qn /norestart REGISTRATIONTOKEN=$Token /l*v C:\Windows\Temp\agent-install.log"
az vm run-command invoke -g $ResourceGroup -n $VmName --command-id RunPowerShellScript --scripts $InstallAgentScript | Out-Null

Write-Host 'Installing AVD bootloader...'
$InstallBootScript = "cmd /c msiexec /i C:\Windows\Temp\boot.msi /quiet /qn /norestart /l*v C:\Windows\Temp\boot-install.log"
az vm run-command invoke -g $ResourceGroup -n $VmName --command-id RunPowerShellScript --scripts $InstallBootScript | Out-Null

Write-Host 'Checking agent services...'
$ServiceCheck = 'Get-Service -Name RdAgent,RDAgentBootLoader -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType | Format-Table -AutoSize | Out-String'
az vm run-command invoke -g $ResourceGroup -n $VmName --command-id RunPowerShellScript --scripts $ServiceCheck --query "value[0].message" -o tsv

Write-Host 'Session host registration script complete.'
