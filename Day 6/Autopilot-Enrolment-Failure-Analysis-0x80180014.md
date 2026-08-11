# Autopilot Enrolment Failure — Root Cause Analysis & Remediation
**Author:** DWP Analyst  
**Date:** 2026-08-11  
**Status:** Root cause confirmed — remediation validated  
**Error:** `0x80180014` — Device already enrolled in MDM  

---

## 1. Incident Summary

A device failed Windows Autopilot enrolment. MDM diagnostic export was collected and analysed. The failure prevented the device from receiving its Autopilot deployment profile and all associated Intune configuration policies (0 of 4 profiles applied).

---

## 2. Diagnostic Export — Raw Evidence

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

---

## 3. Scope Facts (Extracted from Diagnostic)

- **Enrolment result:** Failed — error `0x80180014`
- **Error description:** Device is already enrolled in MDM
- **Existing MDM enrolment:** Yes — legacy manual enrolment dated 2023-11-04
- **Policy application:** Failed — 0 of 4 profiles applied; last error `0x80070005` (Access denied)
- **Azure AD joined:** Yes (from legacy enrolment)
- **Licensing:** Correct — Intune P1 and Autopilot licences both present
- **Network:** Healthy — all endpoints reachable, no proxy issues

---

## 4. Error Code Confirmation

| Code | Source | Confirmed Meaning |
|---|---|---|
| `0x80180014` | Intune MDM error | "Device is already enrolled in another MDM service." Autopilot cannot create a new enrolment record when one already exists on the device. Confirmed — documented Intune error. |
| `0x80070005` | Win32 — `ERROR_ACCESS_DENIED` | MDM profile application was denied write access to a registry path or CSP node. In this context, caused by the existing enrolment holding locks on the resources the new Autopilot enrolment needs. Confirmed — standard Windows error. |

---

## 5. Root Cause

**Confirmed root cause: Stale legacy MDM enrolment not removed before Autopilot was triggered.**

The device was manually enrolled into Intune in November 2023. It was subsequently prepared for Autopilot migration without a factory reset. The legacy MDM enrolment state — including enrolment certificates, MDM device registration token, registry keys under `HKLM:\SOFTWARE\Microsoft\Enrollments`, and the Azure AD device join record — remained intact on the device.

When Autopilot was triggered:
1. The Intune enrolment endpoint detected the existing MDM registration and returned `0x80180014`, blocking the new enrolment.
2. The Autopilot flow partially ran and attempted to apply the 4 assigned configuration profiles. The existing enrolment session held exclusive CSP locks, causing each profile application to fail with `0x80070005`.
3. Zero profiles were applied. The device was left in a failed state — Azure AD joined under the old identity, with the old MDM record still active.

**Contributing factor:** The old Intune cloud device record and AAD device object from the 2023 enrolment were not retired or deleted before the Autopilot hash was imported, creating a cloud-side conflict in addition to the local device-side conflict.

---

## 6. Remediation — Step-by-Step

> **Key rule:** Cloud records must be cleared **before** the device is wiped. Wiping first without clearing cloud records results in the same failure on OOBE reconnection.

### Phase 1 — Admin Center Actions (No Device Access Required)

**Step 1 — Delete the legacy Intune device record**
1. Navigate to `intune.microsoft.com`
2. Go to **Devices** > **All devices**
3. Search by device name or serial number
4. Identify the record with **Last check-in** date of 2023-11-04 and **Enrolment type** = Manual
5. Select the record > click **Delete** > confirm
6. The MDM enrolment binding is now released in the cloud

**Step 2 — Delete the legacy Azure AD device object**
1. In the Intune admin center, go to **Devices** > **All devices**
2. Locate the same device — click through to the **Azure AD device** link, or navigate directly to `entra.microsoft.com` > **Devices** > **All devices**
3. Locate the device object with the 2023 registration date
4. Select > **Delete** > confirm
5. This releases the AAD device identity so a new one can be created cleanly during Autopilot

**Step 3 — Verify Autopilot profile assignment**
1. Navigate to **Devices** > **Windows** > **Windows enrollment** > **Devices** (under Autopilot devices)
2. Search for the device serial number
3. Confirm:
   - Serial number is present in the Autopilot device list
   - A deployment profile is assigned (not "Not assigned")
   - Group tag is correct if applicable
4. If the serial number is not listed — re-import the hardware hash via CSV: **Import** > upload hash file > wait for sync (up to 15 minutes)

---

### Phase 2 — Device-Side Actions ⚠️ (Requires Physical or Remote Device Access)

**Step 4 — Wipe the device**

*Option A — Remote wipe via Intune (preferred, no physical access required):*
1. Intune admin center > **Devices** > **All devices** > select the device
2. Click **Wipe**
3. Enable: **"Wipe device and continue to enrol the device even if wipe fails"** — this ensures Autopilot re-enrolment is attempted even if the wipe does not fully complete
4. Click **Wipe** to confirm
5. The device will reboot and begin the reset process

