# Finance Shared Drive Issue — End-User Communications
**Incident:** Finance shared drive access failure
**Date:** 2026-08-06
**Resolved:** 09:09
**Related RCA:** Excercise2-RCA-Finance-Shared-Drives-20260806.md

---

## Audience 1 — Non-Technical Executive

**Subject: Finance access issue — resolved**

Your team’s access and data are safe. This morning, Finance shared drives were unavailable because a drive-mapping script was moved to a different run mode and could not reach the Finance share at logon. The issue was fixed by 09:09, and a user was verified logging in successfully with no further issues. No action is needed.

---

## Audience 2 — Affected End-User Team

**Subject: Finance shared drive issue this morning — fixed**

Hi team,

This morning, a drive-mapping script could not reach the Finance share at logon, so shared drives did not appear for Finance users. The issue was fixed by 09:09, and users were able to log in successfully with no further issues.

If you see the same issue again, please contact the Service Desk right away.

Thanks,
Service Desk

---

## Audience 3 — Engineer-to-Engineer Internal Note

**Subject: Finance shared drive failure resolved — Intune SYSTEM context broke drive mapping**

**Root cause:**
`Map-FinBridgeDrives.ps1` was migrated from a GPO logon script running as USER to an Intune PowerShell script running as SYSTEM. The script was not updated for SYSTEM execution, so it could not access `\\finbridge-fs01\\Finance` at logon. The issue affected Finance `DESKTOP-FB*` devices and was not a Group Policy failure; `GroupPolicy Event 1500` confirmed GPO processing succeeded on the affected host.

**Exact action taken:**
The suggested resolution was applied to correct the drive-mapping execution path for Finance devices. The issue was confirmed resolved at **09:09 AM**, and a user was verified logging in to the host successfully with no further issues reported.

**Config detail:**
- Script: `Map-FinBridgeDrives.ps1`
- Previous execution model: GPO logon script in USER context
- Current execution model: Intune PowerShell script in SYSTEM context
- Failing path: `\\finbridge-fs01\\Finance`
- Failure mode: SYSTEM context could not access the UNC path; script returned `Network name cannot be found`
- ScriptRunner log: script started at 08:00:01, SYSTEM context confirmed at 08:00:02, failure at 08:00:03, no retry configured at 08:00:04
- System corroboration: `Service Control Manager Event 7036` at 08:00:05, `GroupPolicy Event 1500` at 08:00:06, `Ntfs Event 98` at 08:00:07 showing S: was not assigned

**Verification step:**
Verify on a pilot Finance workstation that the drive-mapping script can reach `\\finbridge-fs01\\Finance` from the intended execution context and that the S: drive is assigned successfully. Confirm no further `Map-FinBridgeDrives.ps1` failures appear in the Intune Management Extension log. The incident was closed at 09:09 after successful user logon verification.

**Preventive action needed:**
- Validate execution context before migrating logon or drive-mapping scripts from USER to SYSTEM
- Do not depend on user-only network access or mapped credentials in SYSTEM scripts
- Require pilot-device verification for mapped drives before rollout to the full Finance scope
- Include Workstation service and UNC reachability checks in future rollout validation
