#Requires -Version 5.1
<#
    Script-AI generated-Evidence-Collection-DriveMapping.ps1

    Purpose:
    Collects evidence for the TOP-RANKED root cause identified in
    Ranked-Login-issues-Floor6-20260814.md: a drive-mapping/logon script
    failure introduced by Friday's application deployment.

    Evidence collected (read-only, non-destructive):
      - Intune Management Extension logs (where the drive-mapping script runs)
      - A fresh GPResult HTML report (Group Policy processing state)
      - System event log entries for Group Policy (Event ID 1500) and
        NTFS drive-mapping failures (Event ID 98)

    See the accompanying README for full usage details.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # --- Requirement 1: Dry run switch ---
    [switch]$DryRun,

    # --- Requirement 2: only target files older than N days (default 0 = all files) ---
    [ValidateRange(0, 3650)]
    [int]$MinAgeDays = 0,

    # Root folder where evidence copies and logs are stored
    [string]$EvidenceRoot = "C:\DWP-Evidence\Floor6-LoginIssue",

    # Source log locations to pull evidence from
    [string[]]$SourcePaths = @(
        "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
    ),

    # --- Requirement 8: rollback support ---
    [switch]$Rollback,
    [string]$RunId
)

# ---------------------------------------------------------------------------
# SECTION: Script metadata / baseline version
# Used by the -DryRun path to show engineers exactly what version/config
# of the script produced the evidence, before any action is simulated.
# ---------------------------------------------------------------------------
$ScriptVersion = "1.0.0"

# ---------------------------------------------------------------------------
# SECTION: Run identity (idempotency key)
# RunId defaults to the current date so re-running the script on the same
# day reuses the same evidence folder instead of creating duplicates.
# ---------------------------------------------------------------------------
if (-not $RunId) {
    $RunId = Get-Date -Format "yyyyMMdd"
}
$RunFolder    = Join-Path $EvidenceRoot $RunId
$LogFolder    = Join-Path $EvidenceRoot "Logs"
$ManifestPath = Join-Path $RunFolder "manifest.csv"

# ---------------------------------------------------------------------------
# SECTION: Logging
# Every action (copy, skip, error, rollback step) is written to a
# date/timestamped log file so the run is fully auditable.
# ---------------------------------------------------------------------------
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}
$LogFile = Join-Path $LogFolder ("EvidenceCollection_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO","WARN","ERROR","DRYRUN")][string]$Level = "INFO"
    )
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

Write-Log "=== Script-AI generated-Evidence-Collection-DriveMapping.ps1 started ==="
Write-Log ("Version={0} DryRun={1} MinAgeDays={2} EvidenceRoot={3} RunId={4}" -f $ScriptVersion, $DryRun, $MinAgeDays, $EvidenceRoot, $RunId)

# ---------------------------------------------------------------------------
# SECTION: Requirement 1 - Dry run baseline printout
# When -DryRun is used, print the raw baseline version/config first,
# before any simulated actions are logged, so the engineer sees exactly
# what would run.
# ---------------------------------------------------------------------------
if ($DryRun) {
    Write-Log "=== DRY RUN: baseline version info ===" -Level DRYRUN
    Write-Log ("ScriptVersion: {0}" -f $ScriptVersion) -Level DRYRUN
    Write-Log ("Parameters: MinAgeDays={0}, EvidenceRoot={1}, SourcePaths={2}" -f $MinAgeDays, $EvidenceRoot, ($SourcePaths -join "; ")) -Level DRYRUN
}

