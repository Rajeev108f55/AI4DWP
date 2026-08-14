# README — Script-AI generated-Evidence-Collection-DriveMapping.ps1

## Purpose
Gathers evidence on a Floor 6 device for the **top-ranked root cause** in
[Ranked-Login-issues-Floor6-20260814.md](Ranked-Login-issues-Floor6-20260814.md):
a drive-mapping/logon script failure introduced by Friday's application
deployment.

The script is **read-only towards source logs** — it only copies files,
generates a fresh `gpresult` report, and exports relevant System event log
entries into a separate evidence folder. It never deletes or modifies
anything on the source device outside of its own evidence folder.

## What it collects
- Intune Management Extension logs (`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` by default)
- A fresh `gpresult /h` HTML report (Group Policy processing state)
- System event log entries for Event ID **1500** (Group Policy processing) and
  Event ID **98** (NTFS — drive letter not assigned)

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-DryRun` | switch | off | Simulates the run only. Prints the script's baseline version and parameters first, then logs every action it *would* take (copy, skip, generate report) without changing anything on disk. |
| `-MinAgeDays` | int | `0` | Only collects files whose `LastWriteTime` is older than this many days. `0` (default) means all files are eligible regardless of age. |
| `-EvidenceRoot` | string | `C:\DWP-Evidence\Floor6-LoginIssue` | Root folder where evidence copies, the run manifest, and logs are stored. |
| `-SourcePaths` | string[] | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` | One or more folders to pull log evidence from. Pass additional paths as a comma-separated array if other logon-script logs need to be included. |
| `-Rollback` | switch | off | Removes the evidence copies made by a previous run (identified by `-RunId`), using the run's `manifest.csv`. Never touches original source files. |
| `-RunId` | string | current date (`yyyyMMdd`) | Identifies the evidence run folder. Defaults to today's date so re-running the script on the same day reuses the same folder instead of duplicating evidence. |

## Usage examples

**Dry run first (recommended before any real run):**
```powershell
.\Script-AI generated-Evidence-Collection-DriveMapping.ps1 -DryRun
```

**Collect all available log files:**
```powershell
.\Script-AI generated-Evidence-Collection-DriveMapping.ps1
```

**Collect only files older than 1 day:**
```powershell
.\Script-AI generated-Evidence-Collection-DriveMapping.ps1 -MinAgeDays 1
```

**Roll back a run (dry run first to preview):**
```powershell
.\Script-AI generated-Evidence-Collection-DriveMapping.ps1 -Rollback -RunId 20260814 -DryRun
.\Script-AI generated-Evidence-Collection-DriveMapping.ps1 -Rollback -RunId 20260814
```

## Safety features
1. **Dry run mode** — prints the script version/config baseline first, then previews every action without making changes.
2. **Age filter** (`-MinAgeDays`) — avoids collecting files still being actively written to.
3. **Locked file handling** — files currently open/locked by another process are detected, skipped, and logged; the script never stops on a locked file.
4. **Per-file try/catch** — a failure copying one file is logged as an error and does not abort the run.
5. **Full logging** — every action is written to a date/timestamped log file under `EvidenceRoot\Logs`.
6. **End-of-run summary** — reports counts of files scanned, copied, skipped (age/locked/already collected), and errors.
7. **Commented sections** — each functional block in the script is explained inline.
8. **Rollback** — removes only the copies the script itself made (tracked via `manifest.csv`), never the original source files.
9. **Idempotent** — re-running with the same `-RunId` (default: today's date) skips files already collected unchanged, and does not duplicate manifest entries or fail if the evidence folder already exists.

## Output layout
```
C:\DWP-Evidence\Floor6-LoginIssue\
  Logs\
    EvidenceCollection_20260814_091500.log   # timestamped run log
  20260814\                                   # RunId (default: date)
    manifest.csv                              # tracks copies made, used for rollback
    gpresult.html
    GroupPolicy-NTFS-Events.csv
    <collected .log files>
```

## Notes
- Run in an elevated PowerShell session if the source log paths require admin access.
- `Get-WinEvent` will report an error if no matching events (IDs 1500/98) exist on the device — this is logged as an error but does not stop the script.
