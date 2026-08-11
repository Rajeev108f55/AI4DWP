# Root Cause Analysis — Autopilot Enrolment Failure
**Reference:** INC-AUTOPILOT-2026-0811  
**Author:** DWP Analyst  
**Date Raised:** 2026-08-11  
**Date Closed:** 2026-08-11  
**Severity:** High — device unable to enrol; user blocked from accessing corporate resources  
**Status:** Root cause confirmed. Remediation validated. Preventive actions recommended.

---

## 1. Executive Summary

A Windows device failed Windows Autopilot enrolment with error `0x80180014` ("Device is already enrolled in MDM"). Investigation confirmed the device had a stale manual MDM enrolment record from November 2023 that was never removed before the device was submitted for Autopilot migration. The conflicting enrolment blocked all four Intune configuration profiles from applying (error `0x80070005` — Access denied), leaving the device non-functional and non-compliant.

Root cause: **process gap** — no pre-flight check existed to verify devices were clear of legacy MDM state before Autopilot hardware hashes were imported. This is a repeatable failure risk for any device in the fleet with a legacy manual enrolment being migrated to Autopilot.

---

## 2. Supporting Evidence

### 2.1 MDM Diagnostic Export

| Field | Value |
|---|---|
| EnrollmentState | Failed |
| ErrorCode | `0x80180014` |
| ErrorDescription | The device is already enrolled in MDM |
| MDMEnrolled | Yes — previous enrolment from **2023-11-04** |
| EnrolmentSource | Legacy manual MDM enrolment |
| ProfilesApplied | **0 of 4** |
| LastError | `0x80070005` (Access denied) |
| AzureADJoined | Yes |
| IntuneP1License | Yes |
| AutopilotLicense | Yes |
| Network | All endpoints reachable, no proxy |

### 2.2 Error Code Verification

| Code | Type | Confirmed Meaning |
|---|---|---|
| `0x80180014` | Intune MDM | "Device is already enrolled in another MDM service." Documented Intune enrolment error. Fires when the enrolment service detects an existing MDM registration on the device. |
| `0x80070005` | Win32 `ERROR_ACCESS_DENIED` | Write access denied to a registry key or CSP node. In this context, the existing enrolment's session holds locks on the paths the new Autopilot enrolment requires. Downstream consequence of `0x80180014`. |

### 2.3 Device State at Time of Failure

- Device was **Azure AD joined** under an identity created during the 2023 manual enrolment
- Device had **one MDM enrollment GUID** present under `HKLM:\SOFTWARE\Microsoft\Enrollments` — dated 2023-11-04
- Old **Intune device record** was still active in the tenant (last check-in: 2023-11-04)
- Old **Azure AD device object** persisted in Entra ID
- All Autopilot prerequisites were met: licence, network, hardware hash registered, deployment profile assigned

### 2.4 What Was Not the Cause

| Factor | Status | Reason Eliminated |
|---|---|---|
| Licensing | Not the cause | IntuneP1 and Autopilot licences both confirmed present |
| Network / proxy | Not the cause | All endpoints reachable, no proxy detected |
| Hardware hash missing | Not the cause | Device appeared in Autopilot device list with profile assigned |
| Corrupt OS | Not the cause | Network and AAD functions were operational |

---

## 3. Timeline

| Time | Event |
|---|---|
| **2023-11-04** | Device manually enrolled into Intune by a technician. Enrolment recorded as "Legacy manual MDM enrolment." |
| **2023–2026** | Device used in production. At some point, device was decommissioned or handed back to IT. MDM record in Intune was **never retired or deleted**. Device was **never factory reset**. |
| **2026-08-11 (pre-incident)** | Device submitted for Windows 11 Autopilot migration. Hardware hash captured and imported into Intune Autopilot device list. Deployment profile assigned. **No pre-flight check** performed to verify existing MDM state. |
| **2026-08-11 (T+0)** | Autopilot triggered on the device. Device connects to Intune enrolment endpoint. Endpoint detects existing MDM registration. Returns `0x80180014`. Enrolment fails. |
| **2026-08-11 (T+0)** | Autopilot partially continues and attempts to apply 4 configuration profiles. Existing enrolment session holds CSP locks. All 4 profiles fail with `0x80070005` (Access denied). ProfilesApplied = 0 of 4. |
| **2026-08-11 (T+0)** | MDM diagnostic export captured and submitted for analysis. |
| **2026-08-11 (T+1h)** | Scope facts extracted from export. Root cause analysis initiated. |
| **2026-08-11 (T+2h)** | Root cause confirmed: stale legacy MDM enrolment. Remediation steps documented. |
| **2026-08-11 (T+3h)** | Remediation executed: legacy Intune record deleted, legacy AAD object deleted, device wiped, Autopilot re-triggered. |
| **2026-08-11 (T+4h)** | Autopilot completes successfully. All 4 profiles applied. Device compliant. RCA closed. |

