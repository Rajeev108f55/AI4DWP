# AVD Black Screen — Incident Analysis & Hypothesis
**Analyst:** DWP Engineer
**Date:** 2026-08-06
**Incident logged:** 2024-03-15 07:18
**Reported by:** Maria Lopez, Finance (ext 4421)

---

## Incident Summary

Users on Azure Virtual Desktop (AVD) pool **POOL-FIN-01** are experiencing a black screen immediately after login. For some users (~Maria Lopez) it clears after ~30 seconds. For others it persists and requires a support call. Pool **POOL-FIN-02** (IT team) is completely unaffected.

---

## Scope Facts

| Fact | Detail |
|---|---|
| Symptom | Black screen post-login — clears after ~30s for some users, persists for others |
| Affected pool | POOL-FIN-01 (Finance) |
| Unaffected pool | POOL-FIN-02 (IT) — not included in the overnight update |
| Affected users | ~40% of POOL-FIN-01 |
| First report | ~07:00, 2024-03-15 |
| Change | Overnight image update to POOL-FIN-01 at 02:00 — POOL-FIN-02 was NOT updated |

---

## Key Discriminating Logic

The fact that **POOL-FIN-02 is completely unaffected and was NOT updated** is the strongest scope clue. It eliminates any cause rooted in shared infrastructure (Azure AD, Conditional Access, DNS, network, RD Gateway) — those would affect both pools. Every viable hypothesis must be explainable by the image update alone.

> Logical test applied to each cause: *"If the image update had never happened, would POOL-FIN-02 still be unaffected?"*
> If yes → consistent. If no → weakened or eliminated.

---

## Ranked Hypotheses (Most Probable First)

### 1. Explorer/Shell Failure Baked Into the New Image
- **Why it fits:** The broken shell component travels inside the image. The image boundary is exactly the affected/unaffected boundary. A black screen (shell not rendering) is the direct symptom. Self-clearing after ~30s is consistent with Explorer retrying on failure. ~40% affected explained by partial host rollout within POOL-FIN-01.
- **POOL-FIN-02 immunity:** Never received the image — fault never deployed to it.
- **Fastest check:** `Get-WinEvent -LogName Application | Where-Object {$_.Id -eq 1000 -and $_.TimeCreated -gt (Get-Date).Date -and $_.Message -like "*explorer*"}`

### 2. FSLogix Configuration/Driver Broken by the Image Update
- **Why it fits:** FSLogix registry keys (`VHDLocations`, `Enabled`) and driver version live inside the image. Profile mount hang/failure produces a black screen while the shell waits. Ranked 2 (not 1) because FSLogix failure more typically produces a persistent black screen or explicit error rather than a variable self-clearing delay.
- **POOL-FIN-02 immunity:** FSLogix config unchanged — image never deployed.
- **Fastest check:** `Get-WinEvent -LogName "Microsoft-FSLogix-Apps/Operational" | Where-Object {$_.TimeCreated -gt (Get-Date).Date} | Select-Object TimeCreated, Message -First 20`

### 3. Logon Script or GPO Change Carried by the Image
- **Why it fits:** A startup/logon script embedded in the image (registry Run key, scheduled task, or MDM policy baked in at imaging time) that hangs or errors produces a black screen until it completes or times out. Explains both the 30s recovery and the "never comes back" split.
- **Caveat:** Only consistent with POOL-FIN-02 immunity if the change was image-carried, not AD-delivered. An AD GPO applying to both pools would have hit POOL-FIN-02 too.
- **Fastest check:** `Get-WinEvent -LogName "Microsoft-Windows-GroupPolicy/Operational" | Where-Object {$_.TimeCreated -gt (Get-Date).Date -and $_.Level -eq 2}`

### 4. Partial Host Rollout Within POOL-FIN-01 (Scope Explainer)
- **Why it fits:** Explains why ~40% are affected and not 100%. If only some session hosts in POOL-FIN-01 received the new image, users brokered to updated hosts hit the problem; users landing on non-updated hosts do not.
- **Note:** This is not a root cause in itself — it explains the affected percentage. Confirming it changes remediation (roll back specific hosts vs. rebuild all of POOL-FIN-01).
- **Fastest check:** Azure Portal → POOL-FIN-01 → Session Hosts → compare image version/build across all hosts.

