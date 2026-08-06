# Root Cause Analysis — AVD Black Screen Post-Login
## POOL-FIN-01 | 2024-03-15

**Document prepared by:** DWP Engineer
**Date prepared:** 2026-08-06
**Incident date:** 2024-03-15
**Incident window:** 07:00 – 10:00
**Resolution confirmed:** 10:00
**Severity:** High — ~40% of Finance AVD users unable to maintain a usable desktop session
**Status:** RESOLVED

---

## 1. Incident Summary

On the morning of 2024-03-15, approximately 40% of users on the Finance AVD host pool (POOL-FIN-01) experienced a black screen immediately after logging in. For some users the screen recovered after ~30 seconds; for others the black screen persisted indefinitely, requiring a support call. The IT AVD pool (POOL-FIN-02) was completely unaffected throughout the incident.

The incident was caused by an incompatible Intel GPU driver (`igdumd64.dll` v31.0.101.4146) introduced into the POOL-FIN-01 session host image during an overnight update at 02:00. This driver caused the Desktop Window Manager (`dwm.exe`) to crash on every user session logon, producing the black screen symptom. The issue was resolved by rolling back POOL-FIN-01 session hosts to the pre-update image (`build-20240313`) and re-brokering users to the restored hosts.

---

## 2. Affected Systems and Users

| Item | Detail |
|---|---|
| Affected host pool | POOL-FIN-01 (Finance) |
| Affected session hosts | All hosts updated overnight — confirmed via boot timestamp 02:03:11 |
| Unaffected host pool | POOL-FIN-02 (IT) — not included in the overnight update wave |
| Affected users | ~40% of POOL-FIN-01 users (partial broker distribution across updated hosts) |
| First reporter | Maria Lopez, Finance (ext 4421) |
| Business impact | Finance team unable to access AVD desktops during morning peak; work interrupted, some users required support calls to recover |

---

## 3. Timeline of Events

| Time | Event |
|---|---|
| **2024-03-14 ~close of business** | POOL-FIN-01 image update scheduled for overnight maintenance window |
| **2024-03-15 02:00** | Overnight image update deployed to POOL-FIN-01 session hosts |
| **02:03:11** | SHFIN-01-A (and other updated hosts) restart — confirmed by Kernel-General Event 1 |
| **07:00** | Finance users begin logging in to AVD for the working day |
| **07:02:10** | FINBRIDGE\mlopez logs on to SHFIN-01-A — Session 3 (Event 21) |
| **07:02:16** | `dwm.exe` crashes on SHFIN-01-A — faulting module `igdumd64.dll` v31.0.101.4146 (Event 1000) |
| **07:02:17** | mlopez session disconnected (Event 40) |
| **07:02:18** | Desktop Window Manager exits with code 0x40010004 (Event 9009) — black screen |
| **07:02:44** | AVD auto-reconnects mlopez — Session 3 (Event 21) |
| **07:02:46** | `dwm.exe` crashes again — same faulting module (Event 1000) |
| **07:02:47** | mlopez session disconnected again (Event 40) |
| **07:03:01** | DWM exits again (Event 9009) |
| **07:03:10** | mlopez successfully lands a session on second reconnect — Session 4 (Event 21) |
| **07:08:22** | FINBRIDGE\akapoor logs on to SHFIN-01-A — Session 5 (Event 21) |
| **07:08:24** | `dwm.exe` crashes again for akapoor — same faulting module (Event 1000) |
| **07:18** | Incident formally logged by Maria Lopez via Service Desk |
| **~07:18 onwards** | DWP engineer begins triage; scope confirmed to POOL-FIN-01 only; POOL-FIN-02 confirmed clean |
| **~07:30** | Overnight image update identified as the change correlating with incident scope |
| **~07:45** | Event log review confirms `dwm.exe` crash on `igdumd64.dll` as root cause; resolution plan agreed |
| **~08:00** | POOL-FIN-01 updated session hosts placed into Drain mode; affected users force-logged off and re-brokered |
| **~08:30** | Rollback to pre-update image (`build-20240313`) initiated on POOL-FIN-01 session hosts |
| **~09:30** | Rebuilt hosts verified clean — Event 9011 (DWM started successfully) confirmed, no Event 1000 |
| **10:00** | Drain mode lifted; users logging in to POOL-FIN-01 without issues; incident resolved |

---

## 4. Supporting Evidence