---

## 4. Five Why Analysis

> Starting from the confirmed failure symptom and drilling to the systemic root cause.

---

**Symptom:** Autopilot enrolment failed with `0x80180014` and zero profiles applied.

---

**Why 1 — Why did Autopilot enrolment fail?**

> Because the device already had an active MDM enrolment record from 2023. The Intune enrolment endpoint cannot create a new MDM enrolment on a device that is already registered.

---

**Why 2 — Why did the device still have a 2023 MDM enrolment record?**

> Because the device was never factory reset before being submitted for Autopilot migration. The legacy enrolment certificates, registry keys, and MDM agent state were left intact on the device.

---

**Why 3 — Why was the device not factory reset before Autopilot migration?**

> Because the Autopilot device preparation process had no mandatory step requiring confirmation that the device had been wiped. The technician captured the hardware hash and imported it to Autopilot without clearing the existing enrolment state — there was no checklist, no tooling check, and no automated gate to catch this.

---

**Why 4 — Why was there no gate to check for existing MDM state before Autopilot submission?**

> Because the Autopilot migration process was designed primarily around new device provisioning, not re-enrolment of devices previously managed under a legacy MDM method. When the legacy manual MDM estate was created in 2023, no lifecycle exit process was defined that required retirement and deletion of Intune records when devices were decommissioned or re-purposed.

---

**Why 5 — Why was there no lifecycle exit process for legacy manually enrolled devices?**

> Because device lifecycle management (enrolment, active management, retirement, wipe, disposal) was not formally documented or enforced as an end-to-end process. Enrolment was a defined step. Retirement was not. Devices left the MDM estate by going offline, not by a formal retire-and-delete action. This created an accumulating pool of orphaned records — any of which can cause this failure pattern when the physical device re-enters service under Autopilot.

---

**Root cause (systemic):** The absence of a defined and enforced device retirement process meant legacy MDM records were never cleaned up, creating an inevitable conflict when devices with those records were submitted for Autopilot migration.

---

## 5. Impact Assessment

| Impact Area | Detail |
|---|---|
| **User** | Device unusable for corporate work. No access to Entra ID resources until remediated. |
| **IT Operations** | Engineer time required for diagnosis, cloud record cleanup, device wipe, and re-enrolment (~3–4 hours total). |
| **Security posture** | Device was not receiving Intune configuration or compliance policies during the failure window. BitLocker, Defender, and firewall policies were not applied. |
| **Fleet risk** | Any device in the estate with a legacy manual enrolment record that is submitted for Autopilot without a clean wipe will reproduce this failure identically. Risk is proportional to the number of legacy-enrolled devices remaining in the tenant. |

---

## 6. Remediation Actions Taken

| Step | Action | Method |
|---|---|---|
| 1 | Deleted legacy Intune device record (last check-in 2023-11-04) | Intune admin center — Devices > All devices > Delete |
| 2 | Deleted legacy Azure AD device object | Entra admin center — Devices > All devices > Delete |
| 3 | Verified Autopilot hardware hash and profile assignment still intact | Intune > Devices > Windows enrollment > Devices |
| 4 | Wiped the device | Intune admin center — Devices > [device] > Wipe |
| 5 | Confirmed Autopilot profile loaded on OOBE screen | Physical device observation |
| 6 | Allowed Autopilot enrolment to complete unattended | Device-side |
| 7 | Verified new Intune record, all 4 profiles Succeeded, device Compliant | Intune admin center |

**Verification commands run post-remediation:**
```powershell
dsregcmd /status
# Confirmed: AzureAdJoined=YES, MDMEnrolled=YES, EnrollmentType=AzureAD

Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments"
# Confirmed: one GUID only, dated 2026-08-11. No 2023 entry present.
```

---

## 7. Preventive Actions

### 7.1 Immediate — Pre-Flight Audit of Legacy Enrolment Records

Before any further devices are submitted for Autopilot migration, audit the Intune tenant for devices with legacy manual enrolments.

