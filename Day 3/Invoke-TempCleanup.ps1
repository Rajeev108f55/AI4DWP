<#
.SYNOPSIS
    Safely cleans up temp files on a Windows endpoint, with dry-run preview
    and rollback support.

.DESCRIPTION
    Instead of permanently deleting files, this script MOVES matching temp
    files into a quarantine folder and records every move in a manifest.
    This is what makes rollback possible: nothing is destroyed, it is only
    relocated. See README.md in this folder for full parameter details.

.PARAMETER Path
    One or more folders to clean. Defaults to the current user's temp folder
    and the Windows system temp folder.

.PARAMETER OlderThanDays
    Only files whose LastWriteTime is older than this many days are targeted.
    Default is 0 (i.e. all files, regardless of age).

.PARAMETER Recurse
    Also scan subfolders of each path in -Path. Default is off (top-level only)
    to reduce the chance of touching an application's active subfolder.

.PARAMETER DryRun
    Preview mode. Lists every file that would be moved/restored, but makes
    no changes to the file system (still writes to the log file).

.PARAMETER Rollback
    Restores files from a previous cleanup run back to their original paths.

.PARAMETER RunId
    Identifies which cleanup run to roll back (folder name under
    -QuarantineRoot). If omitted, the most recent run is used.

.PARAMETER QuarantineRoot
    Where moved files are held so they can be rolled back later.

.PARAMETER LogRoot
    Where date/time-stamped log files are written.

.EXAMPLE
    .\Invoke-TempCleanup.ps1 -DryRun
    .\Invoke-TempCleanup.ps1 -OlderThanDays 7
    .\Invoke-TempCleanup.ps1 -Rollback
    .\Invoke-TempCleanup.ps1 -Rollback -RunId 20260805_101500
#>

[CmdletBinding()]
param(
    [string[]]$Path = @($env:TEMP, (Join-Path $env:SystemRoot 'Temp')),

    [ValidateRange(0, [int]::MaxValue)]
    [int]$OlderThanDays = 0,

    [switch]$Recurse,

    [switch]$DryRun,

    [switch]$Rollback,

    [string]$RunId,

    [string]$QuarantineRoot = (Join-Path $env:LOCALAPPDATA 'TempCleanup\Quarantine'),

    [string]$LogRoot = (Join-Path $env:LOCALAPPDATA 'TempCleanup\Logs')
)

# ---------------------------------------------------------------------------
# SETUP: build a unique run ID and a date/timestamped log file for this run.
# The log folder is always created (this is the tool's own audit trail, not
# a change to the endpoint being cleaned).
# ---------------------------------------------------------------------------
$script:RunTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if (-not (Test-Path $LogRoot)) { New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null }
$script:LogFile = Join-Path $LogRoot "TempCleanup_$($script:RunTimestamp).log"

# ---------------------------------------------------------------------------
# LOGGING HELPER: writes every action to both the console and the log file.
# ---------------------------------------------------------------------------
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $script:LogFile -Value $line
    switch ($Level) {
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
        default { Write-Host $line }
    }
}

# ---------------------------------------------------------------------------
# LOCK CHECK: attempts an exclusive open on the file. If that fails, the file
# is currently in use by another process and must be skipped, not force-closed.
# ---------------------------------------------------------------------------
function Test-FileLocked {
    param([Parameter(Mandatory)][string]$FilePath)
    try {
        $stream = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'None')
        $stream.Close()
        return $false
    }
    catch {
        return $true
    }
}

# ---------------------------------------------------------------------------
# ROLLBACK: restores files from a quarantine run's manifest back to their
# original location. Skips (does not overwrite) if the original path already
# exists or the quarantined copy is already gone - this makes rollback safe
# to run more than once (idempotent).
# ---------------------------------------------------------------------------
function Invoke-Rollback {
    param(
        [string]$QuarantineRoot,
        [string]$RunId,
        [switch]$DryRun
    )

    if (-not (Test-Path $QuarantineRoot)) {
        Write-Log -Level ERROR -Message "Quarantine root not found: $QuarantineRoot"
        return
    }

    if (-not $RunId) {
        $latest = Get-ChildItem -Path $QuarantineRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if (-not $latest) {
            Write-Log -Level ERROR -Message "No previous cleanup runs found under $QuarantineRoot"
            return
        }
        $RunId = $latest.Name
    }

    $manifestPath = Join-Path (Join-Path $QuarantineRoot $RunId) 'manifest.csv'
    if (-not (Test-Path $manifestPath)) {
        Write-Log -Level ERROR -Message "Manifest not found for run '$RunId': $manifestPath"
        return
    }

    Write-Log -Message "Starting rollback for run '$RunId' (DryRun=$($DryRun.IsPresent))"
    $restored = 0; $skipped = 0; $errors = 0

    foreach ($entry in (Import-Csv -Path $manifestPath)) {
        try {
            if (-not (Test-Path $entry.QuarantinePath)) {
                Write-Log -Level WARN -Message "SKIPPED (already restored / missing from quarantine): $($entry.OriginalPath)"
                $skipped++
                continue
            }
            if (Test-Path $entry.OriginalPath) {
                Write-Log -Level WARN -Message "SKIPPED (original path already exists, not overwriting): $($entry.OriginalPath)"
                $skipped++
                continue
            }

            if ($DryRun) {
                Write-Log -Message "[DRY RUN] Would restore: $($entry.OriginalPath)"
                $restored++
                continue
            }

            $originalDir = Split-Path $entry.OriginalPath -Parent
            if (-not (Test-Path $originalDir)) { New-Item -ItemType Directory -Path $originalDir -Force | Out-Null }

            Move-Item -Path $entry.QuarantinePath -Destination $entry.OriginalPath -Force -ErrorAction Stop
            Write-Log -Message "RESTORED: $($entry.OriginalPath)"
            $restored++
        }
        catch {
            $errors++
            Write-Log -Level ERROR -Message "ERROR restoring $($entry.OriginalPath): $($_.Exception.Message)"
        }
    }

    Write-Log -Message "Rollback complete for run '$RunId'. Restored=$restored Skipped=$skipped Errors=$errors"
    Write-Host ""
    Write-Host "===== ROLLBACK SUMMARY (Run: $RunId) =====" -ForegroundColor Cyan
    [PSCustomObject]@{ Restored = $restored; Skipped = $skipped; Errors = $errors } | Format-List
}

