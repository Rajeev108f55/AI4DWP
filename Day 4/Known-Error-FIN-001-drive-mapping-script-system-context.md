# Known-Error Record — Finance Shared Drive Mapping Failure in SYSTEM Context
**Knowledge Base Reference:** Known-Error-FIN-001
**Date raised:** 2026-08-06
**Source incident:** Finance shared drive access failure, 2026-08-06
**RCA document:** Excercise2-RCA-Finance-Shared-Drives-20260806.md
**Status:** Verified

---

**Symptom:**
Finance users could not access mapped shared drives during logon. On the affected workstation, the drive letter S: was not assigned, even though Group Policy processed successfully.

**Cause:**
`Map-FinBridgeDrives.ps1` was migrated from a GPO logon script running as USER to an Intune PowerShell script running as SYSTEM, but it was not updated for SYSTEM execution. In that context, the script could not access `\\finbridge-fs01\\Finance` and failed with `Network name cannot be found`.

**Scope:**
Affects Finance users on `DESKTOP-FB*` devices in `OU=Finance` when the drive-mapping script runs in SYSTEM context. The source incident was limited to Finance shared-drive access; Group Policy processing on the affected host was successful.

**Workaround:**
Apply the corrected drive-mapping execution path for Finance devices so the script can reach `\\finbridge-fs01\\Finance`, then verify a Finance user can log in successfully and that S: is assigned.

**Permanent fix:**
Validate execution context before migrating drive-mapping scripts from USER to SYSTEM, avoid user-only network and credential dependencies in SYSTEM scripts, and require pilot-device verification plus UNC reachability checks before rollout.

**How to spot it:**
The Intune Management Extension log shows `Map-FinBridgeDrives.ps1` starting in SYSTEM context, followed by a warning that `\\finbridge-fs01\\Finance` is not accessible and an error `Network name cannot be found` with no retry configured. On the affected host, the System log shows Group Policy Event ID **1500** (success) and NTFS Event ID **98** indicating drive letter S: has not been assigned.