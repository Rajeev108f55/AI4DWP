# Invoke-TempCleanup.ps1

A safe, rollback-capable temp file cleanup script for Windows endpoints
(PowerShell 5.1+).

## How it works

Instead of permanently deleting files, the script **moves** matching temp
files into a quarantine folder and writes a `manifest.csv` recording where
every file came from and where it went. This is what makes rollback
possible - nothing is destroyed, only relocated. You can later restore an
entire run (or let the quarantine folder be cleaned up manually/by policy
once you're confident the space can be reclaimed permanently).

Every action (moved, skipped, error, restored) is written to a
date/timestamped log file, and a summary is printed at the end of every run.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `-Path` | `$env:TEMP`, `%WINDIR%\Temp` | One or more folders to clean. |
| `-OlderThanDays` | `0` | Only files with `LastWriteTime` older than this many days are targeted. `0` means all files regardless of age. |
| `-Recurse` | off | Also scan subfolders of each `-Path` entry. Off by default to reduce the risk of touching an application's active subfolder. |
| `-DryRun` | off | Preview only. Lists every file that would be moved (or restored, in rollback mode). No files are moved. The log file is still written. |
| `-Rollback` | off | Switches the script into rollback mode: restores files from a previous run instead of cleaning up. |
| `-RunId` | latest run | Which cleanup run to roll back, by its timestamp folder name (e.g. `20260805_101500`). Only used with `-Rollback`. If omitted, the most recent run under `-QuarantineRoot` is used. |
| `-QuarantineRoot` | `%LOCALAPPDATA%\TempCleanup\Quarantine` | Where moved files are held so they can be rolled back. |
| `-LogRoot` | `%LOCALAPPDATA%\TempCleanup\Logs` | Where log files are written (one per run, named `TempCleanup_<timestamp>.log`). |

## Usage examples

```powershell
# Preview what would be cleaned up (no changes made)
.\Invoke-TempCleanup.ps1 -DryRun

# Clean up files older than 7 days, including subfolders
.\Invoke-TempCleanup.ps1 -OlderThanDays 7 -Recurse

# Clean up everything in the default temp paths right now
.\Invoke-TempCleanup.ps1

# Preview a rollback of the most recent run
.\Invoke-TempCleanup.ps1 -Rollback -DryRun

# Roll back the most recent cleanup run
.\Invoke-TempCleanup.ps1 -Rollback

# Roll back a specific run
.\Invoke-TempCleanup.ps1 -Rollback -RunId 20260805_101500
```

## Safety behaviors

- **Locked files are skipped, not forced.** The script tests each file with
  an exclusive open before touching it; if that fails (file in use), it logs
  a warning and moves on. It never terminates a process to force a delete.
- **Per-file error handling.** Every file is processed in its own try/catch,
  so one bad file (permissions error, path too long, etc.) is logged and
  does not stop the run.
- **Idempotent cleanup.** Once a file is moved to quarantine, it no longer
  exists at the original path, so re-running the script simply finds fewer
  (or no) matching files - it won't error or duplicate work.
- **Idempotent rollback.** Rollback skips (and logs) any entry whose
  quarantined copy is already gone or whose original path already exists,
  so running `-Rollback` twice in a row is safe.
- **No overwrites.** Rollback will never overwrite a file that already
  exists at the original path.

## Things to verify before running live (non `-DryRun`)

- Confirm the default `-Path` values (`%TEMP%` and `%WINDIR%\Temp`) are the
  correct locations for your environment before running without `-DryRun`.
- Cleaning `%WINDIR%\Temp` may require running the script elevated
  (as Administrator).
- Quarantined files still consume disk space until you manually remove the
  `-QuarantineRoot` folder (or a specific run's subfolder) once you're
  confident you no longer need to roll back.

## Output locations

- **Logs:** `%LOCALAPPDATA%\TempCleanup\Logs\TempCleanup_<yyyyMMdd_HHmmss>.log`
- **Quarantine:** `%LOCALAPPDATA%\TempCleanup\Quarantine\<yyyyMMdd_HHmmss>\...`
- **Manifest (per run):** `%LOCALAPPDATA%\TempCleanup\Quarantine\<yyyyMMdd_HHmmss>\manifest.csv`
