# DEX Signal Analysis — Finance-Win11 Startup Performance Drop

**Date:** 2026-08-12
**Scope reference:** Finance-Win11 (215 devices), median startup time and score, 2026-08-01 to 2026-08-06, compared against IT-Win11 (40 devices, unaffected)

---

## Ranked Likely Causes

### 1) New Defender scan policy added by the security baseline (Most likely)
**Why it fits the evidence:**
- The score drop begins precisely on 2026-08-04, the same day the new security baseline (including an additional Defender scan policy) was deployed — no gap between change and impact.
- Additional antivirus/Defender scanning at boot is one of the most common causes of startup slowdown, as it runs before the desktop becomes usable.
- IT-Win11 did not receive this config change and showed no change in score or startup time over the same period, ruling out a platform-wide patch, network issue, or seasonal/day-of-week effect.

**Fastest check to confirm or eliminate:**
Pull Defender/antivirus scan logs or event log timestamps (Windows Defender operational log) for a sample of Finance-Win11 devices around login time on 2026-08-04 onward, and compare scan duration/CPU usage during startup against pre-08-04 logs.

### 2) New startup script for compliance logging (Second most likely)
**Why it fits the evidence:**
- Deployed in the same overnight change window (2026-08-04, 02:00) as part of the same baseline profile, so it shares the identical timing correlation with the score drop.
- Compliance logging scripts that run synchronously at logon can add delay before the desktop is marked "usable," directly matching the metric being measured (login to usable desktop).
- The unaffected IT-Win11 group did not receive this script and shows no change, supporting a config-specific rather than environmental cause.

**Fastest check to confirm or eliminate:**
Check the startup script's execution mode (synchronous vs asynchronous) in the deployed policy/GPO, and measure the script's own run time on a test Finance-Win11 device to see if it accounts for the ~24-26 second increase.

### 3) Combined/cumulative effect of multiple new baseline components running at once (Least likely as sole cause, but plausible contributor)
**Why it fits the evidence:**
- Both new components (Defender scan policy and compliance script) were bundled into a single profile deployed at the same time, so it's possible neither alone fully explains the ~24-26 second increase, but their combination does.
- Still consistent with timing (2026-08-04) and the clean comparison group (IT-Win11 untouched).
- Ranked third because it's a compound hypothesis rather than a single isolated mechanism, making it harder to test directly and less parsimonious than #1 or #2.

**Fastest check to confirm or eliminate:**
On a small pilot set of Finance-Win11 devices, temporarily disable/roll back one component at a time (first the Defender policy, then the script) and measure startup time after each change to see whether one, both, or neither restores the baseline ~17-18 second startup time.

---

## Note on Ranking Weight
All three causes point to the same root event — the 2026-08-04 02:00 security baseline deployment — because the timing aligns exactly with the score drop and the unaffected IT-Win11 group (no config change) shows flat performance across the same dates. This rules out unrelated causes (e.g., general Windows update, network/infrastructure issue, seasonal effect) and strongly concentrates the investigation on the baseline's two new components.