### 4.1 Event Log Evidence — SHFIN-01-A (Affected Host)

| Time | Event ID | Source | Level | Significance |
|---|---|---|---|---|
| 07:02:10 | 21 | TerminalServices-LocalSessionManager | Info | Session logon succeeded — profile loaded, authentication passed; confirms issue is post-logon |
| 07:02:14 | 1 | Kernel-General | Info | Boot time 02:03:11 — confirms host restarted during overnight update window |
| 07:02:16 | 1000 | Application Error | Error | `dwm.exe` crash — faulting module `igdumd64.dll` v31.0.101.4146, exception 0xc0000005 (access violation) |
| 07:02:17 | 40 | TerminalServices-LocalSessionManager | Info | Session disconnected — direct consequence of DWM crash |
| 07:02:18 | 9009 | Desktop Window Manager | Error | DWM exited with code 0x40010004 — compositor down, desktop unrenderable (black screen) |
| 07:02:44 | 21 | TerminalServices-LocalSessionManager | Info | AVD auto-reconnect — session re-established |
| 07:02:46 | 1000 | Application Error | Error | `dwm.exe` crashes again on reconnect — same faulting module; confirms persistent driver fault not a transient event |
| 07:02:47 | 40 | TerminalServices-LocalSessionManager | Info | Session disconnected again |
| 07:03:01 | 9009 | Desktop Window Manager | Error | DWM exits again — crash loop confirmed |
| 07:03:10 | 21 | TerminalServices-LocalSessionManager | Info | Second reconnect — mlopez lands stable session (DWM eventually stabilised on retry) |
| 07:08:22 | 21 | TerminalServices-LocalSessionManager | Info | Second user (akapoor) logs on — confirms issue not isolated to one user |
| 07:08:24 | 1000 | Application Error | Error | `dwm.exe` crashes for akapoor — same faulting module; confirms host-wide fault |

### 4.2 Event Log Evidence — SHFIN-02-A (Unaffected Host, Pre-Update Image build-20240313)

| Time | Event ID | Source | Level | Significance |
|---|---|---|---|---|
| 07:01:44 | 21 | TerminalServices-LocalSessionManager | Info | Session logon succeeded — FINBRIDGE\bwalker |
| 07:01:46 | 9011 | Desktop Window Manager | Info | DWM started successfully — clean baseline; no Event 1000 in entire window |

**No Application Error (Event 1000) or DWM exit (Event 9009) events recorded on SHFIN-02-A during the incident window.**

### 4.3 Scope Correlation

| Factor | POOL-FIN-01 (Affected) | POOL-FIN-02 (Unaffected) |
|---|---|---|
| Overnight image update | YES — applied 02:00 | NO — excluded from update wave |
| Host boot time | 02:03:11 (post-update) | Pre-update (no overnight reboot) |
| `igdumd64.dll` version | 31.0.101.4146 (new) | Pre-update version |
| `dwm.exe` Event 1000 | YES — multiple users | NO |
| DWM Event 9009 | YES | NO |
| DWM Event 9011 | NO | YES |
| Users affected | ~40% (those brokered to updated hosts) | 0% |

---

## 5. Root Cause

The overnight image update deployed to POOL-FIN-01 on 2024-03-15 at 02:00 introduced an incompatible Intel GPU display driver (`igdumd64.dll` v31.0.101.4146). On each user session logon, the Desktop Window Manager (`dwm.exe`) — the Windows compositor responsible for rendering the desktop — loaded this driver and immediately crashed with an access violation (exception code 0xc0000005). The crash produced a black screen because no compositor was running to render the desktop surface. AVD's auto-reconnect mechanism restarted the session, but DWM crashed again on each attempt, creating a crash loop. Users who eventually recovered did so by chance on a retry when DWM briefly stabilised; users who did not recover remained in the loop until force-logged off.

POOL-FIN-02 was unaffected because it was not included in the update wave and continued running the pre-update image (`build-20240313`) in which the driver was not present.

---

## 6. Five Whys Analysis

