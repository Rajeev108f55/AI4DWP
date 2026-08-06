<#
.SYNOPSIS
    Quick endpoint health snapshot: computer info, free disk space, top
    memory-consuming processes, recent System log errors, and stale user
    profiles.

.DESCRIPTION
    Read-only diagnostic script. Queries local system information and prints
    a summary to the console. Makes no changes to the system.

.NOTES
    Author:  (inherited script - original author unknown)
    Run with: .\Inherited.PS1
    Requires: Windows PowerShell 5.1+. No parameters or elevation required
    for the queries below (read-only).

    This refactor only renames variables and adds comments for readability -
    the script's behavior/output is unchanged from the original version,
    including any pre-existing logic quirks.
#>

# Get general computer system info (name, total physical memory, etc.) via CIM/WMI
$computerSystem = Get-CimInstance Win32_ComputerSystem

# Get the amount of free space (in bytes) on the C: drive
$freeDiskSpaceBytes = Get-PSDrive C | Select-Object -ExpandProperty Free

# Get all running processes, sort by working set (memory) descending, keep the top 5
$topProcessesByMemory = Get-Process | Sort-Object WS -Descending | Select-Object -First 5

# Get the 10 most recent System log events, then keep only the Error-level (Level 2) ones
$recentSystemErrors = Get-WinEvent -LogName System -MaxEvents 10 | Where-Object {$_.Level -eq 2}

# Get all local user profiles, excluding special/system profiles, that haven't been used in 90+ days
$staleUserProfiles = Get-CimInstance Win32_UserProfile | Where-Object {
     -not $_.Special -and $_.LastUseTime -lt (Get-Date).AddDays(-90)}

# Print the computer name and total physical memory (raw bytes)
Write-Host $computerSystem.Name $computerSystem.TotalPhysicalMemory

# Print the free disk space converted to GB, rounded to 2 decimal places
Write-Host ([math]::Round($freeDiskSpaceBytes/1GB,2)) 'GB free'

# Print each of the top 5 processes' name and working set (memory, in bytes)
$topProcessesByMemory | ForEach-Object { Write-Host $_.Name $_.WS }

# Print the timestamp and message of each recent System log error found above
$recentSystemErrors | ForEach-Object { Write-Host $_.TimeCreated $_.Message }

# If any stale user profiles were found, print how many
if ($staleUserProfiles.Count -gt 0) { Write-Host 'Stale profiles:' $staleUserProfiles.Count }