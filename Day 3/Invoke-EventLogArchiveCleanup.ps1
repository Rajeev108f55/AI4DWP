<#
.SYNOPSIS
    Archives and clears Windows Event Logs, with dry-run preview and a
    best-effort rollback mechanism.

.DESCRIPTION
    For each target log:
      1. Counts records older than -OlderThanDays.
      2. Exports ONLY those old records to a .evtx archive file (retained copy).
      3. Takes a full pre-clear backup of the ENTIRE log, then clears it.

    IMPORTANT / VERIFY BEFORE RUNNING LIVE:
    Windows Event Log has no API to delete only old records from a live log -
    clearing (wevtutil cl) always wipes the WHOLE log. This script cannot
    change that OS limitation. To make this safe:
      - It refuses to clear a log if there are zero records older than the
        cutoff (nothing to justify a full clear).
      - It always takes a full backup (/bu:) of the entire log immediately
        before clearing, so every record - old and new - is recoverable
        as a file, even though it cannot be re-injected into the live log
        (see the Rollback section below and README.md).
      - Clearing the Security log requires the "Manage auditing and security
        log" user right and is a significant audit/compliance action - verify
        you are authorized before including it in -LogName.

.PARAMETER LogName
    One or more event log names to process. Default: Application, System.

.PARAMETER OlderThanDays
    Only records older than this many days count toward the archive and
    justify a clear. Default is 3.

.PARAMETER DryRun
    Preview only. Reports the count of old records (and total records that
    would actually be wiped) per log. No files written, no logs cleared.

.PARAMETER Rollback
    Switches to rollback mode: makes a previously cleared log's backup file
    available for viewing again (see limitation note above).

.PARAMETER RollbackDate
    Date (yyyyMMdd) of the backup to roll back, per log. Defaults to the
    most recent backup found for that log.

.PARAMETER Force
    Skips the interactive "type YES to continue" confirmation prompt that
    otherwise appears before a live (non-DryRun) clear operation.

.PARAMETER ArchiveRoot
    Folder where old-record-only .evtx archives are written.

.PARAMETER BackupRoot
    Folder where full pre-clear .evtx backups (used for rollback) are written.

.PARAMETER LogRoot
    Folder where this script's own timestamped run logs are written.

.EXAMPLE
    .\Invoke-EventLogArchiveCleanup.ps1 -DryRun
    .\Invoke-EventLogArchiveCleanup.ps1 -OlderThanDays 7 -Force
    .\Invoke-EventLogArchiveCleanup.ps1 -Rollback -LogName System
    .\Invoke-EventLogArchiveCleanup.ps1 -Rollback -LogName System -RollbackDate 20260805
#>

[CmdletBinding()]
param(
    [string[]]$LogName = @('Application', 'System'),

    [ValidateRange(0, [int]::MaxValue)]
    [int]$OlderThanDays = 3,

    [switch]$DryRun,

    [switch]$Rollback,

    [string]$RollbackDate,

    [switch]$Force,

    [string]$ArchiveRoot = (Join-Path $env:LOCALAPPDATA 'EventLogArchive\Archives'),

    [string]$BackupRoot = (Join-Path $env:LOCALAPPDATA 'EventLogArchive\PreClearBackups'),

    [string]$LogRoot = (Join-Path $env:LOCALAPPDATA 'EventLogArchive\Logs')
)