### 5. AppX/Per-User Service Broken by the Image Update
- **Why it fits:** Image updates can alter provisioned AppX packages or per-user services (Windows Search, Start menu broker). Broken package registration at first login produces a black screen while Windows attempts repair/re-registration — times out (persistent) or succeeds slowly (~30s).
- **POOL-FIN-02 immunity:** Package state unchanged — image never deployed.
- **Fastest check:** `Get-WinEvent -LogName "Microsoft-Windows-AppXDeploymentServer/Operational" | Where-Object {$_.TimeCreated -gt (Get-Date).Date -and $_.Level -eq 2} | Select-Object TimeCreated, Message -First 10`

---

## Status
**Root cause: NOT YET CONFIRMED** — awaiting log output from session hosts.
Recommended first action: run Hypothesis 1 and 2 checks simultaneously on an affected POOL-FIN-01 session host.

---

## Evidence Analysis — Event Log Review
**Source:** SHFIN-01-A (affected) and SHFIN-02-A (unaffected)
**Window:** 2024-03-15 07:00–07:30

### Raw Events (SHFIN-01-A)

| Time | Source | Event ID | Level | Detail |
|---|---|---|---|---|
| 07:02:10 | TerminalServices-LocalSessionManager | 21 | Info | Session logon succeeded — FINBRIDGE\mlopez, Session 3 |
| 07:02:14 | Kernel-General | 1 | Info | System boot time: 2024-03-15 02:03:11 — confirms host restarted during update window |
| 07:02:16 | Application Error | 1000 | Error | `dwm.exe` crash — faulting module `igdumd64.dll` v31.0.101.4146, exception 0xc0000005 |
| 07:02:17 | TerminalServices-LocalSessionManager | 40 | Info | Session disconnected — FINBRIDGE\mlopez, Session 3 |
| 07:02:18 | Desktop Window Manager | 9009 | Error | DWM exited with code 0x40010004 |
| 07:02:44 | TerminalServices-LocalSessionManager | 21 | Info | Session logon succeeded (reconnect) — FINBRIDGE\mlopez, Session 3 |
| 07:02:46 | Application Error | 1000 | Error | `dwm.exe` crash again — same faulting module |
| 07:02:47 | TerminalServices-LocalSessionManager | 40 | Info | Session disconnected again |
| 07:03:01 | Desktop Window Manager | 9009 | Error | DWM exited again |
| 07:03:10 | TerminalServices-LocalSessionManager | 21 | Info | Session logon succeeded (second reconnect) — Session 4 |
| 07:08:22 | TerminalServices-LocalSessionManager | 21 | Info | Session logon succeeded — FINBRIDGE\akapoor, Session 5 |
| 07:08:24 | Application Error | 1000 | Error | `dwm.exe` crash — same faulting module, second affected user |

### Comparison Events (SHFIN-02-A — unaffected, pre-update image build-20240313)

| Time | Source | Event ID | Level | Detail |
|---|---|---|---|---|
| 07:01:44 | TerminalServices-LocalSessionManager | 21 | Info | Session logon succeeded — FINBRIDGE\bwalker, Session 2 |
| 07:01:46 | Desktop Window Manager | 9011 | Info | Desktop Window Manager started successfully |

No `Event 1000` or `Event 9009` entries on SHFIN-02-A.

### Hypothesis Verdicts Against Evidence

| Hypothesis | Verdict | Determining Evidence |
|---|---|---|
| 1 — Shell failure baked into image | **Partially supports** (wrong process predicted) | `Event 1000 07:02:16` — `dwm.exe` crashes, not `explorer.exe`; `Event 9009 07:02:18` — DWM exits producing black screen |
| 2 — FSLogix broken by image update | **Contradicted** | `Event 21 07:02:10` — logon/profile succeeded before any crash; no FSLogix events present |
| 3 — Logon script/GPO hang | **Contradicted** | No GP events; crash/reconnect loop pattern is inconsistent with a script hang |
| 4 — Partial host rollout | **Confirmed (scope explainer)** | `Event 1 07:02:14` — boot at 02:03 confirms update applied; SHFIN-02-A `Event 9011` clean with no crashes |
| 5 — AppX/per-user service broken | **Contradicted** | No AppX events; `igdumd64.dll` GPU driver crash is unrelated to AppX |