# ---------------------------------------------------------------------------
# SECTION: Requirement 8/9 - Rollback path (idempotent, non-destructive to source)
# Rollback only removes the evidence COPIES this script made (tracked in
# manifest.csv). It never touches original source logs on the device.
# ---------------------------------------------------------------------------
if ($Rollback) {
    Write-Log "=== ROLLBACK requested for RunId=$RunId ==="
    if (-not (Test-Path $ManifestPath)) {
        Write-Log "No manifest found at $ManifestPath - nothing to roll back." -Level WARN
        return
    }

    $entries = Import-Csv -Path $ManifestPath
    foreach ($entry in $entries) {
        try {
            if (Test-Path $entry.Destination) {
                # -WhatIf/-Confirm honoured via ShouldProcess; -DryRun remains an explicit alias
                if ($DryRun -or -not $PSCmdlet.ShouldProcess($entry.Destination, "Remove evidence copy")) {
                    Write-Log ("[DRYRUN/WHATIF] Would remove {0}" -f $entry.Destination) -Level DRYRUN
                } else {
                    Remove-Item -Path $entry.Destination -Force -ErrorAction Stop
                    Write-Log ("Rolled back (removed) {0}" -f $entry.Destination)
                }
            } else {
                Write-Log ("Already absent, nothing to roll back: {0}" -f $entry.Destination) -Level WARN
            }
        }
        catch {
            # Requirement 4: try/catch per file, log and continue
            Write-Log ("ERROR rolling back {0}: {1}" -f $entry.Destination, $_.Exception.Message) -Level ERROR
        }
    }

    $remainingFiles = @(Get-ChildItem $RunFolder -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "manifest.csv" })
    if (-not $DryRun -and (Test-Path $RunFolder) -and $remainingFiles.Count -eq 0 -and $PSCmdlet.ShouldProcess($RunFolder, "Remove empty run folder")) {
        Remove-Item -Path $ManifestPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $RunFolder -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log "Removed empty run folder $RunFolder"
    }

    Write-Log "=== ROLLBACK complete ==="
    return
}

# ---------------------------------------------------------------------------
# SECTION: Prepare evidence run folder (idempotent - safe to re-run same day)
# ---------------------------------------------------------------------------
if (-not (Test-Path $RunFolder)) {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($RunFolder, "Create evidence run folder")) {
        Write-Log ("[DRYRUN/WHATIF] Would create run folder {0}" -f $RunFolder) -Level DRYRUN
    } else {
        New-Item -Path $RunFolder -ItemType Directory -Force | Out-Null
        Write-Log "Created run folder $RunFolder"
    }
}

# Load existing manifest (if re-running the same day) so we don't duplicate rows
$manifestRows = @()
if (Test-Path $ManifestPath) {
    $manifestRows = @(Import-Csv -Path $ManifestPath)
}

# ---------------------------------------------------------------------------
# SECTION: Summary counters
# ---------------------------------------------------------------------------
$summary = [ordered]@{
    FilesScanned      = 0
    FilesCopied       = 0
    FilesSkippedAge   = 0
    FilesSkippedLocked = 0
    FilesSkippedIdempotent = 0
    Errors            = 0
}

# ---------------------------------------------------------------------------
# SECTION: Requirement 3 - locked file check
# Attempts an exclusive open to detect whether a file is currently locked
# by another process, without modifying it.
# ---------------------------------------------------------------------------
function Test-FileLocked {
    param([string]$Path)
    try {
        $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
        $stream.Close()
        return $false
    }
    catch {
        return $true
    }
}

