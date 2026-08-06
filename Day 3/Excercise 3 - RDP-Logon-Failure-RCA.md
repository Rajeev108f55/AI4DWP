# RDP Connection Failure — Root Cause Analysis

**Document prepared by:** DWP Analyst
**Date prepared:** 2026-08-05
**Incident date (per logs):** 2024-03-15
**Affected account:** FINBRIDGE\bwalker
**Source client IP:** 10.10.5.44
**Affected service:** Remote Desktop (RDP)

---

## 1. Event ID Reference

| Event ID | Source | Level | Records | Notes for this incident |
|---|---|---|---|---|
| **56** | TermDD | Error | The Terminal Server security layer detected an error in the protocol stream and disconnected the client. | Occurred at the exact same second as the first bad-password warning (14:01:02). This is a protocol/transport-level event, distinct from credential validation — flagged as a possible separate issue, not assumed to share the same cause as the password failures. |
| **140** | RemoteDesktopServices-RdpCoreTS | Warning | An RDP connection failed because the username or password was incorrect. | RDP-specific companion to the Security log's 4625 events. |
| **4625** (×3) | Security | Audit Failure | A logon failed. Records account, failure reason, logon type, and source IP. | All three (14:01:04, 14:03:18, 14:05:33) are Logon Type **10 (RemoteInteractive)** — i.e., RDP — from the same account and source IP, with an unusually regular ~2-minute interval between each. |
| **4740** | Security | Audit Failure | A user account was locked out. Records the account and the caller computer that triggered it. | Locked out one second after the third failure, consistent with a 3-attempt lockout threshold. |
| **131** | RemoteDesktopServices-RdpCoreTS | Info | A new TCP connection was accepted from a client. | Not an error — simply the next connection attempt beginning, ~16.5 minutes after the lockout. |
| **4624** | Security | Audit Success | A successful logon. Records account, logon type, and source. | Confirms `bwalker` successfully authenticated via RDP two seconds after the new connection was accepted. |

---

## 2. Reconstructed Sequence of Events (Plain English)

1. **14:01:02** — Two events logged simultaneously: `TermDD` Event 56 disconnected the client due to a protocol stream error, and `RdpCoreTS` Event 140 logged a bad username/password from the same source IP (10.10.5.44). This simultaneity is unusual and is treated as a separate line of investigation below, not assumed to be the same fault.
2. **14:01:04** — The Security log records the first failed logon (`4625`) for `bwalker` via RDP (Logon Type 10), reason "Unknown username or bad password."
3. **14:03:18** — A second identical failure, ~2 minutes 14 seconds later.
4. **14:05:33** — A third identical failure, ~2 minutes 15 seconds later — a notably regular cadence across all three attempts.
5. **14:05:34** — The account was locked out (`4740`), one second after the third failure, consistent with a 3-attempt lockout threshold.
6. **14:22:07** — Roughly 16.5 minutes later, a new TCP connection was accepted from the same client IP (`131`).
7. **14:22:09** — `bwalker` successfully logged on via RDP (`4624`), two seconds after the new connection.

**Gap in evidence:** no unlock event (`4767`/`4722`) appears in this excerpt between the lockout (14:05:34) and the successful logon (14:22:09). This should not be assumed away — verify whether the account lockout duration policy auto-unlocked the account after ~16–17 minutes, or whether a manual unlock occurred that simply wasn't included in these "relevant lines."

---

## 3. Most Likely Cause (with Evidence)

**Most likely cause:** `bwalker`'s RDP client at 10.10.5.44 repeatedly submitted a stale or incorrect cached password, tripping the account lockout threshold. The account then became usable again (via policy auto-unlock or an unlogged manual unlock) and the very next attempt succeeded cleanly.

**Supporting evidence:**
- All three failures share the same account, logon type (10 = RemoteInteractive/RDP), source IP, and failure reason — a straightforward credential-mismatch pattern, not a mix of different error types that might suggest a broader issue.
- The successful logon at 14:22:09 required no further retries, meaning once the correct state was reached (correct password and/or unlocked account), authentication worked immediately — consistent with a resolved credential issue rather than an ongoing external problem.