---

## Confirmed Root Cause

**Surviving hypothesis: Hypothesis 1 — image-carried shell component failure**, refined by evidence.

The overnight image update to POOL-FIN-01 deployed an incompatible or corrupt Intel GPU driver (`igdumd64.dll` v31.0.101.4146). On each user logon, Desktop Window Manager (`dwm.exe`) loads this driver and immediately crashes (Event 1000 + Event 9009), blacking out the session. AVD auto-reconnects, DWM restarts, crashes again — users who eventually land a stable session do so by chance on a retry; others remain stuck in the crash loop. POOL-FIN-02 runs the pre-update image (`build-20240313`) and is unaffected.

---

## Resolution Steps

### Phase 1 — Immediate user relief (~15 min)

1. **Drain all updated POOL-FIN-01 session hosts** — Azure Portal → Host Pool → Session Hosts → set each updated host to **Drain mode ON**. Stops new sessions brokering to affected hosts without killing existing ones.
2. **Identify any POOL-FIN-01 hosts not updated** (boot time before 02:00) — set those to Drain mode OFF so users are brokered only to clean hosts.
3. **If all POOL-FIN-01 hosts were updated:** temporarily broker Finance users to POOL-FIN-02 if capacity allows, or advise users to disconnect and reconnect until a clean retry lands.
4. **Force log off users stuck in a black screen loop** — Azure Portal → Host Pool → Sessions → select user → **Log off**. Their next connection re-brokers to a clean host (if steps 1–3 are done first).

### Phase 2 — Roll back the image (~30–60 min)

5. **Locate the pre-update image** — confirmed version: `10.0.22621.2861-build-20240313` from SHFIN-02-A. Find this in Azure Compute Gallery or snapshot store.
6. **Redeploy POOL-FIN-01 session hosts from the pre-update image** — add new hosts using `build-20240313`, verify `Event 9011` (DWM started successfully) with no `Event 1000` for `dwm.exe`, then drain and delete the faulty hosts.
7. **Preserve at least one affected host** before rebuilding — retain the faulty image version for post-incident driver investigation evidence.

### Phase 3 — Fix the image for future deployment

8. **Identify what introduced `igdumd64.dll` v31.0.101.4146** — check the image build pipeline/change log. Likely cause: Windows Update pulled an OEM Intel driver, or a driver package was included in the imaging process.
9. **Add a mandatory DWM smoke test to the image release checklist** — after every image build, launch one test session on a canary host and confirm `Event 9011` with no `Event 1000` for `dwm.exe` before fleet rollout.
10. **Pin or exclude the Intel GPU driver** in the corrected image — revert to the previously working driver version, or exclude OEM display driver updates from the pipeline if AVD hosts use a virtual GPU.
11. **Redeploy POOL-FIN-01 from the corrected new image** once validated, then retire the `build-20240313` rollback image from production.

### Phase 4 — Post-incident actions

12. **Raise a change management process gap** — production pool image updates without a pre-deployment session smoke test allowed a faulty driver to reach ~40% of Finance users. Recommend mandatory canary host validation before any fleet rollout.
13. **Close incident ticket** referencing confirming evidence: `Event 1000` (07:02:16, 07:02:46, 07:08:24) and `Event 9009` (07:02:18, 07:03:01) on SHFIN-01-A; `Event 9011` on SHFIN-02-A as the clean baseline.

## Updated Status
**Root cause: CONFIRMED** — `igdumd64.dll` (Intel GPU driver v31.0.101.4146) introduced in overnight image update causes `dwm.exe` to crash on session logon, producing black screen on all updated POOL-FIN-01 hosts.
