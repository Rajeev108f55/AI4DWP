# Invoke-EventLogArchiveCleanup.ps1

Archives and clears Windows Event Logs on an endpoint, with a dry-run preview
and a best-effort rollback mechanism (PowerShell 5.1+).

## Critical limitation - read this first

**Windows Event Log has no API to delete only old records from a live log.**
Clearing a log (`wevtutil cl`) always wipes the **entire** log, not just the
records older than your cutoff. This script cannot change that OS behavior.
To keep it safe despite this:

- It refuses to clear a log when there are **zero** records older than the
  cutoff - nothing is wiped just to "check the box."
- It always exports the old records to their own `.evtx` archive **and**
  takes a full backup of the entire log immediately before clearing
  (`wevtutil cl /bu:`), so every record - old and new - exists as a file
  afterward.
- **Rollback does not repopulate the live log.** Windows does not support
  re-injecting historical events back into a live channel. "Rollback" in
  this script means: locate the pre-clear backup and make it available again
  for viewing (via `Get-WinEvent -Path` or Event Viewer's "Open Saved Log").
  If you need the data actually querying inside the live channel again,
  that is not possible with any supported Windows tool - the backup file is
  the durable record.
- Clearing the **Security** log requires the "Manage auditing and security
  log" user right and is a significant audit/compliance event. Verify you
  are authorized before including `Security` in `-LogName`.

## How it works

1. **Dry run** (`-DryRun`): for each log, reports the count of records older
   than the cutoff (what would be archived) alongside the log's total record
   count (what a clear would actually wipe). No files are written, nothing
   is cleared.
2. **Live run**: exports old records to an archive `.evtx`, verifies it's
   readable, then runs `wevtutil cl <log> /bu:<backup file>` to back up the
   full log and clear it in one atomic step.
3. **Rollback** (`-Rollback`): copies a prior run's full backup into a
   `Restored` folder so it can be opened/queried again.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `-LogName` | `Application`, `System` | One or more event logs to process. |
| `-OlderThanDays` | `3` | Only records older than this many days count toward the archive and justify a clear. |
| `-DryRun` | off | Preview only - prints old/total record counts, makes no changes. |
| `-Rollback` | off | Restores read access to a previously cleared log's backup instead of archiving/clearing. |
| `-RollbackDate` | latest | Date (`yyyyMMdd`) of the backup to restore, per log. Defaults to the most recent backup found. |
| `-Force` | off | Skips the interactive `Type YES to continue` confirmation before a live clear. |
| `-ArchiveRoot` | `%LOCALAPPDATA%\EventLogArchive\Archives` | Where old-record-only `.evtx` archives are written. |
| `-BackupRoot` | `%LOCALAPPDATA%\EventLogArchive\PreClearBackups` | Where full pre-clear `.evtx` backups (used for rollback) are written. |
| `-LogRoot` | `%LOCALAPPDATA%\EventLogArchive\Logs` | Where this script's own timestamped run logs are written. |

## Usage examples

```powershell
# Preview: see counts only, no changes made
.\Invoke-EventLogArchiveCleanup.ps1 -DryRun

# Archive + clear Application and System logs older than the default 3 days
.\Invoke-EventLogArchiveCleanup.ps1

# Same, but skip the confirmation prompt (e.g. for a scheduled task)
.\Invoke-EventLogArchiveCleanup.ps1 -Force

# Target a specific log and a longer retention window
.\Invoke-EventLogArchiveCleanup.ps1 -LogName Application -OlderThanDays 14

# Restore read access to the most recent System log backup
.\Invoke-EventLogArchiveCleanup.ps1 -Rollback -LogName System

# Restore a specific date's backup
.\Invoke-EventLogArchiveCleanup.ps1 -Rollback -LogName System -RollbackDate 20260805
```

## Safety behaviors

- **Elevation required for live runs.** The script checks whether the
  session is running as Administrator before doing any clear; `-DryRun`
  does not require elevation since it only reads.
- **Confirmation prompt.** A live (non-`-DryRun`) run prompts for
  `Type YES to continue` unless `-Force` is passed, because clearing wipes
  the entire log, not just old records.
- **Archive verified before clear.** After exporting old records, the
  script re-opens the archive file to confirm it is readable before it
  proceeds to back up and clear the log.
- **Skips clearing when nothing qualifies.** If there are zero records
  older than the cutoff, the log is left untouched.
- **Per-log error handling.** Each log is processed independently in its
  own try/catch; a failure on one log is recorded in the summary and does
  not stop the others from being processed.
- **Idempotent archiving.** Archive/backup files are named
  `<log>_<yyyyMMdd>.evtx`. If today's archive already exists for a log,
  that log is skipped entirely on a re-run (no duplicate clear).
- **Idempotent rollback.** Restoring the same backup twice simply reports
  "already restored" the second time; it never overwrites.

## Things to verify before running live

- Confirm `-LogName` only contains logs you intend to fully wipe -
  clearing is all-or-nothing per log.
- Confirm you have authorization before including `Security` in `-LogName`.
- Confirm `wevtutil.exe` is present and not blocked by endpoint security
  tooling (it ships with Windows by default, in `%WINDIR%\System32`).
- Confirm the session is elevated (Administrator) before a live run.

## Output locations

- **Script logs:** `%LOCALAPPDATA%\EventLogArchive\Logs\EventLogCleanup_<yyyyMMdd_HHmmss>.log`
- **Old-record archives:** `%LOCALAPPDATA%\EventLogArchive\Archives\<log>_<yyyyMMdd>.evtx`
- **Full pre-clear backups:** `%LOCALAPPDATA%\EventLogArchive\PreClearBackups\<log>_<yyyyMMdd>.evtx`
- **Restored (rollback) copies:** `%LOCALAPPDATA%\EventLogArchive\PreClearBackups\Restored\<log>_<yyyyMMdd>.evtx`
