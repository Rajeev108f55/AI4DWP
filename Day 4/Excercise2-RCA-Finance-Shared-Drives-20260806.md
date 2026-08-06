# Root Cause Analysis — Finance Shared Drive Access Failure
## Finance team | DESKTOP-FB041 and related DESKTOP-FB* devices | 2026-08-06

**Document prepared by:** DWP Engineer
**Date prepared:** 2026-08-06
**Incident date:** 2026-08-06
**Incident window:** 08:00 – 09:09
**Resolution confirmed:** 09:09
**Severity:** Medium — Finance users could not access shared drives during morning logon
**Status:** RESOLVED

---

## 1. Incident Summary

At approximately 08:40 this morning, Finance users reported that shared drives were unavailable. The issue affected Finance devices in the `DESKTOP-FB*` group and prevented access to the mapped Finance share. Group Policy processing itself was confirmed healthy on an affected workstation, which ruled out a general GPO failure.

The root cause was traced to a drive-mapping script migration that occurred the previous night. The script had been moved from a GPO logon script that ran in the user context to an Intune PowerShell script that ran as SYSTEM. The script was not updated for SYSTEM context, and the UNC path could not be accessed when the script executed at logon.

The suggested resolution was applied and the issue was confirmed resolved at **09:09 AM**. A user was verified logging in to the host successfully, and no further issues were reported.

---

## 2. Affected Systems and Users

| Item | Detail |
|---|---|
| Affected users | Finance team |
| Affected devices | DESKTOP-FB* devices in OU=Finance |
| Scope | Finance shared drive mapping only |
| Other users affected | None reported |
| Business impact | Finance users could not access mapped shared drives during morning logon |
| Resolution time | 09:09 AM after script/context remediation |

---

## 3. Timeline of Events

| Time | Event |
|---|---|
| **2024-03-14 23:30** | Drive mapping script migrated from GPO logon script running as USER to Intune PowerShell script running as SYSTEM |
| **08:00:01** | ScriptRunner starts `Map-FinBridgeDrives.ps1` |
| **08:00:02** | Script context confirmed as SYSTEM account |
| **08:00:03** | Network path `\\finbridge-fs01\\Finance` is not accessible from SYSTEM context; script fails with `Network name cannot be found` |
| **08:00:04** | ScriptRunner reports no retry configured |
| **08:00:05** | Workstation service enters running state on DESKTOP-FB041 |
| **08:00:06** | Group Policy settings processed successfully on DESKTOP-FB041, confirming the issue is not a Group Policy processing failure |
| **08:00:07** | NTFS Event 98 reports drive letter S: has not been assigned |
| **Morning triage** | Migration note reviewed; script context mismatch identified as cause |
| **Remediation applied** | Suggested resolution applied to correct the drive-mapping execution path for Finance devices |
| **09:09** | User logon verified on host and no further shared-drive issues reported |

---

## 4. Supporting Evidence

### 4.1 Intune Management Extension Log

| Time | Source | Detail |
|---|---|---|
| 08:00:01 | ScriptRunner | Executing: `Map-FinBridgeDrives.ps1` |
| 08:00:02 | ScriptRunner | Script context: SYSTEM account |
| 08:00:03 | ScriptRunner | Warning: Network path `\\finbridge-fs01\\Finance` not accessible from SYSTEM context at execution time |
| 08:00:03 | ScriptRunner | Error: `Map-FinBridgeDrives.ps1` failed; exit code 1; `Network name cannot be found` |
| 08:00:04 | ScriptRunner | No retry configured |

### 4.2 System Log — DESKTOP-FB041

| Time | Event ID | Level | Detail |
|---|---|---|---|
| 08:00:05 | 7036 | Information | Workstation service entered running state |
| 08:00:06 | 1500 | Information | Group Policy settings processed successfully |
| 08:00:07 | 98 | Warning | File system could not map drive letter S:; drive letter has not been assigned |

### 4.3 Migration Change Note