# ---------------------------------------------------------------------------
# SECTION: Requirement 2/3/4/9 - collect log files from each source path
# ---------------------------------------------------------------------------
foreach ($source in $SourcePaths) {
    if (-not (Test-Path $source)) {
        Write-Log ("Source path not found, skipping: {0}" -f $source) -Level WARN
        continue
    }

    $cutoff = (Get-Date).AddDays(-1 * $MinAgeDays)
    $files = Get-ChildItem -Path $source -File -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $files) {
        $summary.FilesScanned++

        # Requirement 2: age filter
        if ($file.LastWriteTime -gt $cutoff) {
            $summary.FilesSkippedAge++
            Write-Log ("Skipped (newer than {0} day(s)): {1}" -f $MinAgeDays, $file.FullName)
            continue
        }

        # Requirement 3: skip locked files, log and continue
        if (Test-FileLocked -Path $file.FullName) {
            $summary.FilesSkippedLocked++
            Write-Log ("Skipped (file locked): {0}" -f $file.FullName) -Level WARN
            continue
        }

        $destination = Join-Path $RunFolder $file.Name

        # Requirement 9: idempotent - skip if an identical copy already exists
        if ((Test-Path $destination) -and
            (Get-Item $destination).Length -eq $file.Length -and
            (Get-Item $destination).LastWriteTime -eq $file.LastWriteTime) {
            $summary.FilesSkippedIdempotent++
            Write-Log ("Skipped (already collected, unchanged): {0}" -f $file.FullName)
            continue
        }

        # Requirement 4: try/catch per file
        try {
            if ($DryRun -or -not $PSCmdlet.ShouldProcess($destination, "Copy evidence file from $($file.FullName)")) {
                Write-Log ("[DRYRUN/WHATIF] Would copy {0} -> {1}" -f $file.FullName, $destination) -Level DRYRUN
            } else {
                Copy-Item -Path $file.FullName -Destination $destination -Force -ErrorAction Stop
                $summary.FilesCopied++
                Write-Log ("Copied {0} -> {1}" -f $file.FullName, $destination)

                $manifestRows += [pscustomobject]@{
                    Source      = $file.FullName
                    Destination = $destination
                    CollectedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                }
            }
        }
        catch {
            $summary.Errors++
            Write-Log ("ERROR copying {0}: {1}" -f $file.FullName, $_.Exception.Message) -Level ERROR
        }
    }
}

# ---------------------------------------------------------------------------
# SECTION: Additional targeted evidence - GPResult report and event log export
# These supplement the raw log copies with a point-in-time GPO/event snapshot.
# ---------------------------------------------------------------------------
$gpResultPath = Join-Path $RunFolder "gpresult.html"
$eventLogPath = Join-Path $RunFolder "GroupPolicy-NTFS-Events.csv"

try {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($gpResultPath, "Generate GPResult report")) {
        Write-Log ("[DRYRUN/WHATIF] Would generate GPResult report at {0}" -f $gpResultPath) -Level DRYRUN
    } elseif (-not (Test-Path $gpResultPath)) {
        gpresult /h $gpResultPath /f 2>$null
        Write-Log ("Generated GPResult report: {0}" -f $gpResultPath)
    } else {
        Write-Log ("GPResult report already exists for this run, skipping: {0}" -f $gpResultPath)
    }
}
catch {
    $summary.Errors++
    Write-Log ("ERROR generating GPResult report: {0}" -f $_.Exception.Message) -Level ERROR
}

try {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($eventLogPath, "Export Group Policy/NTFS events")) {
        Write-Log ("[DRYRUN/WHATIF] Would export System log events (IDs 1500, 98) to {0}" -f $eventLogPath) -Level DRYRUN
    } elseif (-not (Test-Path $eventLogPath)) {
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1500, 98 } -ErrorAction Stop |
            Select-Object TimeCreated, Id, ProviderName, Message |
            Export-Csv -Path $eventLogPath -NoTypeInformation
        Write-Log ("Exported Group Policy/NTFS events: {0}" -f $eventLogPath)
    } else {
        Write-Log ("Event export already exists for this run, skipping: {0}" -f $eventLogPath)
    }
}
catch {
    $summary.Errors++
    Write-Log ("ERROR exporting event log entries (may be none present): {0}" -f $_.Exception.Message) -Level ERROR
}

# ---------------------------------------------------------------------------
# SECTION: Persist manifest for later rollback (idempotent write)
# ---------------------------------------------------------------------------
if (-not $DryRun -and $manifestRows.Count -gt 0) {
    $manifestRows | Sort-Object Destination -Unique | Export-Csv -Path $ManifestPath -NoTypeInformation
    Write-Log ("Manifest written: {0}" -f $ManifestPath)
}

# ---------------------------------------------------------------------------
# SECTION: Requirement 6 - final summary report
# ---------------------------------------------------------------------------
Write-Log "=== SUMMARY ==="
foreach ($key in $summary.Keys) {
    Write-Log ("{0}: {1}" -f $key, $summary[$key])
}
Write-Log "=== Script-AI generated-Evidence-Collection-DriveMapping.ps1 finished ==="
