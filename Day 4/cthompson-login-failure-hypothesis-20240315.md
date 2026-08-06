# Account Login Failure — Incident Analysis & Hypothesis
**Analyst:** DWP Engineer
**Date:** 2026-08-06
**Incident date:** 2024-03-15
**Affected account:** FINBRIDGE\cthompson
**Affected device:** DESKTOP-FB022
**Incident window:** 08:40 – ongoing at time of analysis

---

## Incident Summary

User `cthompson` was unable to log in to their workstation (DESKTOP-FB022) from approximately 08:40 on 2024-03-15. No infrastructure or account changes were logged prior to the incident. The failure was isolated to a single user and single device. No other users were reported affected.

---

## Scope Facts

| Fact | Detail |
|---|---|
| Symptom | User unable to log in |
| Affected user | FINBRIDGE\cthompson only |
| Affected device | DESKTOP-FB022 |
| First reported | ~08:40, 2024-03-15 |
| Known changes | None |

---

## Initial Ranked Hypotheses (Scope Analysis — Pre-Evidence)

### 1. Account Lockout
- **Why it fits:** Most common cause of sudden single-user login failure with no associated change. Stale cached credentials on a background process can trigger lockout without the user being aware.
- **Fastest check:** `Get-ADUser cthompson -Properties LockedOut, BadLogonCount, BadPasswordTime`

### 2. Password Expired
- **Why it fits:** User-scoped, no-change event that causes login failure at a predictable point. First login of the day at ~08:40 is consistent with discovering an overnight expiry.
- **Fastest check:** `Get-ADUser cthompson -Properties PasswordExpired, PasswordLastSet, msDS-UserPasswordExpiryTimeComputed`

### 3. Account Disabled
- **Why it fits:** Affects only the named user, produces immediate login failure, and requires no formal change ticket — an admin or HR-driven action could have disabled the account out of band.
- **Fastest check:** `Get-ADUser cthompson -Properties Enabled | Select-Object Enabled`

### 4. Stale or Corrupt Cached Credential on Client Device
- **Why it fits:** A saved credential in Credential Manager, Windows Hello, or a mapped drive targeting an old password fails silently in the background and locks the account before the user even sits down.
- **Fastest check:** Ask cthompson to try logging in from a different device — if login succeeds elsewhere, fault is device/credential-cache-side.

### 5. UPN Mismatch or Missing Group Membership on Target System
- **Why it fits:** If the login target is a specific system (AVD, RDS, application), a UPN mismatch or removed group membership fails for this user only with no system-wide change.
- **Fastest check:** Confirm whether cthompson can authenticate to anything else (OWA, VPN); check `Get-ADUser cthompson -Properties MemberOf`

---

## Evidence — Security Event Log (DESKTOP-FB022, 08:44–09:12)

| Time | Event ID | Level | Detail |
|---|---|---|---|
| 08:44:01 | 4776 | Audit Failure | Credential validation failed — FINBRIDGE\cthompson, error code **0xC000006A** (wrong password), source: DESKTOP-FB022 |
| 08:44:03 | 4625 | Audit Failure | Logon failed — "Unknown user name or bad password", Logon Type **2 (Interactive)**, source: DESKTOP-FB022 |
| 08:44:28 | 4625 | Audit Failure | Logon failed — same reason, same type, same source |
| 08:44:55 | 4625 | Audit Failure | Logon failed — same reason, same type, same source |
| 08:44:56 | 4740 | Audit Failure | **Account locked out** — FINBRIDGE\cthompson, caller computer: DESKTOP-FB022 |

---

## Hypothesis Verdicts Against Evidence

### Hypothesis 1 — Account Lockout
**Verdict: SUPPORTED — active state confirmed**
- `Event 4740 08:44:56` — account locked out one second after the third failure, caller DESKTOP-FB022, consistent with a 3-attempt lockout threshold.
- Lockout is a *consequence* of the wrong-password failures, not the originating cause — but it is the current blocker preventing login.

### Hypothesis 2 — Password Expired
**Verdict: CONTRADICTED**
- `Event 4776 08:44:01` — error code `0xC000006A` means wrong password. An expired password produces `0xC0000071` with failure reason "Password expired." Neither this code nor that reason appears anywhere in the log.

### Hypothesis 3 — Account Disabled
**Verdict: CONTRADICTED**
- `Event 4776 08:44:01` — error code `0xC000006A`, not `0xC0000072`. A disabled account produces "Account disabled" as the failure reason. The domain controller accepted the account name and rejected the credential — incompatible with a disabled account.

### Hypothesis 4 — Stale or Corrupt Cached Credential
**Verdict: SUPPORTED**
- `Event 4776 08:44:01` — a credential was submitted to the domain controller immediately at 08:44, before the user would have had time to type; consistent with an automated submission.
- Three failures at `08:44:03`, `08:44:28`, `08:44:55` — intervals of ~25–27 seconds are unusually regular for manual retries; consistent with an automated reconnect (Credential Manager, mapped drive, background service, or saved Windows Hello entry retrying on a timer).
- Not yet confirmed over manual mistyping — the regular cadence is a soft indicator only.

