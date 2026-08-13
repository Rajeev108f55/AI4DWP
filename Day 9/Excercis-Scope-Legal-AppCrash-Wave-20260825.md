# Scope Facts: Legal Department Application Crash Wave (2026-03-25)

## Device Group & Scale
- **Device group:** Legal-Win11
- **Total devices in scope:** 45
- **Devices affected by incident:** All 45 (100% correlation with deployment scope)

## Timeline
- **Deployment started:** 09:38:20
- **Deployment completed:** 09:44:07
- **Incident onset:** 10:00 (16 minutes after deployment completion)
- **Observation window:** 10:00–11:00

## DEX Telemetry Changes (09:00 to 11:00)
| Metric | 09:00 | 10:00 | 11:00 | Change |
|---|---|---|---|---|
| DEX Score | 90 | 58 | 55 | -32 points (32% drop) |
| App crash rate | 0.2% | 6.2% | 6.8% | +6.0% (31x increase) |
| Disk I/O | Normal | High | High | Baseline→High at 10:00 |

## Application Crash Data
- **Top crashing process:** DocManager.exe
- **Crash attribution:** 74% of all crashes in 10:00–11:00 window
- **Related deployed package:** Document Manager (v2.0 → v2.1)

## Software Deployment Facts
- **Previous version:** Document Manager v2.0 (stable, deployed 6 weeks ago)
- **New version deployed:** Document Manager v2.1
- **Deployment result:** Success, 0 failures reported, 45 of 45 devices completed
- **Deployment method:** SCCM to collection Legal-Win11

## Vendor Release Notes (Document Manager v2.1)
- New feature: Auto-save indexing
- Known limitation stated: "On devices with under 8GB RAM, the auto-save indexing process can cause high disk I/O and intermittent crashes during the first few hours after installation while the initial index builds."

## Fleet Hardware Composition
- **8GB RAM devices:** 27 (60%)
- **4GB RAM devices:** 18 (40%)

## Temporal & Application Correlation
- Deployment completed 09:44:07
- Incident observed at 10:00 (16-minute gap)
- Crashing application (DocManager.exe) directly relates to deployed package (Document Manager v2.1)
- High disk I/O aligns with vendor-documented auto-save indexing behavior

## Scope Summary
The incident is **geographically scoped** to Legal-Win11 fleet, **temporally scoped** to deployment window + 16 minutes, and **application-scoped** to DocManager.exe. All 45 devices are within the deployment footprint. Hardware diversity (40% low-RAM devices) exists in the affected population.

---
**Note:** Root cause determination deferred pending correlation analysis with hardware subset data.
