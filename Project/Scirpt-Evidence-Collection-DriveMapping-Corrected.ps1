#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$DryRun,
    [ValidateRange(0, 3650)]
    [int]$MinAgeDays = 0,
    [string]$EvidenceRoot = "C:\DWP-Evidence\Floor6-LoginIssue",
    [string[]]$SourcePaths = @(
        "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
    ),
    [switch]$Rollback,
    [string]$RunId
)

$scriptVersion = "2.0.0"
if (-not $RunId) {
    $RunId = Get-Date -Format "yyyyMMdd"
}

$runFolder = Join-Path $EvidenceRoot $RunId
$logFolder = Join-Path $EvidenceRoot "Logs"
$manifestPath = Join-Path $runFolder "manifest.csv"
$logFile = Join-Path $logFolder ("EvidenceCollection_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DRYRUN")]
        [string]$Level = "INFO"
    )

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    if (Test-Path $logFolder) {
        Add-Content -Path $logFile -Value $line
    }
    Write-Host $line
}

function Test-FileLocked {
    param([Parameter(Mandatory)][string]$Path)

    try {
        $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
        $stream.Dispose()
        return $false
    }
    catch {
        return $true
    }
}

$summary = [ordered]@{
    FilesScanned = 0
    FilesCopied = 0
    FilesSkippedAge = 0
    FilesSkippedLocked = 0
    FilesSkippedIdempotent = 0
    Errors = 0
}

if (-not (Test-Path $logFolder)) {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($logFolder, "Create evidence log folder")) {
        Write-Log ("[DRYRUN/WHATIF] Would create log folder {0}" -f $logFolder) -Level DRYRUN
    }
    else {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }
}

Write-Log "=== Evidence-Collection-DriveMapping-Corrected.ps1 started ==="
Write-Log ("Version={0} DryRun={1} MinAgeDays={2} EvidenceRoot={3} RunId={4}" -f $scriptVersion, $DryRun, $MinAgeDays, $EvidenceRoot, $RunId)

if ($DryRun) {
    Write-Log "=== DRY RUN: baseline version info ===" -Level DRYRUN
    Write-Log ("ScriptVersion: {0}" -f $scriptVersion) -Level DRYRUN
    Write-Log ("Parameters: MinAgeDays={0}, EvidenceRoot={1}, SourcePaths={2}" -f $MinAgeDays, $EvidenceRoot, ($SourcePaths -join "; ")) -Level DRYRUN
}

if ($Rollback) {
    Write-Log "=== ROLLBACK requested for RunId=$RunId ==="
    if (-not (Test-Path $manifestPath)) {
        Write-Log ("No manifest found at {0} - nothing to roll back." -f $manifestPath) -Level WARN
        return
    }

    foreach ($entry in (Import-Csv -Path $manifestPath)) {
        try {
            if (Test-Path $entry.Destination) {
                if ($DryRun -or -not $PSCmdlet.ShouldProcess($entry.Destination, "Remove evidence copy")) {
                    Write-Log ("[DRYRUN/WHATIF] Would remove {0}" -f $entry.Destination) -Level DRYRUN
                }
                else {
                    Remove-Item -Path $entry.Destination -Force -ErrorAction Stop
                    Write-Log ("Rolled back (removed) {0}" -f $entry.Destination)
                }
            }
            else {
                Write-Log ("Already absent, nothing to roll back: {0}" -f $entry.Destination) -Level WARN
            }
        }
        catch {
            Write-Log ("ERROR rolling back {0}: {1}" -f $entry.Destination, $_.Exception.Message) -Level ERROR
        }
    }

    $remainingFiles = @(Get-ChildItem $runFolder -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "manifest.csv" })
    if (-not $DryRun -and (Test-Path $runFolder) -and $remainingFiles.Count -eq 0 -and $PSCmdlet.ShouldProcess($runFolder, "Remove empty evidence run folder")) {
        Remove-Item -Path $manifestPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $runFolder -Force -Recurse -ErrorAction SilentlyContinue
        Write-Log ("Removed empty run folder {0}" -f $runFolder)
    }

    Write-Log "=== ROLLBACK complete ==="
    return
}

if (-not (Test-Path $runFolder)) {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($runFolder, "Create evidence run folder")) {
        Write-Log ("[DRYRUN/WHATIF] Would create run folder {0}" -f $runFolder) -Level DRYRUN
    }
    else {
        New-Item -Path $runFolder -ItemType Directory -Force | Out-Null
        Write-Log ("Created run folder {0}" -f $runFolder)
    }
}

