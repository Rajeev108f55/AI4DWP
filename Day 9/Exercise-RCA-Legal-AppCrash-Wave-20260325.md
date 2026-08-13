# Exercise-RCA: Legal Department Application Crash Wave — Root Cause Analysis (2026-03-25)

**Incident ID:** LEG-CRASH-20260325-001  
**Date of Incident:** 2026-03-25, 10:00–11:00+  
**Date of RCA:** 2026-03-25 (same day)  
**Scope:** Legal-Win11 device group (45 devices, 18 directly affected)  
**Severity:** High  
**RCA Completed By:** DWP Analysis Team

---

## 1. Root Cause Statement

**Primary Root Cause:**  
Document Manager v2.1 auto-save indexing feature was deployed to devices with insufficient RAM (4GB), causing high disk I/O and application crashes. The vendor explicitly documented this limitation but the deployment did not filter devices by RAM tier.

**Contributing Factors:**
1. Deployment process did not validate hardware prerequisites before installation
2. Vendor release notes were not reviewed by deployment team before broad rollout
3. No pre-deployment testing on representative low-RAM hardware
4. Device collection (Legal-Win11) was not segmented by hardware specification

---

## 2. Five Why Analysis

### Why 1: Why did DocManager.exe crash on 40% of Legal devices at 10:00?
**Answer:** Document Manager v2.1 auto-save indexing initialization process exceeded the disk I/O and memory capacity of devices with 4GB RAM.

### Why 2: Why were 4GB devices included in the v2.1 deployment if the vendor documentation states the version is not supported on sub-8GB RAM hardware?
**Answer:** The deployment process did not perform a prerequisite hardware check, and the SCCM deployment target (Legal-Win11 collection) was not segmented by RAM specification.

### Why 3: Why did the deployment team not review vendor release notes for hardware limitations before deployment?
**Answer:** No formal pre-deployment checklist or approval workflow exists to mandate vendor documentation review for new software versions.

### Why 4: Why was Document Manager v2.1 not tested on 4GB RAM devices before production rollout?
**Answer:** The pre-production testing environment may not have included low-RAM device representation, or testing was conducted only on typical (8GB+) hardware.

### Why 5: Why does the current deployment approval process not require hardware-specific testing for new software versions?
**Answer:** The organization does not have a formal deployment governance standard that enforces testing on the full spectrum of target hardware configurations.

---

## 3. Detailed Timeline

| Time | Event | Component | Details | Impact |
|---|---|---|---|---|
| ~2 weeks prior | Document Manager v2.1 released by vendor | Vendor | Release notes include known limitation for <8GB RAM devices | Not acted upon |
| 09:38:20 | Deployment initiated | SCCM | Target: Legal-Win11 (45 devices, mixed hardware) | Deployment begins |
| 09:44:07 | Installation completed | SCCM | Result: Success, 0 failures | 45 devices receive v2.1 |
| 09:44–10:00 | v2.1 auto-save indexing starts on 4GB devices | DocManager.exe | Background indexing process begins initialization | Preparation phase |
| 10:00:00 | Disk I/O and crash rate spike | Nexthink DEX | DEX Score: 90→58 (-35%); Crash rate: 0.2%→6.2% (+31x); Disk I/O: Normal→High | Incident onset |
| 10:00–11:00 | Elevated crash and I/O sustained | DocManager.exe & Nexthink | 74% of crashes attributed to DocManager.exe; 18 devices (4GB tier) most affected | Sustained disruption |
| 11:00+ | Legal staff report crashes to support | User Reports | Multiple reports of inability to use Document Manager reliably | Business impact escalation |

---

## 4. Supporting Evidence

### 4.1 Deployment Evidence (SCCM Log)
```
[09:38:20] Deployment started: 'Legal Document Manager v2.1' to collection Legal-Win11 (45 devices)
[09:44:07] Install completed: 45 of 45 devices
[09:44:07] Install result: Success, 0 failures
```
**Interpretation:** Deployment completed successfully with no installation errors. The issue manifests post-installation during feature initialization, not during installation.

