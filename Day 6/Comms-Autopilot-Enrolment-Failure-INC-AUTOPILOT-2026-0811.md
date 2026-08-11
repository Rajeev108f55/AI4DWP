# End-User Communications — Autopilot Enrolment Failure
**Reference:** INC-AUTOPILOT-2026-0811 / KE-MDM-2026-001  
**Date:** 2026-08-11  
**Author:** DWP Analyst  

---

## Audience 1 — Non-Technical Executive

Subject: Device Issue Resolved — No Impact to Your Data or Access

Your device experienced a technical setup issue during a routine IT migration today. Your data was not affected and your accounts remain secure. Our team identified and resolved the problem within the same working day. No action is required from you. If you experience any difficulty accessing your device or DWP systems, please contact the IT Service Desk.

---

## Audience 2 — Affected End-User Team

Subject: Device Setup Issue This Morning — Here's What Happened

Hi team,

One of our devices had a hiccup today during an IT upgrade — an old IT registration record hadn't been fully cleared before the new setup ran, which caused it to fail. It's been fixed and the device is working normally. Your data and accounts were not affected at any point.

If your device shows an error during setup or you can't access DWP systems, don't try to fix it yourself — just contact the IT Service Desk straight away and quote reference **INC-AUTOPILOT-2026-0811**.

Thanks,  
DWP IT Support

---

## Audience 3 — Engineer-to-Engineer Internal Note

**Subject:** P1 Autopilot failure — 0x80180014 — stale legacy MDM enrolment. Resolved same day.

---

**Root Cause**

Device submitted for Autopilot migration still had an active manual MDM enrolment record from 2023-11-04 (`EnrolmentSource: Legacy manual MDM enrolment`). No factory reset had been performed. The Intune enrolment endpoint returned `0x80180014` ("device already enrolled") blocking the new Autopilot enrolment. Downstream, all 4 assigned config profiles failed with `0x80070005` (Access denied) because the existing enrolment session held CSP locks on the registry paths the new enrolment needed. `0x80070005` is a symptom — do not chase it as a permissions issue.

---

**Confirmed Facts from Diagnostic Export**

```
EnrollmentState : Failed
ErrorCode       : 0x80180014
ErrorDescription: The device is already enrolled in MDM.
MDMEnrolled     : Yes (previous enrolment from 2023-11-04)
EnrolmentSource : Legacy manual MDM enrolment
ProfilesApplied : 0 of 4
LastError       : 0x80070005 (Access denied)
AzureADJoined   : Yes
IntuneP1License : Yes
AutopilotLicense: Yes
Network         : All endpoints reachable, no proxy
```

Licensing, network, hardware hash, and profile assignment were all confirmed healthy — none of these were contributing factors.

---

**Actions Taken — Order Is Critical**

> Cloud records must be cleared before the device is wiped. Reversing the order reproduces the same failure on OOBE reconnection.

1. **Intune admin center** — Devices > All devices — located record with last check-in 2023-11-04, EnrolmentType = Manual — clicked **Delete**, confirmed.
2. **Entra admin center** — Devices > All devices — located AAD device object from 2023 registration — clicked **Delete**, confirmed.
3. **Intune admin center** — Devices > Windows > Windows enrollment > Devices (Autopilot) — confirmed serial number present, correct deployment profile assigned.
4. **Intune admin center** — Devices > [device] > **Wipe** — enabled "Wipe device and continue to enrol even if wipe fails."
5. Device rebooted to OOBE — Autopilot profile loaded within 60 seconds (confirms hash and profile still intact post-cloud-record deletion).
6. Autopilot completed unattended — device rebooted twice during provisioning.

---

**Verification**

Admin center post-enrolment:
- New device record — enrolment date 2026-08-11, Enrolment type = **Autopilot**
- Device configuration — all **4 profiles: Succeeded**
- Device compliance — status **In grace period** (expected — 7-day grace period active per policy)
- No legacy record remaining in Devices > All devices for this serial

Device-side:
```powershell
dsregcmd /status
# AzureAdJoined  : YES
# MDMEnrolled    : YES
# EnrollmentType : AzureAD   ← confirms Autopilot, not manual

Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments"
# One GUID only, dated 2026-08-11. No 2023 entry.
```

---

**How to Spot This If It Recurs**

Primary signal: `0x80180014` + `MDMEnrolled: Yes` with a pre-migration date in the same MDM diagnostic export.  
Secondary (do not chase independently): `0x80070005` on ProfilesApplied = 0.  
Local confirm: `Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments"` — more than one GUID, or a GUID with a pre-migration EnrollmentStartDate.

---

**Preventive Actions Required — Not Yet Completed**

| Action | Owner | Priority |
|---|---|---|
| Run pre-flight audit: export all Intune devices, filter `EnrolmentType = Manual` + `LastSync > 180 days old`, cross-reference against Autopilot migration queue, retire and delete matches before hash import | DWP MDM team | Immediate — before next Autopilot batch |
| Enforce Autopilot pre-flight checklist: no hash import without confirming zero existing Intune record and AAD object for that serial | DWP Desktop/Field Engineering | Immediate |
| Enable Intune device cleanup rule: Tenant admin > Device cleanup rules > delete devices not checked in for 90 days. Notify stakeholders first — devices offline >90 days will be auto-retired. | DWP Intune admin | Within 2 weeks |
| Add KE-MDM-2026-001 to the knowledge base and brief L1/L2 that `0x80070005` in Autopilot context is a downstream symptom of `0x80180014`, not a standalone permissions fault | DWP Knowledge / Service Desk lead | This week |

---

**Related Docs (Day 6)**
- `Autopilot-Enrolment-Failure-Analysis-0x80180014.md` — full diagnostic and remediation steps
- `RCA-Autopilot-Enrolment-Failure-0x80180014.md` — formal RCA with 5-why and impact assessment
- `Known-Error-MDM-001-Autopilot-Stale-Enrolment.md` — KB record
