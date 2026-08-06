# Known-Error Record — Account Lockout via Stale Cached Credential
**Knowledge Base Reference:** Known-Error-AD-001
**Date raised:** 2026-08-06
**Source incident:** FINBRIDGE\cthompson, DESKTOP-FB022, 2024-03-15
**RCA document:** RCA-cthompson-login-failure-20240315.md
**Status:** Verified

---

**Symptom:**
User is unable to log in to their workstation and receives a login failure message. The account may have been locked before the user made any manual login attempt, or locks immediately on the first try without the user entering a wrong password.

**Cause:**
A stale credential stored in Windows Credential Manager on the user's device automatically retried an outdated domain password at regular intervals (~27 seconds), submitting three wrong-password attempts (error code `0xC000006A`) against the domain controller and triggering the 3-attempt account lockout threshold. The stored credential was not updated after a prior AD password change.

**Scope:**
Affects any single user whose device has a saved domain credential in Windows Credential Manager that has not been updated following an AD password change. In the source incident one user (FINBRIDGE\cthompson) on one device (DESKTOP-FB022) was affected; no other users or systems were impacted.

**Workaround:**
Before unlocking the account, go to the source device identified in Event 4740 (caller computer field) and remove the stale entry from Credential Manager (Control Panel → Credential Manager → Windows Credentials). Then unlock the account: `Unlock-ADAccount -Identity <username>`. Unlocking without first removing the stale credential will cause immediate re-lockout.

**Permanent fix:**
Publish user guidance instructing staff to open Credential Manager and remove or update stored domain credentials immediately after any AD password change. Evaluate applying a Group Policy setting to prevent interactive accounts from saving domain credentials in Credential Manager, and use dedicated service accounts for any process that legitimately requires stored credentials.

**How to spot it:**
On the domain controller Security log, look for three or more Event ID **4625** failures for the same account from the same source workstation within 60 seconds, with Event ID **4776** showing error code `0xC000006A` (wrong password) — not `0xC0000071` (expired) or `0xC0000072` (disabled). This is followed immediately by Event ID **4740** (account locked out) with the caller computer field identifying the source device. The ~27-second retry interval between failures and the absence of any manual login attempt by the user are the key distinguishing signals.