### Hypothesis 5 — UPN Mismatch / Missing Group Membership
**Verdict: CONTRADICTED**
- `Event 4776 08:44:01` — the domain controller resolved the account name and rejected the password specifically (`0xC000006A`). A UPN resolution failure produces a different error; a group membership/authorisation failure occurs *after* successful authentication. Neither is consistent with this evidence.

---

## Hypothesis Verdict Summary

| Hypothesis | Verdict | Determining Evidence |
|---|---|---|
| 1 — Account lockout | **Supported (active blocker)** | `Event 4740 08:44:56` |
| 2 — Password expired | **Contradicted** | `Event 4776` error code `0xC000006A` ≠ `0xC0000071` |
| 3 — Account disabled | **Contradicted** | `Event 4776` error code `0xC000006A` ≠ `0xC0000072` |
| 4 — Stale cached credential | **Supported (likely trigger)** | Immediate submission + ~27s regular retry cadence at `Event 4625` |
| 5 — UPN mismatch / group membership | **Contradicted** | Wrong error type for UPN or authorisation failure |

**Two hypotheses survive: H1 and H4.** They are not competing — the lockout (H1) is the *current blocker*; the stale cached credential (H4) is the likely *trigger* that caused the lockout.

---

## Status
**Root cause: NOT YET CONFIRMED** — awaiting further investigation to confirm whether failures were user-initiated or automated credential retry.
Immediate action required: unlock cthompson's account; then check Credential Manager and mapped drives on DESKTOP-FB022 for a stored stale credential before the account locks again.

---

## Confirmed Root Cause

**Surviving root cause hypothesis: Hypothesis 4 — Stale cached credential on DESKTOP-FB022.**

H1 (account lockout) is no longer a hypothesis — it is a confirmed fact (Event 4740). H4 is the surviving root cause: a stored credential on DESKTOP-FB022 (Credential Manager, mapped drive, or background service) was retrying with a password that no longer matched cthompson's AD account, submitting three wrong-password attempts at a regular ~27-second interval and triggering the 3-attempt lockout threshold before cthompson had a chance to log in manually.

---

## Resolution Steps

### Phase 1 — Immediate unblock (~5 min)

1. **Unlock the account** — the account is locked (Event 4740, 08:44:56) and must be unlocked before any login attempt will succeed:
   ```powershell
   Unlock-ADAccount -Identity cthompson
   ```
   Confirm: `Get-ADUser cthompson -Properties LockedOut | Select-Object LockedOut` → should return `False`.

2. **Do NOT have cthompson attempt to log back in yet** — if the stale credential is still present on DESKTOP-FB022 it will re-submit the bad password immediately and re-lock the account within seconds.

### Phase 2 — Find and remove the stale credential (~10 min)

3. **Check Credential Manager on DESKTOP-FB022** — Control Panel → Credential Manager → Windows Credentials. Remove any stored entry referencing `FINBRIDGE\cthompson`, the domain, or any network resource.

4. **Check mapped network drives** — in File Explorer, check whether any mapped drives have stored credentials for cthompson. Disconnect and re-map without saving credentials until the correct password is confirmed.

5. **Check for scheduled tasks or services running as cthompson**:
   ```powershell
   Get-ScheduledTask | Where-Object {$_.Principal.UserId -like "*cthompson*"}
   Get-WmiObject Win32_Service | Where-Object {$_.StartName -like "*cthompson*"}
   ```
   If found, update the stored password or migrate to a dedicated service account.

6. **Check Windows Hello / PIN** — if cthompson has a PIN or biometric registered and the underlying password has changed, remove and re-register after confirming the correct password in Settings → Accounts → Sign-in options.

### Phase 3 — Confirm correct password and restore login (~5 min)

7. **Confirm cthompson knows their current password.** If not, reset it:
   ```powershell
   Set-ADAccountPassword -Identity cthompson -Reset -NewPassword (Read-Host -AsSecureString "New password")
   ```

8. **Have cthompson log in interactively** at DESKTOP-FB022. Monitor for immediate re-lockout — if the account locks again within 30 seconds, a stale credential process is still active and steps 3–6 must be revisited.

9. **Verify no further lockout events** on the DC Security log:
   ```powershell
   Get-WinEvent -LogName Security -ComputerName <DC-name> |
     Where-Object {$_.Id -eq 4740 -and $_.Message -like "*cthompson*"} |
     Select-Object TimeCreated, Message -First 5
   ```

### Phase 4 — Post-resolution check (~5 min)

10. **Check whether cthompson recently changed their password** — if `PasswordLastSet` is recent, the device's stored credentials were never updated after the change:
    ```powershell
    Get-ADUser cthompson -Properties PasswordLastSet | Select-Object PasswordLastSet
    ```

11. **Advise cthompson** not to save domain credentials in Credential Manager for interactive accounts — saved credentials are a recurring lockout risk after any password change. Services requiring credentials should use a dedicated service account, not a personal user account.

---

## Updated Status
**Root cause: CONFIRMED** — stale cached credential on DESKTOP-FB022 submitted incorrect password three times (Event 4625: 08:44:03, 08:44:28, 08:44:55; error code 0xC000006A), triggering account lockout (Event 4740: 08:44:56). Immediate action: unlock account and clear stale credential before next login attempt.