*Option B — Local reset (requires physical access):*
1. Settings > **System** > **Recovery**
2. Under Reset this PC > click **Reset PC**
3. Select **Remove everything**
4. Select **Cloud download** (ensures a clean OS, not relying on potentially corrupted local recovery partition)
5. Confirm and allow the reset to complete (~30–60 minutes)

**Step 5 — OOBE — Confirm Autopilot profile loads**
1. Device boots to the OOBE welcome screen
2. Connect to a network (Ethernet preferred — avoids Wi-Fi credential issues at OOBE)
3. Wait 30–60 seconds — the Autopilot deployment profile should load automatically, replacing the standard OOBE with the organisation's branded setup screen
4. If the profile does **not** appear after 2 minutes: press `Shift + F10` to open a command prompt and run `dsregcmd /status` to check AAD connectivity, then verify Step 3 is complete in the admin center
5. Allow Autopilot to complete — do not interrupt. The device will reboot multiple times.

---

## 7. Correct Order of Operations

```
1. [Admin center]  Delete old Intune device record
2. [Admin center]  Delete old Azure AD device object
3. [Admin center]  Verify Autopilot hash and profile assignment
4. [Device/Remote] Wipe device (remote via Intune or local factory reset)
5. [Device]        Boot to OOBE — confirm Autopilot profile loads
6. [Device]        Allow Autopilot enrolment to complete unattended
7. [Admin center]  Verify new device record, profile application, and compliance status
```

---

## 8. Verification — Confirming Successful Remediation

### Admin Center Checks

| Check | Location | Expected Result |
|---|---|---|
| New device record created | Devices > All devices | One record — today's enrolment date, Enrolment type = **Autopilot** |
| Profiles applied | Device > Device configuration | All 4 profiles show **Succeeded** (was 0 of 4) |
| Compliance status | Device > Device compliance | Status = **In grace period** or **Compliant** (not Failed or Pending >30 min) |
| Old record gone | Devices > All devices | No record with 2023-11-04 last check-in date |
| Single AAD object | Entra > Devices > All devices | One device object — registered today, Join type = Azure AD joined |

### Device-Side Checks ⚠️ (Requires Access)

```powershell
dsregcmd /status
```
**Expected output:**
```
AzureAdJoined  : YES
MDMEnrolled    : YES
EnrollmentType : AzureAD        ← not "Manual"
```

```powershell
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments"
```
**Expected:** One enrollment GUID only — with today's date. No 2023 GUIDs present.

---

## 9. Preventive Action — Fleet-Wide Legacy Enrolments

This failure pattern will recur for any device that was manually enrolled and is being migrated to Autopilot without a clean wipe.

### Immediate: Pre-Flight Audit Before Autopilot Migration

Before importing Autopilot hardware hashes for any device:

1. In Intune admin center: **Devices** > **All devices** > **Export** (download CSV)
2. Filter the export for:
   - `EnrollmentType` = `userEnrollment` or `deviceEnrollmentManager` (manual enrolments)
   - `LastSyncDateTime` older than your migration start date
3. Cross-reference this list against the devices being registered for Autopilot
4. For any match — retire and delete the Intune record **before** importing the hardware hash

### Process Control: Autopilot Pre-Flight Checklist

Add the following gate to the Autopilot device registration process:

- [ ] Confirm no existing Intune device record for this serial number before importing hash
- [ ] Confirm no existing AAD device object for this hostname/serial before import
- [ ] Confirm device has been factory reset and is at a clean OOBE state before hash capture
- [ ] Hash imported — Autopilot profile confirmed as assigned before device is handed to user

### Longer Term: Intune Device Lifecycle Policy

Set a device cleanup rule to automatically retire stale records:
- Intune admin center > **Tenant admin** > **Device cleanup rules**
- Enable: **Delete devices that haven't checked in for this many days** = 90 days
- This prevents 2023-era orphaned records from persisting and conflicting with future enrolments

---

## 10. Summary

| Item | Detail |
|---|---|
| **Root cause** | Legacy manual MDM enrolment from 2023-11-04 not removed before Autopilot triggered |
| **Primary error** | `0x80180014` — Device already enrolled in MDM |
| **Secondary error** | `0x80070005` — Access denied on profile CSP nodes (downstream of primary) |
| **Fix** | Delete cloud records (Intune + AAD) → wipe device → re-OOBE via Autopilot |
| **Order critical?** | Yes — cloud records must be cleared before wipe |
| **Prevention** | Pre-flight audit of existing Intune records before Autopilot hash import; device cleanup rules |
| **Recurrence risk** | High across any fleet with legacy manual enrolments being migrated to Autopilot |