- **2024-03-14 23:30** — Drive mapping script migrated from GPO logon script (runs as USER) to Intune PowerShell script (runs as SYSTEM).
- Script was **not updated to handle SYSTEM context**.
- UNC network paths require the Workstation service and mapped credentials, which are not available to SYSTEM at login time.

### 4.4 Key Evidence Notes

- **Event 1500 at 08:00:06** proves Group Policy itself processed successfully, so the failure was not a GPO engine problem.
- **ScriptRunner failure at 08:00:03** shows the script could not resolve or reach the UNC path from SYSTEM context.
- **The migration note at 2024-03-14 23:30** explains why the script failed only after the move to Intune SYSTEM execution.
- **Event 98 at 08:00:07** confirms the mapped drive letter was never created.

---

## 5. Root Cause

The drive-mapping script `Map-FinBridgeDrives.ps1` was migrated from a user-context GPO logon script to an Intune PowerShell script running as SYSTEM. The script was not updated for SYSTEM execution, so when it ran at logon it could not access the UNC path `\\finbridge-fs01\\Finance`. Because SYSTEM does not have the same user context, mapped credentials, or timing as an interactive user session, the script failed with `Network name cannot be found` and the Finance drive mapping did not complete.

---

## 6. Five Whys Analysis

| # | Why? | Answer |
|---|---|---|
| 1 | Why could Finance users not access shared drives? | The mapped Finance drive was not created at logon, so the share was unavailable to the user. |
| 2 | Why was the mapped drive not created? | `Map-FinBridgeDrives.ps1` failed during execution. |
| 3 | Why did the script fail? | It ran in SYSTEM context and could not access `\\finbridge-fs01\\Finance`, returning `Network name cannot be found`. |
| 4 | Why was the script running in SYSTEM context? | The script had been migrated from a GPO logon script to an Intune PowerShell script. |
| 5 | Why did the migration cause failure? | The script was not updated for SYSTEM context and still depended on user-context network access and credentials that are not available at login time. |

**Root cause of the process gap:** The script migration changed the execution context, but the drive-mapping logic was not revalidated for SYSTEM execution before rollout.

---

## 7. Immediate Actions Taken

| Action | Time | Outcome |
|---|---|---|
| Script migration issue identified in change note | Morning triage | Confirmed cause of failure |
| Suggested resolution applied | Before 09:09 | Drive mapping issue corrected |
| User logon verified on host | 09:09 | Finance user access restored |
| No further issues reported | 09:09 onward | Service confirmed stable |

---

## 8. Preventive Actions

| # | Action | Owner | Priority |
|---|---|---|---|
| 1 | **Validate execution context before migrating scripts** — any logon or drive-mapping script moved from user context to Intune SYSTEM context must be tested explicitly under SYSTEM before production rollout. | Endpoint / Intune team | High |
| 2 | **Do not rely on user-only resources in SYSTEM scripts** — scripts that depend on mapped credentials or interactive network availability should remain in user context or be refactored to remove those dependencies. | Endpoint / Platform team | High |
| 3 | **Add pilot-device verification for drive maps** — confirm the mapped drive exists on at least one Finance pilot workstation before promoting the change to the rest of the OU. | Service Desk / Endpoint team | High |
| 4 | **Include Workstation service and UNC reachability checks in rollout validation** — verify the target share can be reached from the intended script context and timing before deployment. | Intune / Platform team | Medium |
| 5 | **Document script migration standards** — require a context review, dependency review, and rollback plan for every script migration from GPO to Intune. | Change management | Medium |

---

## 9. Lessons Learned

- **Execution context matters.** A script that works as a user logon script can fail immediately when moved to SYSTEM.
- **A successful Group Policy event does not prove drive mapping success.** The drive mapping failure occurred independently of GPO processing.
- **Migration notes are high-value evidence.** The change log provided the key clue that the script had not been updated for SYSTEM context.
- **Validation must match the deployment model.** Testing should confirm the script works in the exact context and timing it will use in production.