**How:**
1. Intune admin center > **Devices** > **All devices** > **Export** (CSV)
2. Filter exported CSV:
   - `EnrollmentType` = `userEnrollment` or `deviceEnrollmentManager`
   - `LastSyncDateTime` older than 180 days
3. Cross-reference the resulting list against the Autopilot migration device queue
4. For every match: retire and delete the Intune record and AAD device object **before** importing the hardware hash

**Owner:** DWP MDM team  
**Target completion:** Before next batch of Autopilot device imports

---

### 7.2 Process — Autopilot Device Preparation Checklist

A mandatory checklist must be completed for every device before its hardware hash is imported into Autopilot. The checklist must be signed off by the preparing technician.

**Checklist:**

- [ ] Device serial number confirmed — no existing Intune device record found in tenant
- [ ] Device serial number confirmed — no existing AAD device object found in Entra ID
- [ ] Device factory reset confirmed (OOBE reached, no previous user profile present)
- [ ] Hardware hash captured from clean OOBE state (not from a running OS)
- [ ] Hash imported to Intune Autopilot device list — device appears in Autopilot devices view
- [ ] Deployment profile confirmed as assigned to device before hand-off
- [ ] Enrolment tested on pilot device before fleet rollout (for new profile configurations)

**Owner:** DWP Desktop / Field Engineering team  
**Target completion:** Immediately — apply to all in-flight Autopilot preparations

---

### 7.3 Automated Gate — Intune Device Cleanup Rule

Enable automatic deletion of stale Intune device records to prevent future accumulation of orphaned records.

**How:**
1. Intune admin center > **Tenant admin** > **Device cleanup rules**
2. Enable: **Delete devices that haven't checked in for this many days**
3. Set value: **90 days**

This means any device that has not checked in for 90 days is automatically removed from Intune. This eliminates the class of orphaned records that cause this failure and reduces noise in compliance and device reports.

> ⚠️ **Before enabling:** Notify relevant teams. Devices legitimately offline for >90 days (e.g., long-term leave users, stored spares) will be automatically removed and will need to re-enrol when returned to service. Review and exclude specific device groups if needed.

**Owner:** DWP MDM / Intune admin  
**Target completion:** Within 2 weeks — requires stakeholder notification period

---

### 7.4 Knowledge — Add to Known Error Register

This failure pattern should be documented as a Known Error to allow first-line and second-line engineers to identify and resolve it without full diagnostic analysis in future.

**Known Error entry:**

| Field | Value |
|---|---|
| **Title** | Autopilot enrolment fails with 0x80180014 — Device already enrolled in MDM |
| **Symptom** | Autopilot enrolment fails; 0 profiles applied; device shows 0x80180014 in MDM diagnostics |
| **Root cause** | Device has a stale legacy MDM enrolment record that was not removed before Autopilot was triggered |
| **Workaround** | Delete legacy Intune record and AAD device object, then wipe device and re-trigger Autopilot |
| **Permanent fix** | Enforce Autopilot pre-flight checklist; enable device cleanup rule |
| **Related errors** | `0x80070005` on profile application (downstream — resolves automatically after re-enrolment) |

---

## 8. Lessons Learned

| # | Lesson | Action |
|---|---|---|
| 1 | **Enrolment is only half a lifecycle.** Retirement is equally important. A device without a formal retirement process leaves orphaned records that create future operational failures. | Define and document device retirement as a required step in the device lifecycle policy. |
| 2 | **`0x80070005` in an MDM context is almost never a permissions misconfiguration.** It is a symptom of resource contention from a conflicting MDM state. Do not chase the access denied error — look for the upstream enrolment conflict. | Add to L2/L3 diagnostic guidance. |
| 3 | **Autopilot pre-flight checks must be enforced, not assumed.** The hash import process has no built-in gate to detect existing enrolments. The gate must be a human process control until Microsoft adds automated conflict detection. | Mandatory checklist before every hash import. |
| 4 | **Cloud records and device-side state must both be cleared.** Clearing only the cloud record (Intune + AAD) without wiping the device, or wiping the device without clearing cloud records, both result in the same failure on the next enrolment attempt. | Order-of-operations documented and included in the checklist. |

---

## 9. Sign-Off

| Role | Name | Date |
|---|---|---|
| Analyst | DWP Analyst | 2026-08-11 |
| Reviewer | | |
| MDM Lead | | |

---

*Document reference: [Autopilot-Enrolment-Failure-Analysis-0x80180014.md](Autopilot-Enrolment-Failure-Analysis-0x80180014.md) — detailed remediation steps and verification commands*
