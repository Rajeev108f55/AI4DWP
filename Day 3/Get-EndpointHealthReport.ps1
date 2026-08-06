<#
.SYNOPSIS
    Endpoint Health Report for DWP (Digital Workplace) engineers.

.DESCRIPTION
    Read-only diagnostic script. Reports:
        1. System uptime
        2. Free disk space
        3. Pending reboot status (registry checks)
        4. Top 5 processes by memory (working set)
        5. Top 5 processes by CPU
        6. Last 5 System event log errors

    STRICTLY READ-ONLY:
    This script only uses "Get-" cmdlets (Get-CimInstance, Get-Process,
    Get-WinEvent, Get-ItemProperty, Test-Path, Get-Item). It does not create,
    modify, delete, or restart anything on the system.

.NOTES
    Tested against Windows PowerShell 5.1.
    Run as a standard user where possible; some sections (e.g. reading the
    System event log) may return incomplete results without elevated rights
    depending on local security policy - see "VERIFY" comments below.
#>

# Requires PowerShell 5.1+ (uses Get-CimInstance / Get-WinEvent, both built in on 5.1)
Set-StrictMode -Version Latest

Write-Host "===== ENDPOINT HEALTH REPORT =====" -ForegroundColor Cyan
Write-Host "Generated: $(Get-Date)" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 1. SYSTEM UPTIME
#    Reads OS boot time via CIM (WMI) and calculates elapsed time since boot.
#    Read-only: Get-CimInstance only queries WMI, no data is changed.
# ---------------------------------------------------------------------------
Write-Host "----- 1. System Uptime -----" -ForegroundColor Yellow
try {
    # VERIFY: Requires the WMI/CIM service to be running; on some locked-down
    # endpoints CIM access may be restricted by policy - confirm before relying on this.
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $lastBoot = $os.LastBootUpTime
    $uptime = (Get-Date) - $lastBoot

    [PSCustomObject]@{
        LastBootTime = $lastBoot
        Uptime       = "{0}d {1}h {2}m {3}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
    } | Format-List
}
catch {
    Write-Warning "Unable to retrieve system uptime: $($_.Exception.Message)"
}
Write-Host ""

# ---------------------------------------------------------------------------
# 2. FREE DISK SPACE
#    Reads logical disk info via CIM for fixed local drives (DriveType=3).
#    Read-only: only reads volume metadata, does not touch file contents.
# ---------------------------------------------------------------------------
Write-Host "----- 2. Free Disk Space -----" -ForegroundColor Yellow
try {
    # VERIFY: DriveType=3 filters to fixed local disks only; change/remove the
    # filter if you also need to report on removable/network drives.
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop

    $disks | ForEach-Object {
        [PSCustomObject]@{
            Drive        = $_.DeviceID
            SizeGB       = [math]::Round($_.Size / 1GB, 2)
            FreeSpaceGB  = [math]::Round($_.FreeSpace / 1GB, 2)
            PercentFree  = if ($_.Size -gt 0) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
        }
    } | Format-Table -AutoSize
}
catch {
    Write-Warning "Unable to retrieve disk space: $($_.Exception.Message)"
}
Write-Host ""

# ---------------------------------------------------------------------------
# 3. REBOOT PENDING CHECK (registry only, read-only via Test-Path/Get-ItemProperty)
#    Checks the standard set of registry locations Windows/WSUS/SCCM use to
#    flag a pending reboot. No registry values are created or changed.
# ---------------------------------------------------------------------------
Write-Host "----- 3. Reboot Pending Status -----" -ForegroundColor Yellow
$rebootPendingReasons = @()

# Component Based Servicing (CBS) reboot flag
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
    $rebootPendingReasons += "Component Based Servicing (CBS)"
}

# Windows Update reboot required flag
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
    $rebootPendingReasons += "Windows Update"
}

# Pending file rename operations (used by many installers, e.g. MSI)
# VERIFY: This value can exist transiently during normal update activity -
# confirm it truly indicates a stuck/pending reboot before acting on it.
try {
    $pfro = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction Stop
    if ($pfro.PendingFileRenameOperations) {
        $rebootPendingReasons += "Pending File Rename Operations"
    }
}
catch {
    # Value not present = no pending rename operations; not a script error.
}