### 4.2 Vendor Release Notes (Document Manager v2.1)
```
Vendor Statement: "v2.1 includes a new auto-save feature. Known limitation: on devices with 
under 8GB RAM, the auto-save indexing process can cause high disk I/O and intermittent crashes 
during the first few hours after installation while the initial index builds."
```
**Interpretation:** Vendor explicitly identified this exact scenario as a known limitation. This was a predictable risk if hardware prerequisites were not validated.

### 4.3 Nexthink DEX Telemetry (10:00–11:00)
```
DEX Score:      90 (09:00) → 58 (10:00) = -32 points (-35% degradation)
App Crash Rate: 0.2% (09:00) → 6.2% (10:00) = 31x increase
Disk I/O:       Normal (09:00) → High (10:00)
Top Process:    DocManager.exe (74% of crashes in window)
```
**Interpretation:** Telemetry pattern (high disk I/O + crashes concentrated in one application) is diagnostic of the auto-save indexing behavior described by the vendor.

### 4.4 Hardware Composition (Legal-Win11 Fleet)
```
Total devices:      45
8GB RAM devices:    27 (60%) — Expected to handle v2.1 auto-save indexing
4GB RAM devices:    18 (40%) — Expected to experience crashes per vendor documentation
```
**Interpretation:** 40% of the target fleet falls into the unsupported hardware category. This is significant and should have triggered a segmented deployment strategy.

### 4.5 Temporal Correlation
```
Deployment completion: 09:44:07
Incident onset:        10:00:00
Lag time:              ~16 minutes
Vendor expectation:    Crashes occur "during the first few hours after installation"
```
**Interpretation:** 16-minute lag aligns with the initialization time of auto-save indexing, confirming the timeline matches the vendor-documented symptom window.

---

## 5. Immediate Remediation Actions

### Action 1: Rollback Document Manager v2.1 to v2.0 on 4GB RAM Devices (Immediate)
- **Target:** 18 devices with 4GB RAM in Legal-Win11
- **Method:** SCCM forced deployment of Document Manager v2.0
- **Execution time:** <30 minutes
- **Expected outcome:** DEX Score returns to 90+, crash rate drops to 0.1–0.2%

### Action 2: Monitor 8GB RAM Devices (Ongoing)
- **Target:** 27 devices with 8GB RAM in Legal-Win11
- **Method:** Continuous DEX monitoring for the next 24 hours
- **Expectation:** v2.1 should remain stable on these devices
- **Escalation trigger:** If crash rate exceeds 1%, investigate competing root causes

### Action 3: Contact Vendor for Support (Immediate)
- **Action:** Request ETA for v2.1 hotfix supporting 4GB RAM devices
- **Question for vendor:** Is a patched v2.1 in development, or should Legal use v2.0 long-term?
- **Timeline:** Follow up within 24 hours

### Action 4: Verification Check Post-Remediation (Within 30 min of rollback)
```
✓ DEX Score on 4GB devices returns to 90+ (target: within 30 min)
✓ App crash rate on 4GB devices returns to ≤0.2% (target: within 30 min)
✓ DocManager.exe drops off top crash process list
✓ Disk I/O on 4GB devices returns to Normal
✓ No escalation from Legal staff after rollback
```

---

## 6. Preventive Actions (Long-Term)

### 6.1 Pre-Deployment Hardware Prerequisite Validation
**Action:** Implement a mandatory step in the deployment approval workflow to validate that all target devices meet the vendor's stated hardware requirements.

**Implementation:**
- Before deployment: Compare SCCM device collection hardware specs against vendor system requirements
- If hardware mismatch exists: Segment deployment by hardware tier OR delay deployment until all devices meet minimum specs
- Document waiver if proceeding with mismatched hardware (requires executive sign-off)

**Owner:** Deployment governance team  
**Timeline:** Implement before next major software deployment

---

