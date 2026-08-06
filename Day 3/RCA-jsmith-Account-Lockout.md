# Root Cause Analysis (RCA) — Account Lockout: jsmith / DESKTOP-FB001

**Document prepared by:** DWP Analyst
**Date prepared:** 2026-08-05
**Incident date:** Not specified in the provided log excerpt (timestamps only, no date) — confirm exact calendar date against the SIEM/Security log export before filing this RCA formally.
**Affected account:** jsmith
**Affected host:** DESKTOP-FB001

---

## 1. Event ID Reference

| Event ID | Records | Notes for this incident |
|---|---|---|
| **4625** | An account failed to log on. Captures the account name, failure reason, source workstation, and logon type for every failed authentication attempt. | Three occurrences: two "Unknown username or bad password" failures, then one "Account locked out" failure. |
| **4740** | A user account was locked out. Records the account that got locked and the computer the lockout was "called from" (i.e., where the triggering failed attempts originated). | Confirms DESKTOP-FB001 as the source of the failed attempts that caused the lockout. |
| **4722** | Standard Windows Security Auditing definition: *"A user account was enabled."* | **Flag for verification** — this event is typically generated when a previously *disabled* account is *enabled*. The action described here ("unlocking" a locked-out account) is normally recorded as **event ID 4767 ("A user account was unlocked")**, not 4722. This discrepancy should be verified against the raw Security log / SIEM field mapping — either the helpdesk admin performed a disable→enable action instead of a standard unlock, or the log source/SIEM is mislabeling 4767 as 4722. Do not assume these are interchangeable without confirming. |
| **4624** | An account successfully logged on. Records the account, logon type, and source. | Confirms jsmith successfully authenticated after the account was reactivated. |

**Logon Type reference used above:**
- **Type 2** = Interactive (logon at the local keyboard/console).
- **Type 7** = Unlock (an attempt to unlock an already-locked workstation session).

---

## 2. Reconstructed Sequence of Events (Plain English)

1. **08:02:14** — jsmith attempted to log on interactively (Type 2) at DESKTOP-FB001 and failed; Windows reported "Unknown username or bad password."
2. **08:04:22** — jsmith attempted the same interactive logon again, roughly 2 minutes later, and failed for the same reason.
3. **08:06:01** — The account lockout policy threshold was reached: jsmith's account was locked out, triggered from DESKTOP-FB001.
4. **08:07:45** — jsmith (or someone at that workstation) tried to unlock the session (Type 7). This attempt failed, but this time the reason given was explicitly "Account locked out" — confirming the account was already in a locked state at this point, not that this attempt caused the lockout.
5. **08:22:10** — Roughly 16 minutes after the lockout, a helpdesk administrator (`FINBRIDGE\helpdesk-admin`) performed an action recorded as event 4722 ("Account enabled") against jsmith's account, restoring access.
6. **08:23:44** — jsmith successfully logged on interactively (Type 2) — confirming the account was usable again and the correct credentials were now being accepted.

---

## 3. Most Likely Cause (with Evidence)

**Most likely cause:** jsmith entered an incorrect or outdated password twice in a row while logging on directly at their own workstation, which reached the account lockout threshold.

**Supporting evidence:**
- Both failed attempts (08:02:14, 08:04:22) are **Logon Type 2 (Interactive)** from **DESKTOP-FB001** — i.e., typed directly at the machine's keyboard, not a remote logon attempt, a mapped drive, or a service account retry (which would show as Type 3 or Type 10, from a different/unexpected source). This points away from an external brute-force attempt and toward a local, user-driven credential mismatch.
- The lockout (4740) is attributed to the same host (DESKTOP-FB001), consistent with the two preceding local failures being the trigger.
- The 08:07:45 attempt was **Type 7 (Unlock)**, which happens when a user tries to unlock an already-in-use, locked screen session — this is consistent with jsmith being physically at their desk and repeatedly trying (and failing) to get back in, rather than an attacker probing the account remotely.

**What we cannot confirm from this excerpt (evidence gaps):**
- **Only two 4625 failures are shown before the lockout.** Depending on the organization's configured lockout threshold (commonly 3, 5, or 10), there may be an additional failed attempt not included in this excerpt, or the threshold in force is unusually low. **Verify the exact "Account lockout threshold" policy value** applied to jsmith (Default Domain Policy or a fine-grained password policy) before finalizing this RCA.
- There is **no 4723 (password change attempt) or 4724 (password reset) event** in the reviewed window, so we cannot confirm whether jsmith's password had recently changed (self-service, expiration, or admin reset) versus a simple typing error (Caps Lock, wrong keyboard layout, muscle-memory of an old password). **Recommend pulling a wider log window (previous 24–72 hours)** for jsmith's account to check for a preceding password change event.
- The 4722 vs. expected 4767 discrepancy noted in Section 1 should be resolved before this cause is treated as final, since it affects confidence in exactly what remediation action the helpdesk admin performed.

---

## 4. Five Whys Analysis

| # | Why? | Answer |
|---|---|---|
| 1 | Why was jsmith's account locked out? | The AD account lockout threshold was reached after two (possibly more) consecutive failed interactive logon attempts with incorrect credentials at DESKTOP-FB001 between 08:02 and 08:04. |
| 2 | Why were there repeated failed logon attempts? | The credentials entered at the keyboard (Logon Type 2) did not match jsmith's current account password on at least two consecutive tries. |
| 3 | Why did the entered credentials not match the current password? | Most likely either (a) jsmith was using a stale/cached password following a recent change or expiration, or (b) a manual entry error (typo, Caps Lock, keyboard layout). **Evidence is insufficient to confirm which** — no password-change event (4723/4724) is present in the reviewed window. |
| 4 | Why wasn't the issue caught or corrected before the lockout threshold was reached? | jsmith re-attempted the same (likely incorrect) credential within about 2 minutes without an intermediate check (e.g., Caps Lock indicator, password hint) or a self-service reset option, and the account lockout threshold/observation window in force allowed only a small number of attempts before locking. |
| 5 | Why did it take roughly 16 minutes to restore access? | Restoring access required manual intervention by a helpdesk administrator (event 4722/4767) — there is no evidence of a self-service unlock or password reset mechanism available to jsmith, so resolution time was bound by helpdesk ticket handling rather than an automated process. |

**Root cause:** A local, user-side credential mismatch (stale password or entry error) during an interactive logon triggered the AD lockout policy, and the lack of a self-service unlock/reset option extended the outage until a helpdesk administrator manually intervened roughly 16 minutes later.

---

## 5. Recommendations

1. **Confirm with jsmith** whether their password had recently changed (self-service portal, expiration, or admin-forced reset) around the incident time, to close the evidence gap identified above.
2. **Enable/promote Self-Service Password Reset (SSPR)** so users can unlock their own account or reset a forgotten/expired password without waiting on a helpdesk queue, reducing time-to-resolution for this class of incident.
3. **Review the account lockout policy** (threshold and observation window) applied to jsmith against the organizational security baseline, and confirm it matches expectations — this RCA only observed 2 failures before lockout, which should be reconciled against the configured threshold.
4. **Resolve the 4722 vs. 4767 discrepancy** with the SIEM/log pipeline team to ensure the correct event ID is being captured/mapped for account unlock actions, so future RCAs are built on accurate evidence.
5. **User awareness reminder** (e.g., via IT communications) on checking Caps Lock/keyboard layout before repeated logon attempts, and on responding promptly to password-expiration notifications, to reduce recurrence of similar lockouts.
