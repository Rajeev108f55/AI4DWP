# FinBridge Connect v3.1 — Phased Intune Deployment Plan
**Version:** 1.0 | **Date:** 2026-08-11 | **Status:** Draft  
**Author:** DWP Engineer  
**Deadline:** 2026-09-01 (3 weeks)  
**Fleet:** 10,000 Windows 11 endpoints  
**Reference:** FinBridge-v3.1-Intune-Deployment-Plan.md (initial plan), Guide-Adding-Windows-App-Intune-Catalog.md

---

## 1. Ring Structure

### Ring 0 — Finance Priority (Recommended — see Section 4)

| Field | Detail |
|---|---|
| **Size** | 500 devices (Finance team) |
| **Duration** | Day 1–5 (Week 1) |
| **Who** | Finance department users — highest business priority |
| **Purpose** | Meet the end-of-week-1 Finance deadline while keeping general pilot independent. Ring 0 runs in parallel with Ring 1 setup, not after it. |
| **Intune assignment group type** | Static AAD security group: `SG-FinBridge-Finance` — Required assignment |
| **Assignment deadline** | Set deadline in Intune assignment to Day 5 17:00 to force install on devices that have not self-installed |

---

### Ring 1 — Pilot

| Field | Detail |
|---|---|
| **Size** | 100 devices |
| **Duration** | Day 1–3 (minimum 48 hours of active monitoring) |
| **Who** | IT department volunteers, helpdesk staff, and technically capable users across mixed departments — not Finance (Finance is Ring 0) |
| **Purpose** | Validate the package, install command, detection rule, and return codes in a controlled environment before any wide deployment. Identify packaging errors, silent failures, and environment-specific conflicts at minimal scale. |
| **Intune assignment group type** | Static AAD security group: `SG-FinBridge-Pilot` — Required assignment |

---

### Ring 2 — Early Adopters

| Field | Detail |
|---|---|
| **Size** | 2,000 devices |
| **Duration** | Day 4–8 (4 days active monitoring after assignment) |
| **Who** | One representative from each business unit, spread across locations and hardware profiles — deliberately inclusive of varied device specs to surface environment-specific issues before broad rollout |
| **Purpose** | Validate at moderate scale across diverse hardware and user profiles. Confirm Finance ring (Ring 0) and Pilot ring (Ring 1) results hold across a larger, less homogeneous group. Surface any issues that only appear at scale (network contention, CDN throttling, concurrent install conflicts). |
| **Intune assignment group type** | Dynamic AAD device group: `SG-FinBridge-Early` — Required assignment. Exclude `SG-FinBridge-Finance`, `SG-FinBridge-Pilot`, and `SG-FinBridge-LegacyHardware` to prevent overlap. |

---

### Ring 3 — Broad Fleet

| Field | Detail |
|---|---|
| **Size** | ~6,900 devices (all remaining standard devices) |
| **Duration** | Day 9–16 |
| **Who** | All remaining Windows 11 endpoints not in previous rings, excluding the legacy hardware group |
| **Purpose** | Complete deployment to the standard fleet. By this point, 2,600 devices (Ring 0 + 1 + 2) have confirmed success, giving high confidence before the full rollout. |
| **Intune assignment group type** | Dynamic AAD device group: `SG-FinBridge-Broad` — Required assignment, with assignment filter excluding `deviceMemory -le 4096` and all previous ring groups |

---

### Ring 4 — Legacy Hardware (At-Risk)

| Field | Detail |
|---|---|
| **Size** | ~500 devices (5% of fleet with ≤4GB RAM) |
| **Duration** | Day 14–21 — delayed until Ring 3 success confirmed AND vendor compatibility confirmed |
| **Who** | All devices meeting filter: `deviceMemory -le 4096` |
| **Purpose** | Isolate the at-risk hardware group from the main rollout. Deploy only after Ring 3 confirms v3.1 is stable and after the vendor confirms 4GB RAM is supported. If vendor confirms 4GB is not supported, this ring is held indefinitely and devices remain on v3.0 until hardware is refreshed. |
| **Intune assignment group type** | Dynamic AAD device group with filter: `SG-FinBridge-LegacyHW` — Required assignment, deployed only on explicit go/no-go decision |

---

### Ring Timeline Summary

| Ring | Group | Devices | Start | End | Gate |
|---|---|---|---|---|---|
| Ring 0 | Finance | 500 | Day 1 | Day 5 | Business deadline |
| Ring 1 | Pilot | 100 | Day 1 | Day 3 | Advance criteria (see Section 2) |
| Ring 2 | Early adopters | 2,000 | Day 4 | Day 8 | Advance criteria (see Section 2) |
| Ring 3 | Broad fleet | ~6,900 | Day 9 | Day 16 | Advance criteria (see Section 2) |
| Ring 4 | Legacy hardware | ~500 | Day 14 | Day 21 | Vendor confirmation + Ring 3 gate |