$manifestRows = @()
if (Test-Path $manifestPath) {
    $manifestRows = @(Import-Csv -Path $manifestPath)
}

foreach ($source in $SourcePaths) {
    if (-not (Test-Path $source)) {
        Write-Log ("Source path not found, skipping: {0}" -f $source) -Level WARN
        continue
    }

    $cutoff = (Get-Date).AddDays(-1 * $MinAgeDays)
    foreach ($file in (Get-ChildItem -Path $source -File -Recurse -ErrorAction SilentlyContinue)) {
        $summary.FilesScanned++

        if ($file.LastWriteTime -gt $cutoff) {
            $summary.FilesSkippedAge++
            Write-Log ("Skipped (newer than {0} day(s)): {1}" -f $MinAgeDays, $file.FullName)
            continue
        }

        if (Test-FileLocked -Path $file.FullName) {
            $summary.FilesSkippedLocked++
            Write-Log ("Skipped (file locked): {0}" -f $file.FullName) -Level WARN
            continue
        }

        $destination = Join-Path $runFolder $file.Name
        $existing = if (Test-Path $destination) { Get-Item $destination } else { $null }
        if ($existing -and $existing.Length -eq $file.Length -and $existing.LastWriteTime -eq $file.LastWriteTime) {
            $summary.FilesSkippedIdempotent++
            Write-Log ("Skipped (already collected, unchanged): {0}" -f $file.FullName)
            continue
        }

        try {
            if ($DryRun -or -not $PSCmdlet.ShouldProcess($destination, "Copy evidence file from $($file.FullName)")) {
                Write-Log ("[DRYRUN/WHATIF] Would copy {0} -> {1}" -f $file.FullName, $destination) -Level DRYRUN
            }
            else {
                Copy-Item -Path $file.FullName -Destination $destination -Force -ErrorAction Stop
                $summary.FilesCopied++
                $manifestRows += [pscustomobject]@{
                    Source = $file.FullName
                    Destination = $destination
                    CollectedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                Write-Log ("Copied {0} -> {1}" -f $file.FullName, $destination)
            }
        }
        catch {
            $summary.Errors++
            Write-Log ("ERROR copying {0}: {1}" -f $file.FullName, $_.Exception.Message) -Level ERROR
        }
    }
}

$gpResultPath = Join-Path $runFolder "gpresult.html"
try {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($gpResultPath, "Generate GPResult report")) {
        Write-Log ("[DRYRUN/WHATIF] Would generate GPResult report at {0}" -f $gpResultPath) -Level DRYRUN
    }
    elseif (-not (Test-Path $gpResultPath)) {
        gpresult /h $gpResultPath /f 2>$null
        Write-Log ("Generated GPResult report: {0}" -f $gpResultPath)
    }
}
catch {
    $summary.Errors++
    Write-Log ("ERROR generating GPResult report: {0}" -f $_.Exception.Message) -Level ERROR
}

$eventLogPath = Join-Path $runFolder "GroupPolicy-NTFS-Events.csv"
try {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($eventLogPath, "Export Group Policy/NTFS events")) {
        Write-Log ("[DRYRUN/WHATIF] Would export System log events (IDs 1500, 98) to {0}" -f $eventLogPath) -Level DRYRUN
    }
    elseif (-not (Test-Path $eventLogPath)) {
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1500, 98 } -ErrorAction Stop |
            Select-Object TimeCreated, Id, ProviderName, Message |
            Export-Csv -Path $eventLogPath -NoTypeInformation
        Write-Log ("Exported Group Policy/NTFS events: {0}" -f $eventLogPath)
    }
}
catch {
    $summary.Errors++
    Write-Log ("ERROR exporting event log entries: {0}" -f $_.Exception.Message) -Level ERROR
}

if ($manifestRows.Count -gt 0) {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($manifestPath, "Write evidence manifest")) {
        Write-Log ("[DRYRUN/WHATIF] Would write manifest: {0}" -f $manifestPath) -Level DRYRUN
    }
    else {
        $manifestRows | Sort-Object Destination -Unique | Export-Csv -Path $manifestPath -NoTypeInformation
        Write-Log ("Manifest written: {0}" -f $manifestPath)
    }
}

Write-Log "=== SUMMARY ==="
foreach ($key in $summary.Keys) {
    Write-Log ("{0}: {1}" -f $key, $summary[$key])
}
Write-Log "=== Evidence-Collection-DriveMapping-Corrected.ps1 finished ==="