# Account Lockout — Incident Communications
**Incident:** FINBRIDGE\cthompson login failure — account lockout
**Date:** 2024-03-15
**Resolved:** 09:09
**Related RCA:** RCA-cthompson-login-failure-20240315.md

---

## Audience 1 — Non-Technical Executive

**Subject: This morning's login issue for one team member — resolved**

Your team member's account and all data are completely safe. This morning, one staff member was temporarily unable to log in to their computer because an outdated saved password on their device triggered an automatic security lock on their account. Our team identified and resolved the issue by 09:09 AM with no data loss. No action is needed from you or your team.

---

## Audience 2 — Affected End-User Team

**Subject: Login lock issue this morning — fixed, and what to do if it happens to you**

Hi team,

This morning one of your colleagues was temporarily locked out of their computer because their device had an old saved password stored on it, which kept trying to log in automatically and triggered a security lock. It was fixed by 09:09 AM with no data lost.

If this happens to you — you see a login failure or get told your account is locked — please call the Service Desk straight away and quote **T-CTHOMPSON-0315**. Do not keep retrying as this can make the lock worse.

Thanks.

---

## Audience 3 — Engineer-to-Engineer Internal Note

**Subject: Account lockout resolved — cthompson / DESKTOP-FB022 / stale Credential Manager entry**

**Root cause:**
Stale credential stored in Windows Credential Manager on DESKTOP-FB022 was auto-retrying with an outdated password for `FINBRIDGE\cthompson`. Three Event 4625 failures (Logon Type 2, Interactive) at 08:44:03, 08:44:28, 08:44:55 — ~27s intervals, consistent with automated retry not manual input. DC validated account name but rejected credential each time (`0xC000006A` — wrong password, confirmed via Event 4776 08:44:01). Account locked at 08:44:56 (Event 4740, caller: DESKTOP-FB022) on third failure, consistent with 3-attempt lockout threshold. No changes to account or infrastructure prior to incident.

**Actions taken:**
1. Stale credential identified and removed from Credential Manager on DESKTOP-FB022 (Control Panel → Credential Manager → Windows Credentials) — stopped the automated retry loop
2. Account unlocked by `FINBRIDGE\helpdesk-admin` at 09:08:14 (Event 4722)
3. cthompson logged in successfully at 09:09:01 (Event 4624, Logon Type 2, source: DESKTOP-FB022)

**Config detail:**
- Faulting device: DESKTOP-FB022
- Stored credential target: domain/FINBRIDGE — outdated password, not updated after a prior AD password change
- Lockout policy in effect: 3 bad attempts → lockout (confirmed by 3 failures → immediate Event 4740)
- Error code in Event 4776: `0xC000006A` (wrong password) — rules out `0xC0000071` (expired) and `0xC0000072` (disabled)

**Verification step:**
After unlock and credential removal, confirm no re-lockout by monitoring:
```powershell
Get-WinEvent -LogName Security -ComputerName <DC-name> |
  Where-Object {$_.Id -eq 4740 -and $_.Message -like "*cthompson*"} |
  Select-Object TimeCreated, Message -First 5
```
Successful logon confirmed at 09:09:01 via Event 4624. No further Event 4740 observed.

**If this recurs — immediate steps:**
1. Read Event 4740 caller computer field — go to that device first
2. Before unlocking, remove any stale Credential Manager entry on the source device — unlocking without this causes immediate re-lockout
3. Unlock: `Unlock-ADAccount -Identity <username>`
4. Have user log in and watch for re-lock within 30 seconds
5. Check `PasswordLastSet` to confirm if a recent password change triggered the stale entry:
   ```powershell
   Get-ADUser <username> -Properties PasswordLastSet, LockedOut, BadLogonCount | Select-Object *
   ```

**Preventive action required:**
- Publish user guidance: after any AD password change, users must open Credential Manager and remove/update stored domain credentials — without this, re-lockout on next login is certain
- Evaluate GPO: `Network access: Do not allow storage of passwords and credentials for network authentication` for standard interactive accounts
- Add Credential Manager check as mandatory step 1 in the account-lockout resolution runbook (before unlock, not after)
- Configure SIEM/AD alert: three or more Event 4625 failures for the same account from the same source within 60 seconds — this pattern is detectable before Event 4740 fires and allows proactive intervention