# ---------------------------------------------------------------------------
# SETUP: date/timestamped log file for this run's own audit trail.
# ---------------------------------------------------------------------------
$script:RunTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:Today = Get-Date -Format 'yyyyMMdd'
if (-not (Test-Path $LogRoot)) { New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null }
$script:LogFile = Join-Path $LogRoot "EventLogCleanup_$($script:RunTimestamp).log"

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
# ELEVATION CHECK: clearing event logs requires an elevated (Administrator)
# session; this is a read-only check, it does not elevate anything itself.
# ---------------------------------------------------------------------------
function Test-IsElevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------------------
# ARCHIVE + CLEAR (per log): exports old records only (archive), then takes
# a full pre-clear backup and clears the log. Every step is try/catch'd so a
# failure on one log is recorded and does not stop processing of the others.
# ---------------------------------------------------------------------------
function Invoke-LogArchiveAndClear {
    param(
        [string]$LogName,
        [datetime]$Cutoff,
        [string]$ArchiveRoot,
        [string]$BackupRoot,
        [switch]$DryRun
    )

    $safeName = ($LogName -replace '[\\/:]', '_')
    $archivePath = Join-Path $ArchiveRoot "$($safeName)_$($script:Today).evtx"
    $backupPath = Join-Path $BackupRoot "$($safeName)_$($script:Today).evtx"

    $result = [PSCustomObject]@{
        LogName        = $LogName
        Status         = 'Unknown'
        OldRecordCount = 0
        TotalBefore    = 0
        ArchivePath    = $null
        BackupPath     = $null
        Detail         = $null
    }

    try {
        # VERIFY: clearing the Security log requires the "Manage auditing and
        # security log" right and is a significant audit/compliance action.
        if ($LogName -eq 'Security') {
            Write-Log -Level WARN -Message "Security log targeted - confirm you are authorized before proceeding."
        }

        $logInfo = Get-WinEvent -ListLog $LogName -ErrorAction Stop
        $result.TotalBefore = $logInfo.RecordCount

        # Count records older than cutoff. Get-WinEvent throws a terminating
        # error when nothing matches - that case means zero, not a failure.
        $oldCount = 0
        try {
            $oldCount = (Get-WinEvent -FilterHashtable @{ LogName = $LogName; EndTime = $Cutoff } -ErrorAction Stop |
                Measure-Object).Count
        }
        catch {
            if ($_.Exception.Message -notmatch 'No events were found') { throw }
        }
        $result.OldRecordCount = $oldCount

        if ($DryRun) {
            $result.Status = 'DryRunPreview'
            $result.Detail = "Would archive $oldCount record(s) older than $($Cutoff.ToString('u')); " +
                "note a clear would wipe the FULL log ($($result.TotalBefore) total record(s))."
            return $result
        }

        # IDEMPOTENCY: if today's archive already exists for this log, this
        # log has already been processed today - skip it entirely.
        if (Test-Path $archivePath) {
            $result.Status = 'SkippedIdempotent'
            $result.Detail = "Archive for today already exists: $archivePath"
            return $result
        }

        if ($oldCount -eq 0) {
            $result.Status = 'SkippedNoOldRecords'
            $result.Detail = "No records older than cutoff; log left untouched."
            return $result
        }

        # Export ONLY the old records, in native .evtx format, as the archive copy.
        # VERIFY: this shells out to wevtutil.exe - confirm it's available/unblocked
        # on this endpoint (it ships with Windows by default).
        $cutoffUtc = $Cutoff.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        $xpath = "*[System[TimeCreated[@SystemTime<='$cutoffUtc']]]"
        & wevtutil.exe epl $LogName $archivePath "/q:$xpath" /ow:true
        if ($LASTEXITCODE -ne 0) { throw "wevtutil epl failed with exit code $LASTEXITCODE" }

        # Verify the archive is actually readable before doing anything destructive.
        Get-WinEvent -Path $archivePath -MaxEvents 1 -ErrorAction Stop | Out-Null

        # VERIFY: wevtutil cl clears the ENTIRE log (old and new records alike) -
        # Windows has no selective-delete option. /bu backs up every record to
        # $backupPath immediately before the clear, for rollback purposes.
        & wevtutil.exe cl $LogName "/bu:$backupPath"
        if ($LASTEXITCODE -ne 0) { throw "wevtutil cl failed with exit code $LASTEXITCODE" }

        $result.Status = 'ArchivedAndCleared'
        $result.ArchivePath = $archivePath
        $result.BackupPath = $backupPath
        $result.Detail = "Archived $oldCount old record(s); cleared full log ($($result.TotalBefore) total record(s))."
        Write-Log -Message "$LogName -> $($result.Detail) Archive=$archivePath Backup=$backupPath"
    }
    catch {
        $result.Status = 'Error'
        $result.Detail = $_.Exception.Message
        Write-Log -Level ERROR -Message "$LogName -> ERROR: $($_.Exception.Message)"
    }

    return $result
}

# ---------------------------------------------------------------------------
# ROLLBACK (per log): Windows cannot re-inject historical events back into a
# live log channel, so "rollback" here restores READ ACCESS to every record
# that was cleared, by copying the full pre-clear backup into a Restored
# folder. It does not repopulate the live event log - see README.md.
# ---------------------------------------------------------------------------
function Invoke-LogRollback {
    param(
        [string]$LogName,
        [string]$RollbackDate,
        [string]$BackupRoot,
        [switch]$DryRun
    )

    $safeName = ($LogName -replace '[\\/:]', '_')

    try {
        if ($RollbackDate) {
            $backupPath = Join-Path $BackupRoot "$($safeName)_$RollbackDate.evtx"
        }
        else {
            $latest = Get-ChildItem -Path $BackupRoot -Filter "$($safeName)_*.evtx" -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1
            if (-not $latest) {
                throw "No backup found for '$LogName' under $BackupRoot"
            }
            $backupPath = $latest.FullName
        }

        if (-not (Test-Path $backupPath)) {
            throw "Backup file not found: $backupPath"
        }

        $count = (Get-WinEvent -Path $backupPath -ErrorAction Stop | Measure-Object).Count

        $restoreRoot = Join-Path $BackupRoot 'Restored'
        if (-not (Test-Path $restoreRoot)) { New-Item -ItemType Directory -Path $restoreRoot -Force | Out-Null }
        $restorePath = Join-Path $restoreRoot (Split-Path $backupPath -Leaf)

        if (Test-Path $restorePath) {
            Write-Log -Message "$LogName -> already restored: $restorePath"
            return [PSCustomObject]@{ LogName = $LogName; Status = 'SkippedIdempotent'; RecordCount = $count; RestoredPath = $restorePath; Detail = "Already restored to $restorePath" }
        }

        if ($DryRun) {
            Write-Log -Message "$LogName -> [DRY RUN] would restore $count record(s) to $restorePath"
            return [PSCustomObject]@{ LogName = $LogName; Status = 'DryRunPreview'; RecordCount = $count; RestoredPath = $restorePath; Detail = "Would restore $count record(s)" }
        }

        Copy-Item -Path $backupPath -Destination $restorePath -ErrorAction Stop
        Write-Log -Message "$LogName -> restored $count record(s) for viewing at $restorePath"
        return [PSCustomObject]@{
            LogName = $LogName; Status = 'Restored'; RecordCount = $count; RestoredPath = $restorePath
            Detail  = "View with: Get-WinEvent -Path '$restorePath'  (or Event Viewer > Open Saved Log)"
        }
    }
    catch {
        Write-Log -Level ERROR -Message "$LogName -> ROLLBACK ERROR: $($_.Exception.Message)"
        return [PSCustomObject]@{ LogName = $LogName; Status = 'Error'; RecordCount = 0; RestoredPath = $null; Detail = $_.Exception.Message }
    }
}

