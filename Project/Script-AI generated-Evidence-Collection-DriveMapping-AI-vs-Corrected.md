# AI-Generated vs Hand-Corrected — Floor 6 Drive-Mapping Evidence Collection Script

This document pairs the **AI-generated first draft** with the **hand-corrected version**
now in [Script-AI generated-Evidence-Collection-DriveMapping.ps1](Script-AI%20generated-Evidence-Collection-DriveMapping.ps1),


Target: gather evidence for the **top-ranked cause** in
[Ranked-Login-issues-Floor6-20260814.md](Ranked-Login-issues-Floor6-20260814.md) —
a drive-mapping/logon script failure introduced by Friday's application deployment.

## TL;DR — What was wrong, what was fixed

> **Bug:** `[CmdletBinding(SupportsShouldProcess = $true)]` was declared in v1 but
> `$PSCmdlet.ShouldProcess()` was never called anywhere — so the standard `-WhatIf`
> and `-Confirm` switches had **no effect**. Only the custom `-DryRun` switch worked,
> meaning `-WhatIf` alone would have silently performed real copies/deletes.
>
> **Fix:** every mutating action (run folder creation, file copy, rollback deletion,
> empty-folder cleanup, GPResult report generation, event log export) in v2 now checks
> `$PSCmdlet.ShouldProcess(...)` in addition to `-DryRun`, so `-WhatIf`/`-Confirm` work
> as any PowerShell engineer would expect. See the [fixes table](#fixes-applied-one-line-each) below for the full list.

---

## Version 1 — AI-Generated Draft (as first produced)

```powershell
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

# ... run folder / manifest / log file setup ...

if (-not (Test-Path $RunFolder)) {
    if ($DryRun) {
        Write-Log ("[DRYRUN] Would create run folder {0}" -f $RunFolder) -Level DRYRUN
    } else {
        New-Item -Path $RunFolder -ItemType Directory -Force | Out-Null
        Write-Log "Created run folder $RunFolder"
    }
}

# ... file collection loop ...
try {
    if ($DryRun) {
        Write-Log ("[DRYRUN] Would copy {0} -> {1}" -f $file.FullName, $destination) -Level DRYRUN
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

# ... rollback loop ...
foreach ($entry in $entries) {
    try {
        if (Test-Path $entry.Destination) {
            if ($DryRun) {
                Write-Log ("[DRYRUN] Would remove {0}" -f $entry.Destination) -Level DRYRUN
            } else {
                Remove-Item -Path $entry.Destination -Force -ErrorAction Stop
                Write-Log ("Rolled back (removed) {0}" -f $entry.Destination)
            }
        }
    }
    catch {
        Write-Log ("ERROR rolling back {0}: {1}" -f $entry.Destination, $_.Exception.Message) -Level ERROR
    }
}

if (-not $DryRun -and (Test-Path $RunFolder) -and
    ((Get-ChildItem $RunFolder -File | Where-Object { $_.Name -ne "manifest.csv" }) -eq $null)) {
    Remove-Item -Path $ManifestPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $RunFolder -Force -Recurse -ErrorAction SilentlyContinue
    Write-Log "Removed empty run folder $RunFolder"
}
```

**Issue with v1:** `[CmdletBinding(SupportsShouldProcess = $true)]` was declared, but
`$PSCmdlet.ShouldProcess()` was **never actually called** anywhere. Every mutating
action only checked the custom `-DryRun` switch. This means `-WhatIf` and `-Confirm` —
the standard PowerShell safety switches every DWP engineer expects to work — were
silently ignored. Running the script with `-WhatIf` alone would have performed the
real actions instead of previewing them.

---

## Version 2 — Hand-Corrected (current, in the .ps1 file)

```powershell
# Run folder creation
if (-not (Test-Path $RunFolder)) {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($RunFolder, "Create evidence run folder")) {
        Write-Log ("[DRYRUN/WHATIF] Would create run folder {0}" -f $RunFolder) -Level DRYRUN
    } else {
        New-Item -Path $RunFolder -ItemType Directory -Force | Out-Null
        Write-Log "Created run folder $RunFolder"
    }
}

# File copy
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

# Rollback removal
if (Test-Path $entry.Destination) {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($entry.Destination, "Remove evidence copy")) {
        Write-Log ("[DRYRUN/WHATIF] Would remove {0}" -f $entry.Destination) -Level DRYRUN
    } else {
        Remove-Item -Path $entry.Destination -Force -ErrorAction Stop
        Write-Log ("Rolled back (removed) {0}" -f $entry.Destination)
    }
}

# Empty run-folder cleanup after rollback
$remainingFiles = @(Get-ChildItem $RunFolder -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "manifest.csv" })
if (-not $DryRun -and (Test-Path $RunFolder) -and $remainingFiles.Count -eq 0 -and
    $PSCmdlet.ShouldProcess($RunFolder, "Remove empty run folder")) {
    Remove-Item -Path $ManifestPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $RunFolder -Force -Recurse -ErrorAction SilentlyContinue
    Write-Log "Removed empty run folder $RunFolder"
}

# GPResult report generation
try {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($gpResultPath, "Generate GPResult report")) {
        Write-Log ("[DRYRUN/WHATIF] Would generate GPResult report at {0}" -f $gpResultPath) -Level DRYRUN
    } elseif (-not (Test-Path $gpResultPath)) {
        gpresult /h $gpResultPath /f 2>$null
        Write-Log ("Generated GPResult report: {0}" -f $gpResultPath)
    }
}
catch { $summary.Errors++; Write-Log ("ERROR generating GPResult report: {0}" -f $_.Exception.Message) -Level ERROR }

# Event log export
try {
    if ($DryRun -or -not $PSCmdlet.ShouldProcess($eventLogPath, "Export Group Policy/NTFS events")) {
        Write-Log ("[DRYRUN/WHATIF] Would export System log events (IDs 1500, 98) to {0}" -f $eventLogPath) -Level DRYRUN
    } elseif (-not (Test-Path $eventLogPath)) {
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1500, 98 } -ErrorAction Stop |
            Select-Object TimeCreated, Id, ProviderName, Message |
            Export-Csv -Path $eventLogPath -NoTypeInformation
        Write-Log ("Exported Group Policy/NTFS events: {0}" -f $eventLogPath)
    }
}
catch { $summary.Errors++; Write-Log ("ERROR exporting event log entries (may be none present): {0}" -f $_.Exception.Message) -Level ERROR }
```

The full, current version lives in
[Script-AI generated-Evidence-Collection-DriveMapping.ps1](Script-AI%20generated-Evidence-Collection-DriveMapping.ps1) — the excerpts above show only the sections that changed.

---

## Fixes Applied (one line each)

| # | Location | Fix | Why |
|---|---|---|---|
| 1 | Run folder creation | Added `$PSCmdlet.ShouldProcess($RunFolder, "Create evidence run folder")` check alongside `-DryRun` | `-WhatIf` had no effect on folder creation before this — it would have silently created the folder for real. |
| 2 | File copy loop | Added `$PSCmdlet.ShouldProcess($destination, ...)` check before `Copy-Item` | `-WhatIf` must preview file copies without touching disk; previously only `-DryRun` was honoured. |
| 3 | Rollback removal | Added `$PSCmdlet.ShouldProcess($entry.Destination, "Remove evidence copy")` before `Remove-Item` | Rollback is a delete operation — the riskiest action in the script — and is the most important place for `-WhatIf`/`-Confirm` to actually work. |
| 4 | Empty run-folder cleanup | Added `$PSCmdlet.ShouldProcess($RunFolder, "Remove empty run folder")` | Same reasoning as #3; this also deletes the manifest, so it needed the same guard. |
| 5 | GPResult report generation | Added `$PSCmdlet.ShouldProcess($gpResultPath, "Generate GPResult report")` | Running `gpresult /h` writes a file to disk; `-WhatIf` should preview this like any other write. |
| 6 | Event log export | Added `$PSCmdlet.ShouldProcess($eventLogPath, "Export Group Policy/NTFS events")` | Same reasoning as #5 — `Export-Csv` is a write action that `-WhatIf` should be able to suppress. |
| 7 | Log message prefixes | Changed `[DRYRUN]` to `[DRYRUN/WHATIF]` in preview log lines | Makes it clear in the audit log whether `-DryRun`, `-WhatIf`, or both caused an action to be skipped. |

## Net effect
`SupportsShouldProcess` is no longer a no-op declaration — `-WhatIf` and `-Confirm`
now work as expected on every mutating action (folder creation, file copy, rollback
deletion, report/event export), in addition to the existing `-DryRun` switch. Both
mechanisms funnel into the same log output, so the audit trail is identical either way.

## How to verify
```powershell
# Preview only, using the standard PowerShell switch
.\Script-AI generated-Evidence-Collection-DriveMapping.ps1 -WhatIf

# Ask for confirmation before each mutating action
.\Script-AI generated-Evidence-Collection-DriveMapping.ps1 -Confirm
```