---

## 2. Advance Criteria

All metrics are observable in: `intune.microsoft.com > Apps > All apps > FinBridge Connect > Monitor > Device install status`

---

### Ring 1 → Ring 2 Advance Criteria (minimum monitoring period: 48 hours after last device in ring installs)

| Criterion | Threshold | Where to Measure |
|---|---|---|
| **Install success rate** | ≥ 95% of Ring 1 devices show status `Installed` | `Monitor > Device install status` — count `Installed` ÷ total assigned |
| **Error rate** | ≤ 3% of Ring 1 devices show status `Failed` | `Monitor > Device install status` — count `Failed` ÷ total assigned |
| **User-reported issues** | ≤ 2 tickets raised by Ring 1 users in the 48-hour window | Service desk ticket queue — filter by `FinBridge` and Ring 1 user list |
| **Detection rule accuracy** | 0 devices showing `Not installed` where install logs confirm the app ran successfully | Cross-check `Not installed` status against device-side registry: `Get-ItemProperty "HKLM:\SOFTWARE\FinBridge\Connect"` |
| **Monitoring period** | Minimum 48 hours after the last Ring 1 device checks in with `Installed` status — not 48 hours from assignment |

**Hold condition (pause without rollback):**  
If `Failed` rate is between 3% and 10% AND all failures are on devices with an identical hardware configuration or OS build — pause Ring 2 assignment, do not rollback Ring 1. Investigate whether the failure is isolated to that specific profile before proceeding. Example: 4 of 100 Ring 1 devices fail, all 4 are running OS build `22621.2861` — this is a build-specific conflict, not a packaging error. Hold and investigate before broadening.

---

### Ring 2 → Ring 3 Advance Criteria (minimum monitoring period: 96 hours after last device in ring installs)

| Criterion | Threshold | Where to Measure |
|---|---|---|
| **Install success rate** | ≥ 97% of Ring 2 devices show status `Installed` | `Monitor > Device install status` |
| **Error rate** | ≤ 2% of Ring 2 devices show status `Failed` | `Monitor > Device install status` |
| **User-reported issues** | ≤ 10 tickets raised by Ring 2 users in the 96-hour window (scales proportionally from Ring 1 threshold) | Service desk queue — filter by Ring 2 user list |
| **Application stability** | Zero P1 or P2 incidents raised citing FinBridge v3.1 as the cause in the 96-hour window | Incident management tool — search `FinBridge` in active incidents |
| **Ring 0 Finance confirmation** | Finance team lead confirms no blocking issues reported by Finance users (required gate — not optional) | Direct confirmation from Finance team lead or their delegate |
| **Monitoring period** | Minimum 96 hours after the last Ring 2 device checks in with `Installed` status |

**Hold condition (pause without rollback):**  
If user ticket rate exceeds 10 but all tickets describe the same non-critical cosmetic issue (e.g., splash screen rendering incorrectly on specific display resolutions) — pause Ring 3, raise with the vendor for a patch, but do not rollback Rings 0–2. Re-evaluate when a fix is available or the vendor confirms the issue is cosmetic and safe to ignore.

---

### Ring 2 → Ring 4 (Legacy Hardware) Additional Gate

Before deploying Ring 4, all of the following must be confirmed independently of the Ring 2→3 gate:

- Written confirmation from FinBridge vendor that v3.1 is supported on 4GB RAM devices
- Ring 3 has been running for at least 48 hours with ≥ 97% install success
- A single legacy hardware device has been manually tested with v3.1 installed and confirmed stable over 24 hours of use

If vendor confirmation is not received by Day 14 — Ring 4 deployment is held. Devices remain on v3.0 indefinitely pending hardware refresh or vendor patch.

---

## 3. Rollback Triggers

All rollback actions are executed via the following Intune path:  
`Apps > All apps > FinBridge Connect v3.0 > Assignments > [affected group] > Required`  
`Apps > All apps > FinBridge Connect v3.1 > Assignments > [affected group] > Uninstall`

---

### Trigger 1 — Install Failure Rate

