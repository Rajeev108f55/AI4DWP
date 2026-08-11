# FinBridge Connect v3.1 — Intune Deployment Plan
**Author:** DWP Engineer  
**Date:** 2026-08-11  
**Status:** Draft  
**Deadline:** 2026-09-01 (3 weeks from today)  

---

## Deployment Context

| Field | Detail |
|---|---|
| **Application** | FinBridge Connect v3.1 (.intunewin package) |
| **Target fleet** | 10,000 Windows 11 endpoints |
| **Deadline** | 3 weeks from today (2026-09-01) |
| **Priority constraint** | Finance team (500 users) must have v3.1 by end of Week 1 |
| **Hardware constraint** | ~500 devices (5%) have ≤4GB RAM — may not meet v3.1 requirements |
| **Previous version** | v3.0 — no major rollout issues; still available in Intune app catalog |
| **Rollback option** | v3.0 available for immediate reassignment |
| **Detection rule** | Registry version string check |

---

## Deployment Strategy Overview

Three-ring deployment over 3 weeks. Finance prioritised in Ring 1 to meet the end-of-week-1 deadline. Legacy hardware (≤4GB RAM) isolated into Ring 3 with a compatibility gate before deployment proceeds.

---

## Ring Structure

| Ring | Target Group | Device Count | Deploy Day | Intent |
|---|---|---|---|---|
| **Ring 0 — Pilot** | IT / volunteer testers | ~25 | Day 1 | Confirm package installs, detection rule fires, no silent failures |
| **Ring 1 — Finance** | Finance AAD group | 500 | Day 2–3 | Meet end-of-week-1 deadline; monitored closely |
| **Ring 2 — General fleet** | All remaining standard devices | ~9,000 | Day 8 | Broad rollout after Finance confirmed stable |
| **Ring 3 — Legacy hardware** | Devices with ≤4GB RAM (scoped via Intune filter) | ~500 (5%) | Day 14 | Delayed pending compatibility confirmation from Ring 2 |

---

## Ring 0 — Pilot (Day 1–2)

**Intune path:** `Apps > Windows > [FinBridge Connect v3.1] > Assignments > Add group (Required) > [IT Pilot group]`

**Gates before Ring 1:**
- Install success rate ≥ 95% across pilot devices
- Detection rule (registry version string) returns correct version on all successful installs
- No crash reports or application errors in first 4 hours of use
- Uninstall and reinstall tested on one device to confirm clean behaviour

---

## Ring 1 — Finance (Day 2–3, must complete by end of Week 1)

**Intune path:** `Apps > Windows > [FinBridge Connect v3.1] > Assignments > Add group (Required) > [Finance AAD group]`

**Assignment type:** Required (not Available) — Finance deadline is non-negotiable; passive install cannot be relied on.

**Deadline setting:**  
`intune.microsoft.com > Apps > [app] > Assignments > [Finance group] > Deadline: [Day 5 date, 17:00]`

Set an installation deadline so devices that have not installed by end of Week 1 are flagged rather than silently missed.

**Monitoring during Ring 1:**
- `Apps > Monitor > App install status > [FinBridge v3.1]` — filter by Finance group
- Watch for: install failures, `Not applicable` (device not in scope — check group membership), `Pending restart`
- Alert threshold: >5% failure rate within 4 hours of assignment → pause and investigate before continuing

---

## Ring 2 — General Fleet (Day 8)

**Gate from Ring 1:**
- Finance install success rate ≥ 97%
- No P1/P2 incidents raised by Finance users in Week 1
- v3.0 → v3.1 upgrade path confirmed clean (no orphaned v3.0 files blocking detection rule)

**Intune path:** `Apps > Windows > [FinBridge Connect v3.1] > Assignments > Add group (Required) > [All Windows Devices]`

Apply an **Intune assignment filter** to exclude ≤4GB RAM devices and Finance (already deployed):  
`Tenant admin > Filters > Create > Rule: deviceMemory -gt 4096`

Use this filter as an exclusion on the Ring 2 assignment to prevent overlap with Ring 3.

---

## Ring 3 — Legacy Hardware (Day 14)

**Why delayed:** v3.1 requirements against 4GB RAM devices are unconfirmed. Deploying simultaneously with the general fleet risks 500 simultaneous failures creating noise that masks other issues.

**Gate from Ring 2:**
- Review v3.1 system requirements — confirm whether 4GB RAM is supported or not
- **If supported:** assign Ring 3 with `Required`, monitor install success
- **If not supported:** raise with application owner — request compatibility exception, plan hardware refresh, or keep these devices on v3.0 until hardware is upgraded

**Intune filter for legacy hardware group:**  
`intune.microsoft.com > Tenant admin > Filters > Create`  
Rule: `deviceMemory -le 4096 -and operatingSystem -eq Windows`

---

## Detection Rule Verification

**Intune path:** `Apps > Windows > [app] > Detection rules > Registry`

Confirm the registry key, value name, and version string for v3.1 are updated from the v3.0 detection rule before any ring is deployed. A detection rule still pointing at the v3.0 version string will report all v3.1 installs as `Not installed`.

**Verification check on a Ring 0 device:**
```powershell
# Confirm the exact registry path and value the detection rule queries
# Replace path/value with what is defined in the .intunewin package spec
Get-ItemProperty "HKLM:\SOFTWARE\[Vendor]\FinBridge Connect" | Select-Object Version
```
Value returned must match exactly what is configured in the Intune detection rule.

---

## Rollback Plan

### Trigger Conditions
- Install failure rate >10% in any ring within 6 hours of deployment
- Finance users reporting application crashes or data errors in Ring 1
- v3.1 confirmed incompatible on legacy hardware in Ring 3

### Rollback Action

**Intune path:**  
`Apps > Windows > [FinBridge Connect v3.0] > Assignments > Add group (Required) > [affected group]`

Simultaneously:  
`Apps > Windows > [FinBridge Connect v3.1] > Assignments > [affected group] > Change to Uninstall`

Intune will uninstall v3.1 and reinstall v3.0 on next device check-in (up to 8 hours without a manual sync).

**To accelerate rollback:**  
`Devices > All devices > [device] > Sync` — or instruct users to open Company Portal > Sync.

---

## Week-by-Week Summary

| Week | Action | Success Criteria |
|---|---|---|
| **Week 1** | Ring 0 pilot (Day 1–2), Ring 1 Finance (Day 2–5) | Finance 100% deployed by Day 5, <3% failure rate |
| **Week 2** | Ring 2 general fleet (Day 8) | ≥97% install success by Day 12, no P1 incidents |
| **Week 3** | Ring 3 legacy hardware (Day 14–17), final sweep | All rings at target or documented exception raised for unsupported hardware |