# ---------------------------------------------------------------------------
# MAIN: rollback mode short-circuits the whole script; otherwise archive+clear.
# ---------------------------------------------------------------------------
Write-Log -Message "Starting run '$($script:RunTimestamp)' (Rollback=$($Rollback.IsPresent), DryRun=$($DryRun.IsPresent), OlderThanDays=$OlderThanDays, Logs=$($LogName -join ', '))"

if (-not (Test-Path $ArchiveRoot)) { New-Item -ItemType Directory -Path $ArchiveRoot -Force | Out-Null }
if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }

if ($Rollback) {
    $rollbackResults = foreach ($log in $LogName) {
        Invoke-LogRollback -LogName $log -RollbackDate $RollbackDate -BackupRoot $BackupRoot -DryRun:$DryRun
    }

    Write-Host ""
    Write-Host "===== ROLLBACK SUMMARY =====" -ForegroundColor Cyan
    $rollbackResults | Format-Table LogName, Status, RecordCount, RestoredPath -AutoSize
    Write-Log -Message "Rollback run complete."
    return
}

# Live clears require elevation; dry runs only read, so no elevation needed.
if (-not $DryRun -and -not (Test-IsElevated)) {
    Write-Log -Level ERROR -Message "This session is not elevated. Re-run PowerShell as Administrator to archive/clear event logs."
    return
}

# Extra safety gate: a live run is destructive (full log clear per requirement
# above), so require explicit confirmation unless -Force is supplied.
if (-not $DryRun -and -not $Force) {
    Write-Host ""
    Write-Host "WARNING: This will CLEAR the ENTIRE contents of: $($LogName -join ', ')" -ForegroundColor Red
    Write-Host "Old records will be archived first, and a full backup taken, but the live log will be emptied." -ForegroundColor Red
    $response = Read-Host "Type YES to continue"
    if ($response -ne 'YES') {
        Write-Log -Message "Run cancelled by user at confirmation prompt."
        return
    }
}

$cutoff = (Get-Date).AddDays(-$OlderThanDays)
$results = foreach ($log in $LogName) {
    Invoke-LogArchiveAndClear -LogName $log -Cutoff $cutoff -ArchiveRoot $ArchiveRoot -BackupRoot $BackupRoot -DryRun:$DryRun
}

# ---------------------------------------------------------------------------
# SUMMARY: per-log outcome plus overall totals.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "===== EVENT LOG CLEANUP SUMMARY (Run: $($script:RunTimestamp)) =====" -ForegroundColor Cyan
$results | Format-Table LogName, Status, OldRecordCount, TotalBefore, Detail -AutoSize -Wrap

$overall = [PSCustomObject]@{
    Mode              = if ($DryRun) { 'DRY RUN' } else { 'LIVE' }
    LogsProcessed     = $results.Count
    ArchivedAndCleared = ($results | Where-Object Status -eq 'ArchivedAndCleared').Count
    SkippedIdempotent = ($results | Where-Object Status -eq 'SkippedIdempotent').Count
    SkippedNoOldData  = ($results | Where-Object Status -eq 'SkippedNoOldRecords').Count
    Errors            = ($results | Where-Object Status -eq 'Error').Count
    TotalOldRecords   = ($results | Measure-Object -Property OldRecordCount -Sum).Sum
    LogFile           = $script:LogFile
}
$overall | Format-List
Write-Log -Message "Run complete. $($overall | ConvertTo-Json -Compress)"