| Field | Detail |
|---|---|
| **Threshold** | > 10% of devices in the active ring show `Failed` status within 6 hours of ring assignment going live |
| **Timeframe** | Evaluated at 2-hour intervals from assignment time. If threshold is crossed at any 2-hour check — trigger activates. |
| **Decision window** | 30 minutes from threshold being crossed |
| **Decision maker** | DWP MDM Lead or on-call engineer if out of hours |
| **Intune action** | Change affected ring assignment from `Required (v3.1)` to `Uninstall (v3.1)` AND add `Required (v3.0)` assignment to the same group simultaneously. Do not wait for v3.1 uninstall to complete before assigning v3.0 — Intune handles sequencing. |
| **Example** | Ring 2 assigned at 09:00. By 11:00 check, 215 of 2,000 devices (10.75%) show `Failed`. Trigger activates. MDM Lead notified. Decision made by 11:30. v3.1 Uninstall + v3.0 Required applied to `SG-FinBridge-Early` by 11:35. |

---

### Trigger 2 — Application Crash Rate

| Field | Detail |
|---|---|
| **Threshold** | ≥ 5 crash reports or application error tickets referencing FinBridge v3.1 received within any 4-hour window after installation |
| **Timeframe** | Monitored continuously for 48 hours post-ring-assignment. Evaluated per ring independently. |
| **Decision window** | 2 hours from threshold being crossed — time to triage whether crashes are isolated to a specific action or universal |
| **Decision maker** | DWP MDM Lead in consultation with Application Owner |
| **Intune action** | If crashes are confirmed as reproducible across multiple device profiles: `Uninstall (v3.1)` + `Required (v3.0)` on the affected ring group. If crashes appear isolated to a single device/user: investigate individually before rolling back the ring. |
| **Note** | Crash rate rollback is a consideration trigger, not an automatic one. The MDM Lead has the 2-hour window to determine whether the crash pattern is systemic. Automatic rollback applies only to Trigger 1. |

---

### Trigger 3 — Business-Critical Failure

| Field | Detail |
|---|---|
| **Definition** | Any failure where FinBridge Connect v3.1 causes loss of access to, or corruption of, Finance data — regardless of the number of affected devices |
| **Threshold** | One confirmed incident is sufficient. No percentage threshold applies. |
| **Decision window** | Immediate — no waiting period. Rollback begins on confirmation of the incident. |
| **Decision maker** | DWP MDM Lead or Service Desk Incident Manager — does not require senior sign-off given the data risk |
| **Intune action** | `Uninstall (v3.1)` applied to ALL active ring groups simultaneously (`SG-FinBridge-Finance`, `SG-FinBridge-Pilot`, `SG-FinBridge-Early`, `SG-FinBridge-Broad`). `Required (v3.0)` applied to all same groups. Trigger manual sync on Finance devices immediately: `Devices > All devices > [Finance device] > Sync`. |
| **Example** | A Finance user reports that opening a FinBridge v3.1 report overwrites existing data with blank values. One confirmed reproduction — immediate full rollback, all rings. |

---

### Trigger 4 — Legacy Hardware (Ring 4) Failure Rate

| Field | Detail |
|---|---|
| **Threshold** | > 20% of Ring 4 devices (≤4GB RAM) show `Failed` or `Not installed` after 4 hours, OR any device in Ring 4 shows a system performance degradation incident (BSOD, application freeze, unresponsive OS) within 24 hours of install |
| **Decision window** | 1 hour from threshold being crossed |
| **Decision maker** | DWP MDM Lead |
| **Intune action** | `Uninstall (v3.1)` on `SG-FinBridge-LegacyHW` only. `Required (v3.0)` on `SG-FinBridge-LegacyHW`. All other rings are unaffected — do not rollback Ring 3 based on Ring 4 failures alone. |
| **Post-action** | Raise vendor case with failure evidence. Do not re-attempt Ring 4 until vendor confirms a fix or hardware refresh is scheduled. |

---

### Rollback Decision Matrix

| Trigger | Who decides | Decision window | Scope |
|---|---|---|---|
| Install failure >10% | MDM Lead | 30 minutes | Affected ring only |
| Crash rate ≥5 in 4h | MDM Lead + App Owner | 2 hours | Affected ring — triage first |
| Business-critical data failure | MDM Lead or Incident Manager | Immediate | All active rings |
| Ring 4 failure >20% | MDM Lead | 1 hour | Ring 4 only |

---

## 4. Finance Deadline Resolution

### The Conflict

The ring structure in Section 1 places Finance as Ring 0, running from Day 1. However, if Finance were placed in Ring 2 (as a standard early-adopter cohort), they would not receive the app until Day 4 at the earliest — potentially Day 8 if Ring 1 advance criteria are not met on schedule. This conflicts with the end-of-week-1 (Day 5) deadline.