**Anomalies flagged for separate investigation (not confirmed to share the same root cause):**
- **Event 56** (protocol stream error) coincided exactly with the first bad-password warning. Event 56 is typically associated with network instability, client/server security-layer (NLA/TLS) mismatches, or malformed/non-standard connection attempts — **not** normally a symptom of a bad password. This should be investigated on its own merits (network path, RDP client version, security layer configuration) rather than assumed to be caused by the same issue as the lockout.
- **The retry interval is unusually uniform** (~2m14s, ~2m15s), which is more characteristic of an automated reconnect (e.g., a saved `.rdp` shortcut, mapped drive, or scheduled task retrying on a timer) than typical manual human retry behavior. This is a soft indicator only — it does not, by itself, confirm automation or malicious activity.
- Source IP 10.10.5.44 is an internal/private address; it should still be confirmed as `bwalker`'s expected workstation rather than assumed.

---

## 4. Five Whys Analysis

| # | Why? | Answer |
|---|---|---|
| 1 | Why was `bwalker` unable to connect via RDP? | The account was locked out after three consecutive failed logon attempts using an incorrect password, from 14:01 to 14:05. |
| 2 | Why were the logon attempts using an incorrect password? | The credentials submitted from the client at 10.10.5.44 did not match the account's current password on three consecutive tries, at a notably regular ~2-minute interval. |
| 3 | Why would the same incorrect credential be resubmitted at such a regular interval? | This pattern is more consistent with an automated or saved-credential reconnect (e.g., a cached credential in Credential Manager, a saved `.rdp` file, or a scheduled task) than manual retyping — **not confirmed**, requires checking Credential Manager and scheduled tasks on 10.10.5.44. |
| 4 | Why did a protocol-layer error (Event 56) also occur at the same moment as the first failure? | This may be coincidental (a separate network/client-compatibility issue on 10.10.5.44) or it may indicate a non-standard connection attempt — the evidence in this excerpt is insufficient to determine which, and it should be investigated independently rather than folded into the credential root cause. |
| 5 | Why did the account become usable again ~16 minutes later without an unlock event in this excerpt? | Most likely the account lockout duration policy auto-unlocked it after the configured interval, and the client then authenticated successfully with a corrected/refreshed credential — **not fully confirmed**, verify against the domain's lockout duration policy and check the full Security log for any unlock event not captured in this excerpt. |

**Root cause:** A stale or incorrect cached RDP credential from the client at 10.10.5.44 caused three consecutive failed logons for `bwalker`, triggering an AD account lockout; the account subsequently became available again (auto-unlock or unlogged manual unlock) and the next connection succeeded with a valid credential. The co-occurring protocol stream error (Event 56) is a separate anomaly that has not been confirmed to share this root cause and warrants independent investigation.

---

## 5. Recommendations

1. **Check Credential Manager and any saved `.rdp` files or scheduled tasks on 10.10.5.44** for a stored/stale credential targeting the RDP host — the most likely source of the repeated, regularly-spaced bad-password attempts.
2. **Confirm whether `bwalker`'s password recently changed** (`Get-ADUser bwalker -Properties PasswordLastSet`, and check for `4723`/`4724` events preceding the incident) to determine if the client simply had an outdated cached credential.
3. **Investigate the Event 56 protocol stream error independently** — check network stability, RDP client version on 10.10.5.44, and any Group Policy governing RDP security layer/NLA settings. **Verify against Microsoft's official TermDD/Event 56 documentation** before concluding a specific cause.
4. **Confirm the account lockout policy's duration/threshold** (`Get-ADDefaultDomainPasswordPolicy` or applicable fine-grained policy) and check the full Security log for any unlock event (`4767`/`4722`) between 14:05 and 14:22 that wasn't included in this excerpt.
5. **Confirm device identity behind 10.10.5.44** via DHCP/asset records to verify it is `bwalker`'s expected workstation.
6. **Monitor for a broader pattern** — given the unusually regular retry cadence, do a quick SIEM check for similar Logon Type 10 failures against other accounts from the same or nearby IPs to rule out a wider automated issue, even though nothing in this excerpt currently indicates one.