# SCCM Client reboot pending flag (only applies if SCCM client is installed)
# VERIFY: This WMI namespace only exists on endpoints managed by SCCM/MECM.
# Confirm SCCM is in use in your environment before trusting this result.
try {
    $ccmUtil = Get-CimInstance -Namespace "ROOT\ccm\ClientSDK" -ClassName CCM_ClientUtilities -ErrorAction Stop
    if ($ccmUtil -and ($ccmUtil.DetermineIfRebootPending().RebootPending)) {
        $rebootPendingReasons += "SCCM Client"
    }
}
catch {
    # SCCM namespace not present - expected on non-SCCM-managed machines.
}

if ($rebootPendingReasons.Count -gt 0) {
    Write-Host "REBOOT PENDING: Yes" -ForegroundColor Red
    Write-Host ("Reason(s): " + ($rebootPendingReasons -join ", "))
}
else {
    Write-Host "REBOOT PENDING: No" -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------------------------
# 4. TOP 5 PROCESSES BY MEMORY (WORKING SET)
#    Get-Process is read-only; it only reads process info, it does not
#    stop/start/modify any process.
# ---------------------------------------------------------------------------
Write-Host "----- 4. Top 5 Processes by Memory (Working Set) -----" -ForegroundColor Yellow
try {
    # VERIFY: Path is unavailable for some system/elevated processes when the
    # script is run without admin rights; those rows show "Access Denied".
    Get-Process -ErrorAction Stop |
        Sort-Object -Property WS -Descending |
        Select-Object -First 5 -Property Id, ProcessName, @{Name = "WorkingSetMB"; Expression = { [math]::Round($_.WS / 1MB, 2) } }, @{Name = "ExecutablePath"; Expression = { try { $_.Path } catch { "Access Denied" } } } |
        Format-Table -AutoSize -Wrap
}
catch {
    Write-Warning "Unable to retrieve process memory info: $($_.Exception.Message)"
}
Write-Host ""

# ---------------------------------------------------------------------------
# 5. TOP 5 PROCESSES BY CPU
#    Read-only: CPU property is a cumulative counter read from the process
#    object; sorting/displaying it does not affect the process.
# ---------------------------------------------------------------------------
Write-Host "----- 5. Top 5 Processes by CPU -----" -ForegroundColor Yellow
try {
    # VERIFY: CPU is cumulative processor time (seconds) since the process
    # started, not a live "current %" - confirm this meets your reporting need.
    # VERIFY: Path is unavailable for some system/elevated processes when the
    # script is run without admin rights; those rows show "Access Denied".
    Get-Process -ErrorAction Stop |
        Where-Object { $_.CPU } |
        Sort-Object -Property CPU -Descending |
        Select-Object -First 5 -Property Id, ProcessName, @{Name = "CPU_Seconds"; Expression = { [math]::Round($_.CPU, 2) } }, @{Name = "ExecutablePath"; Expression = { try { $_.Path } catch { "Access Denied" } } } |
        Format-Table -AutoSize -Wrap
}
catch {
    Write-Warning "Unable to retrieve process CPU info: $($_.Exception.Message)"
}
Write-Host ""

# ---------------------------------------------------------------------------
# 6. LAST 5 SYSTEM LOG ERRORS
#    Get-WinEvent only reads event log entries; it does not clear or modify
#    the log in any way.
# ---------------------------------------------------------------------------
Write-Host "----- 6. Last 5 System Log Errors -----" -ForegroundColor Yellow
try {
    # VERIFY: Reading the System log may require Administrator or
    # "Event Log Readers" group membership depending on local security policy.
    $errors = Get-WinEvent -FilterHashtable @{ LogName = "System"; Level = 2 } -MaxEvents 5 -ErrorAction Stop
    $errors | Select-Object TimeCreated, Id, ProviderName, Message | Format-List
}
catch [Exception] {
    if ($_.Exception.Message -match "No events were found") {
        Write-Host "No System log errors found." -ForegroundColor Green
    }
    else {
        Write-Warning "Unable to retrieve System log errors: $($_.Exception.Message)"
    }
}
Write-Host ""

Write-Host "===== END OF REPORT =====" -ForegroundColor Cyan
