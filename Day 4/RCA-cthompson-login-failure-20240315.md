# Root Cause Analysis — Account Lockout / Login Failure
## FINBRIDGE\cthompson | DESKTOP-FB022 | 2024-03-15

**Document prepared by:** DWP Engineer
**Date prepared:** 2026-08-06
**Incident date:** 2024-03-15
**Incident window:** 08:44 – 09:09
**Resolution confirmed:** 09:09
**Severity:** Medium — single user unable to log in during morning working hours
**Status:** RESOLVED

---

## 1. Incident Summary

On the morning of 2024-03-15, user `FINBRIDGE\cthompson` was unable to log in to their workstation DESKTOP-FB022 from approximately 08:40. Three consecutive failed logon attempts were recorded between 08:44:03 and 08:44:55, each submitting an incorrect password at a regular ~27-second interval. The account was locked out at 08:44:56 after the third failure. No infrastructure or account changes were logged prior to the incident. No other users were affected.

The incident was resolved at 09:09 after the helpdesk unlocked the account and the stale stored credential on DESKTOP-FB022 was removed. `cthompson` logged in successfully at 09:09:01 with no further issues reported.

---

## 2. Affected Systems and Users

| Item | Detail |
|---|---|
| Affected account | FINBRIDGE\cthompson |
| Affected device | DESKTOP-FB022 |
| Scope | Single user, single device |
| Other users affected | None |
| Business impact | User unable to access workstation during morning peak; estimated ~25 minutes of lost access (08:44–09:09) |

---

## 3. Timeline of Events

| Time | Event |
|---|---|
| **~08:40** | cthompson attempts to log in to DESKTOP-FB022; login does not succeed |
| **08:44:01** | Domain controller receives a credential validation request for `FINBRIDGE\cthompson` from DESKTOP-FB022 — error code `0xC000006A` (wrong password) — Event 4776 |
| **08:44:03** | First logon failure recorded — "Unknown user name or bad password", Logon Type 2 (Interactive) — Event 4625 |
| **08:44:28** | Second logon failure — same account, same reason, same source — Event 4625 (~25s after first) |
| **08:44:55** | Third logon failure — same account, same reason, same source — Event 4625 (~27s after second) |
| **08:44:56** | Account locked out — `FINBRIDGE\cthompson`, caller computer DESKTOP-FB022 — Event 4740 |
| **~08:40–09:00** | Incident logged; DWP engineer begins triage |
| **~09:00** | Stale stored credential identified in Credential Manager on DESKTOP-FB022 and removed |
| **09:08:14** | Helpdesk admin (`FINBRIDGE\helpdesk-admin`) unlocks the account — Event 4722 |
| **09:09:01** | `cthompson` logs in successfully — Logon Type 2 (Interactive), source DESKTOP-FB022 — Event 4624 |
| **09:09** | Incident resolved; user confirmed working |

---

## 4. Supporting Evidence

### 4.1 Security Event Log — DESKTOP-FB022 / Domain Controller (Incident Window)

| Time | Event ID | Level | Detail |
|---|---|---|---|
| 08:44:01 | 4776 | Audit Failure | Credential validation failed — FINBRIDGE\cthompson, error code **0xC000006A** (wrong password), source: DESKTOP-FB022 |
| 08:44:03 | 4625 | Audit Failure | Logon failed — "Unknown user name or bad password", Logon Type **2 (Interactive)**, source: DESKTOP-FB022 |
| 08:44:28 | 4625 | Audit Failure | Second logon failure — same account, reason, and source |
| 08:44:55 | 4625 | Audit Failure | Third logon failure — same account, reason, and source |
| 08:44:56 | 4740 | Audit Failure | **Account locked out** — FINBRIDGE\cthompson, caller computer: DESKTOP-FB022 |

### 4.2 Security Event Log — Resolution Window

| Time | Event ID | Level | Detail |
|---|---|---|---|
| 09:08:14 | 4722 | Audit Success | Account enabled/unlocked — FINBRIDGE\cthompson, actioned by FINBRIDGE\helpdesk-admin |
| 09:09:01 | 4624 | Audit Success | **Successful logon** — FINBRIDGE\cthompson, Logon Type 2 (Interactive), source: DESKTOP-FB022 |

### 4.3 Key Evidence Notes

- **Error code `0xC000006A`** (wrong password) in Event 4776 eliminates password expiry (`0xC0000071`) and account disabled (`0xC0000072`) as causes.
- **~27-second retry intervals** between the three Event 4625 failures are inconsistent with manual typing — this cadence is characteristic of an automated credential retry (Credential Manager, mapped drive, or background process).
- **Logon Type 2 (Interactive)** confirms all attempts originated from a local interactive session on DESKTOP-FB022, not a remote or service logon.
- **Event 4624 at 09:09:01** — successful logon immediately after account unlock confirms the credential itself was not the ongoing issue; removing the stale stored entry resolved the retry loop.