| # | Why? | Answer |
|---|---|---|
| 1 | Why were Finance users seeing a black screen after AVD login? | Desktop Window Manager (`dwm.exe`) crashed immediately after logon, removing the compositor and leaving the session with a blank display surface. |
| 2 | Why did `dwm.exe` crash on logon? | It loaded an incompatible Intel GPU driver (`igdumd64.dll` v31.0.101.4146) which caused an access violation (0xc0000005) in the DWM process. |
| 3 | Why was this incompatible driver present on the session hosts? | The overnight image update applied to POOL-FIN-01 at 02:00 included the driver — either via a Windows Update OEM driver package or a driver catalog pull during the image build process. |
| 4 | Why did the incompatible driver reach a production host pool without being caught? | The image build and deployment pipeline had no post-update smoke test step to verify that a user session rendered a desktop successfully before fleet rollout. The update was deployed directly to all POOL-FIN-01 production hosts. |
| 5 | Why was there no smoke test in the deployment pipeline? | The image release process did not include a mandatory canary validation stage — there was no policy or checklist requirement to test a live session on one host before promoting the image to the full pool. |

**Root cause of the process failure:** Absence of a canary host validation step in the AVD image release pipeline allowed a driver regression to reach 100% of production session hosts in a single deployment.

---

## 7. Immediate Actions Taken

| Action | Time | Outcome |
|---|---|---|
| Updated POOL-FIN-01 hosts placed into Drain mode | ~08:00 | Stopped new sessions brokering to affected hosts |
| Affected users force-logged off via Azure Portal | ~08:00 | Users re-brokered; those landing on any remaining clean hosts recovered |
| Rollback to pre-update image `build-20240313` initiated | ~08:30 | New session hosts deployed from clean image |
| Rebuilt hosts verified via Event 9011 (DWM clean start) | ~09:30 | Confirmed no Event 1000 on rebuilt hosts |
| Drain mode lifted; POOL-FIN-01 returned to production | 10:00 | Users logging in normally; no further reports |

---

## 8. Preventive Actions

| # | Action | Owner | Priority |
|---|---|---|---|
| 1 | **Add mandatory canary host validation to image release pipeline** — before any production fleet rollout, deploy the new image to a single canary session host, log in a test account, and confirm `Event 9011` (DWM started successfully) with no `Event 1000` for `dwm.exe`. Rollout to the fleet is blocked until this gate passes. | Image/Platform team | Critical |
| 2 | **Implement staged rollout for host pool image updates** — deploy new images to a percentage of hosts (e.g. 10–20%) first, monitor for DWM errors and user session quality for a defined soak period before completing the rollout. | Image/Platform team | High |
| 3 | **Pin or exclude OEM GPU driver updates from AVD image builds** — AVD session hosts use virtual GPU adapters in most configurations; OEM display drivers (such as Intel `igdumd64.dll`) are typically not required and should be excluded from the image build pipeline or pinned to a validated version. | Image/Platform team | High |
| 4 | **Separate update waves by pool with a mandatory gap** — POOL-FIN-01 and POOL-FIN-02 should never be updated in the same overnight window. Staggering updates with a minimum 24-hour gap between pools ensures an unaffected reference pool is always available and that production impact is limited to one pool at a time. | Change Management | High |
| 5 | **Add DWM health check to post-deployment automated testing** — after each session host image deployment, run an automated check querying Event 9009 and Event 1000 for `dwm.exe` in the first 10 minutes of operation. Alert and auto-drain the host if either event is detected. | Platform/Automation team | Medium |
| 6 | **Document image build driver sourcing** — maintain a record of driver versions included in each image build so that regressions can be identified immediately by diffing the current and previous build manifests. | Image/Platform team | Medium |

---

## 9. Lessons Learned

- **The pool boundary was the key diagnostic clue.** POOL-FIN-02 being completely unaffected immediately eliminated all shared-infrastructure causes (Azure AD, Conditional Access, network, gateway) and pointed directly to the image update as the change vector. Scope analysis before log review significantly accelerated diagnosis.
- **`dwm.exe` Event 9009 is a definitive black screen indicator.** When DWM exits, the desktop compositor is gone and the user sees black. Any investigation into AVD black screen symptoms should check for Event 9009 and Event 1000 for `dwm.exe` as the first log check.
- **A crash loop is diagnostically different from a hang.** The repeating logon → crash → disconnect → reconnect pattern in the logs ruled out FSLogix, GPO scripts, and AppX issues early and pointed specifically to a component crash in the rendering stack.
- **Automated reconnect masked the severity.** AVD's reconnect behaviour meant some users recovered after ~30 seconds, which could have led to under-reporting. The incident scope (~40%) was only understood by correlating multiple tickets, not from the first user report alone.