# ---------------------------------------------------------------------------
# MAIN: rollback mode short-circuits the whole script; otherwise run cleanup.
# ---------------------------------------------------------------------------
if ($Rollback) {
    Invoke-Rollback -QuarantineRoot $QuarantineRoot -RunId $RunId -DryRun:$DryRun
    return
}

Write-Log -Message "Starting temp cleanup run '$($script:RunTimestamp)' (DryRun=$($DryRun.IsPresent), OlderThanDays=$OlderThanDays, Recurse=$($Recurse.IsPresent))"

# VERIFY: default -Path targets the current user's temp folder and the
# Windows system temp folder - confirm these are the correct locations for
# your environment before running live (non-DryRun).
Write-Log -Message "Target paths: $($Path -join ', ')"

$runQuarantineDir = Join-Path $QuarantineRoot $script:RunTimestamp
$manifestPath = Join-Path $runQuarantineDir 'manifest.csv'

$stats = @{ Scanned = 0; Moved = 0; SkippedLocked = 0; Errors = 0; BytesFreed = 0 }

# ---------------------------------------------------------------------------
# SCAN + PROCESS: enumerate candidate files per target path, filter by age,
# then handle each file individually so one bad file cannot stop the run.
# ---------------------------------------------------------------------------
foreach ($targetPath in $Path) {
    if (-not (Test-Path $targetPath)) {
        Write-Log -Level WARN -Message "SKIPPED (path not found): $targetPath"
        continue
    }

    $cutoff = (Get-Date).AddDays(-$OlderThanDays)
    $files = Get-ChildItem -Path $targetPath -File -Recurse:$Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -le $cutoff }

    foreach ($file in $files) {
        $stats.Scanned++
        try {
            if (Test-FileLocked -FilePath $file.FullName) {
                $stats.SkippedLocked++
                Write-Log -Level WARN -Message "SKIPPED (locked/in use): $($file.FullName)"
                continue
            }

            if ($DryRun) {
                Write-Log -Message "[DRY RUN] Would move: $($file.FullName) ($([math]::Round($file.Length / 1KB, 1)) KB, LastWriteTime $($file.LastWriteTime))"
                $stats.Moved++
                $stats.BytesFreed += $file.Length
                continue
            }

            # Mirror the original path under the quarantine folder (colons/backslashes
            # replaced) so files with identical names from different folders don't collide.
            $safeRelativeName = ($file.FullName -replace '[:\\]', '_')
            $destination = Join-Path $runQuarantineDir $safeRelativeName
            $destinationDir = Split-Path $destination -Parent
            if (-not (Test-Path $destinationDir)) { New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null }

            Move-Item -Path $file.FullName -Destination $destination -Force -ErrorAction Stop

            [PSCustomObject]@{
                OriginalPath   = $file.FullName
                QuarantinePath = $destination
                SizeBytes      = $file.Length
                LastWriteTime  = $file.LastWriteTime
                MovedUtc       = (Get-Date).ToUniversalTime().ToString('o')
            } | Export-Csv -Path $manifestPath -Append -NoTypeInformation

            $stats.Moved++
            $stats.BytesFreed += $file.Length
            Write-Log -Message "MOVED: $($file.FullName) -> $destination"
        }
        catch {
            # Per-file error handling: log and continue, never abort the whole run.
            $stats.Errors++
            Write-Log -Level ERROR -Message "ERROR processing $($file.FullName): $($_.Exception.Message)"
        }
    }
}

# ---------------------------------------------------------------------------
# SUMMARY: totals for this run, plus where to find the log/manifest for
# rollback later.
# ---------------------------------------------------------------------------
Write-Log -Message "Run complete. Scanned=$($stats.Scanned) Moved=$($stats.Moved) SkippedLocked=$($stats.SkippedLocked) Errors=$($stats.Errors) BytesFreed=$($stats.BytesFreed)"

Write-Host ""
Write-Host "===== CLEANUP SUMMARY (Run: $($script:RunTimestamp)) =====" -ForegroundColor Cyan
[PSCustomObject]@{
    Mode          = if ($DryRun) { 'DRY RUN' } else { 'LIVE' }
    FilesScanned  = $stats.Scanned
    FilesMoved    = $stats.Moved
    SkippedLocked = $stats.SkippedLocked
    Errors        = $stats.Errors
    SpaceFreedMB  = [math]::Round($stats.BytesFreed / 1MB, 2)
    LogFile       = $script:LogFile
    ManifestFile  = if ($DryRun) { 'N/A (dry run, nothing moved)' } else { $manifestPath }
} | Format-List