---

## 5. Root Cause

A stale credential stored in Windows Credential Manager on DESKTOP-FB022 was submitting an incorrect (outdated) password for `FINBRIDGE\cthompson` automatically on login. This triggered three consecutive failed authentication attempts at a regular ~27-second interval against the domain controller, reaching the 3-attempt lockout threshold and locking the account at 08:44:56 — before cthompson had the opportunity to log in manually. The account remained locked until `helpdesk-admin` unlocked it at 09:08:14. Once unlocked and the stale credential removed, the user logged in successfully at 09:09:01 with no further issues.

---

## 6. Five Whys Analysis

| # | Why? | Answer |
|---|---|---|
| 1 | Why was cthompson unable to log in to DESKTOP-FB022? | The account was locked out (Event 4740, 08:44:56) after three consecutive wrong-password submissions, preventing any further authentication. |
| 2 | Why were wrong-password credentials being submitted? | A stale credential stored in Windows Credential Manager on DESKTOP-FB022 was automatically retrying with a password that no longer matched cthompson's current AD account password. |
| 3 | Why did the stored credential contain the wrong password? | cthompson's AD password had been changed at some point prior to the incident, but the stored entry in Credential Manager on DESKTOP-FB022 was never updated to reflect the new password. |
| 4 | Why was the outdated credential not updated when the password changed? | Windows does not automatically update saved credentials in Credential Manager when an AD password changes — the user must manually update or remove stored entries. cthompson was not aware of this requirement. |
| 5 | Why was there no safeguard to catch the stale credential before it caused a lockout? | There is no current process to alert users to update saved credentials after a password change, no policy preventing interactive accounts from being saved in Credential Manager, and no monitoring alert for repeated rapid-interval lockout events from a single source. |

**Root cause of the process gap:** No user guidance or policy exists to prevent the saving of domain credentials for interactive accounts in Credential Manager, and no monitoring detects the stale-credential-lockout pattern before it impacts the user.

---

## 7. Immediate Actions Taken

| Action | Time | Outcome |
|---|---|---|
| Stale credential identified and removed from Credential Manager on DESKTOP-FB022 | ~09:00 | Automated retry loop stopped |
| Account unlocked by helpdesk-admin (Event 4722) | 09:08:14 | Account available for authentication |
| cthompson logged in successfully (Event 4624) | 09:09:01 | Service restored; no further lockout observed |

---

## 8. Preventive Actions

| # | Action | Owner | Priority |
|---|---|---|---|
| 1 | **User guidance on Credential Manager after password changes** — publish a Service Desk knowledge article and include a step in the password-change process advising users to open Credential Manager (Control Panel → Credential Manager → Windows Credentials) and remove or update any stored domain credentials immediately after changing their AD password. | Service Desk / Communications | High |
| 2 | **Policy to prevent saving interactive account credentials in Credential Manager** — evaluate applying a Group Policy setting (`Network access: Do not allow storage of passwords and credentials for network authentication`) for standard user accounts to prevent domain credentials being saved at the device level; use dedicated service accounts for any legitimate automated credential requirements. | Platform/GPO team | High |
| 3 | **Monitoring alert for rapid repeated lockout events from a single source** — configure a SIEM or AD audit alert to fire when three or more Event 4625 failures for the same account from the same source workstation occur within a 60-second window. This pattern (stale cached credential retrying) is detectable before the lockout lands and would allow proactive intervention. | Security / Platform team | Medium |
| 4 | **Include Credential Manager check in the standard account-lockout resolution runbook** — when resolving any account lockout, the first step after unlocking should always be to check Credential Manager on the source workstation (identified from Event 4740 caller computer field) for stale entries before returning the ticket to the user. Without this step, the account re-locks immediately and generates a repeat ticket. | Service Desk | Medium |

---

## 9. Lessons Learned

- **Event 4740 caller computer is the fastest diagnostic clue.** The source workstation is logged directly in the lockout event — going to that device first and checking Credential Manager is the single most efficient resolution path for this pattern.
- **Regular retry cadence distinguishes automated from manual failures.** Three failures at ~27-second intervals is not how a human types. Recognising this pattern immediately directs investigation to background processes and stored credentials rather than a forgotten password.
- **Error code `0xC000006A` in Event 4776 is decisive.** It eliminates expired password, disabled account, and UPN issues in a single check — always read the error code, not just the failure reason text.
- **Unlocking without removing the stale credential is incomplete.** An account unlocked while a stale credential is still present on the source device will re-lock within seconds of the user sitting down. Resolution must address both the lock and the cause simultaneously.