### 6.2 Vendor Release Notes Review Checklist
**Action:** Create a mandatory pre-deployment checklist that includes vendor release notes review.

**Checklist items:**
- [ ] Vendor release notes reviewed for known limitations
- [ ] Known limitations compared against target device fleet configuration
- [ ] Known limitation mitigation plan documented (if applicable)
- [ ] Testing plan includes devices that match all known limitation scenarios

**Owner:** Change management / Deployment team  
**Timeline:** Deploy checklist immediately

---

### 6.3 Segmented Pre-Production Testing
**Action:** Establish a policy that new software versions are tested on representative hardware from each tier present in the target fleet.

**Implementation:**
- Identify all hardware tiers in the organization (e.g., 4GB, 8GB, 16GB RAM buckets)
- Pre-production testing must include at least one device from each tier
- Test execution includes specific scenarios related to vendor-documented known limitations
- Test results must show acceptable performance/stability before approval for production

**Owner:** Quality assurance / Testing team  
**Timeline:** Standard for all future deployments

---

### 6.4 Device Collection Segmentation Strategy
**Action:** Create hardware-based sub-collections within major device groups to enable targeted deployments when hardware prerequisites vary.

**Example:**
```
Legal-Win11 (parent collection, 45 devices)
  ├─ Legal-Win11-4GB (18 devices)
  ├─ Legal-Win11-8GB (27 devices)
```

**Benefit:** Allows different versions/patches to be deployed to different hardware tiers without manual intervention.

**Owner:** SCCM administration  
**Timeline:** Implement within 1 week

---

### 6.5 Deployment Approval Governance
**Action:** Establish a formal deployment approval workflow that includes review by a technical architect, not just operational sign-off.

**Workflow step:**
- Before approval: Technical architect confirms vendor prerequisites are met for ALL devices in target collection
- If prerequisites not met: Architect recommends segmented deployment OR deferral
- Documentation: Approval email includes explicit acknowledgment of hardware validation

**Owner:** Deployment governance  
**Timeline:** Implement before next wave of software deployments

---

## 7. Lessons Learned

1. **Vendor documentation is contractual:** Vendor-documented limitations are not recommendations; they define the supported operating envelope. Ignoring them creates preventable incidents.

2. **Hardware diversity requires deployment strategy:** Organizations with mixed hardware generations (4GB vs. 8GB) must segment deployments; broad rollouts are higher risk.

3. **Testing on representative hardware is essential:** Pre-production testing on 8GB devices only will not expose issues on 4GB devices. Test scope must match deployment scope.

4. **Early escalation based on telemetry is key:** DEX telemetry identified the incident at 10:00 (within minutes of onset). Rapid detection enables faster remediation. Ensure monitoring is actively reviewed pre-deployment on new versions.

---

## 8. Incident Closure

**Status:** Resolved via rollback (Action 1)  
**Verification:** Post-remediation DEX telemetry confirms recovery  
**Follow-up:** Track vendor hotfix timeline for v2.1 compatibility with 4GB devices  
**Preventive measures:** Implemented per Section 6  
**Closure date:** 2026-03-25 (same day)

---

## 9. Appendices

### Appendix A: Hardware Query Command (SCCM PowerShell)
```powershell
# Query devices in Legal-Win11 with RAM specifications
Get-CMDevice -CollectionName "Legal-Win11" | `
  Select-Object Name, @{Label="RAM (GB)"; Expression={[math]::Round($_.Properties["RAM"] / 1024, 0)}} | `
  Sort-Object "RAM (GB)"
```

### Appendix B: Vendor Support Contact
- **Vendor:** Document Manager Publisher
- **Action:** Confirm v2.1 patch ETA for 4GB RAM support
- **Reference:** v2.1 Known Limitation — auto-save indexing on sub-8GB RAM

### Appendix C: Links to Source Telemetry
- Nexthink DEX export: Legal-Win11 group, 2026-03-25, 08:00–11:00
- SCCM deployment log: Document Manager v2.1, Legal-Win11, 2026-03-25, 09:38–09:44