Two resolution options exist.

---

### Option A — Compress Pilot Ring to Fit Finance into Ring 2 by End of Week 1

**How it works:** Run Ring 1 (Pilot) for 24 hours instead of 48, evaluate advance criteria at the 24-hour mark, and assign Ring 2 (which includes Finance) on Day 2 or Day 3.

**Minimum safe pilot duration:** 24 hours — this is the absolute floor. Below 24 hours, Intune has not had sufficient check-in cycles on all pilot devices to produce reliable status data (check-in occurs every 8 hours by default, meaning some devices may only have checked in once).

**Risk introduced:** A 24-hour pilot provides one data point per device at best, compared to 3+ data points in a 48-hour pilot. Silent failures that only appear after the first reboot (e.g., a service that fails to start correctly after restart) may not be visible. Edge cases triggered by specific usage patterns (opening large Finance reports, concurrent user sessions) will not surface in 24 hours of IT pilot usage.

**Compensating control:** Require all 100 Ring 1 pilot users to actively launch and use FinBridge Connect within the first 12 hours of assignment — not just passive install confirmation. Structured test script covering: open, create, save, export. Results logged by pilot users in a shared form. This partially compensates for the reduced time window by increasing the breadth of testing within it.

---

### Option B — Treat Finance as a Separate Priority Ring 0 Before the Main Pilot

**How it works:** Finance receives the app as Ring 0, assigned from Day 1, running concurrently with Ring 1 (Pilot) — not after it. Finance is a separate assignment group with its own monitoring, advance criteria, and rollback path. Ring 1 (Pilot) runs its normal 48-hour window starting Day 1. Ring 2 (Early adopters) starts Day 4 based on Ring 1 advance criteria only — Finance Ring 0 success or failure does not gate Ring 1 or Ring 2 progression.

**Ring 0 structure:**
- Group: `SG-FinBridge-Finance` — 500 devices — Required assignment — Deadline: Day 5 17:00
- Assigned Day 1 simultaneously with Ring 1 Pilot
- Monitored independently — install status checked at 4-hour intervals on Day 1–2, then daily
- Finance IT liaison designated as the escalation contact for Ring 0 user-reported issues

**Ring 0 advance conditions (to confirm Finance deployment is stable before it influences broader communications):**
- ≥ 95% `Installed` by Day 3
- ≤ 3 tickets raised by Finance users by Day 3
- Finance team lead sign-off that the app is functional for Finance workflows by Day 5

**Ring 0 rollback plan:**
- Trigger: > 10% `Failed` in Finance ring by Day 2, OR any Finance user reports data access failure
- Action: `Uninstall (v3.1)` on `SG-FinBridge-Finance`, `Required (v3.0)` on `SG-FinBridge-Finance`
- This does not affect Ring 1 or subsequent rings — Ring 0 rollback is scoped to Finance only
- Decision maker: MDM Lead in consultation with Finance team lead, 1-hour decision window

---

### Recommendation: Option B

**Recommendation: Implement Option B — Finance as Ring 0, concurrent with Ring 1 Pilot.**

**Justification:**

Option A compresses the safest part of the deployment — the pilot — to meet a business deadline. The pilot exists specifically to catch packaging and environment errors before they hit larger groups. Cutting it from 48 hours to 24 hours to accommodate Finance removes half the data collection window and introduces risk to all subsequent rings, not just the Finance ring. If a failure surfaces during the compressed pilot that would have been caught in hour 36 of a normal pilot window, it has now already been deployed to Finance and potentially to 500 users simultaneously.

Option B preserves the integrity of the pilot ring (Ring 1 runs its full 48 hours without pressure) while still meeting the Finance deadline. Finance is treated as a business-priority deployment that runs on its own risk profile, with its own rollback path, and does not contaminate the phased rollout methodology. If Ring 0 (Finance) has problems, they are contained to the Finance group — Ring 1 and Ring 2 are unaffected.

The only additional overhead Option B requires is a dedicated monitoring lane for Ring 0 and a Finance IT liaison — both are low-cost compared to the risk Option A introduces to the full 10,000-device rollout.

**Implementation note:** When assigning Ring 0 and Ring 1 simultaneously, ensure the Finance AAD group (`SG-FinBridge-Finance`) is explicitly excluded from the Ring 1 assignment (`SG-FinBridge-Pilot`) to prevent Finance devices from appearing in both rings and creating ambiguous status reporting.

---

*Related documents: `Guide-Adding-Windows-App-Intune-Catalog.md` (app catalog setup), `FinBridge-v3.1-Intune-Deployment-Plan.md` (initial ring overview)*
