# KB Article — Autopilot Enrolment Failure: Device Already Enrolled (0x80180014)
**KB ID:** KB-MDM-L2-2026-001  
**Version:** 1.0 | **Date:** 11/08/2026 | **Status:** Draft  
**Audience:** L2 / L3 DWP Engineers  
**Related RCA:** RCA-Autopilot-Enrolment-Failure-0x80180014.md  
**Related Known Error:** KE-MDM-2026-001  

---

## 1. Background

Windows Autopilot is the zero-touch device provisioning service used by DWP to configure new and re-purposed Windows 11 devices. When a device is powered on and reaches the Out-of-Box Experience (OOBE), it contacts the Microsoft Intune enrolment endpoint, retrieves its assigned deployment profile, and applies configuration policies automatically without engineer intervention.

For Autopilot to complete, the device must have no pre-existing MDM enrolment. Intune registers each device as a unique MDM client using certificates and a GUID stored locally under `HKLM:\SOFTWARE\Microsoft\Enrollments`. If a prior enrolment record exists — either locally on the device or as a cloud record in the Intune tenant — the enrolment endpoint rejects the new attempt. This matters because DWP manages a large estate of devices that were previously enrolled manually before Autopilot was adopted. Any such device submitted for Autopilot migration without a clean wipe will fail with this error.

---

## 2. Symptom

### What the User Reports
- New device shows a setup or error screen and does not reach the normal sign-in screen
- Device appears stuck on setup screens for more than 30 minutes
- Device restarts during setup but returns to the same error

### What the Engineer Observes
- Autopilot enrolment fails — device does not appear in Intune as a newly enrolled Autopilot device
- MDM diagnostic export shows `EnrollmentState: Failed` and `ProfilesApplied: 0 of 4`
- Device is Azure AD joined but under a legacy identity, not an Autopilot-provisioned identity
- Intune admin center shows the device record with a last check-in date from a previous year, not today

### Comparison Check — Affected vs Unaffected Device

| Field | Affected Device | Unaffected Device |
|---|---|---|
| `HKLM:\SOFTWARE\Microsoft\Enrollments` GUID count | 1 GUID with a pre-migration date | 0 GUIDs (pre-enrolment) or 1 GUID with today's date (post-enrolment) |
| Intune device record count for this serial | 2 records (one legacy, one failed attempt) or 1 legacy record | 1 record with today's enrolment date |
| `EnrollmentType` in Intune record | Manual / userEnrolment | Autopilot |
| `dsregcmd /status` → `EnrollmentType` | Not AzureAD | AzureAD |
| Intune device config → profiles | 0 Succeeded | All profiles Succeeded |

---

## 3. Root Cause

The device has an active MDM enrolment record remaining from a previous manual Intune enrolment (confirmed in this incident: dated 2023-11-04, source: Legacy manual MDM enrolment). The record persists in two locations simultaneously:

1. **Device-side:** Enrolment GUID, certificates, and MDM agent state under `HKLM:\SOFTWARE\Microsoft\Enrollments\{GUID}`
2. **Cloud-side:** Intune device object and Azure AD device object from the original enrolment, still active in the tenant

When Autopilot triggers, the Intune enrolment endpoint checks for existing MDM registration. It finds the 2023 record and returns `0x80180014`, blocking the new enrolment. The Autopilot flow partially continues and attempts to write the four assigned configuration profiles to CSP registry paths, but the existing enrolment session holds exclusive locks on those paths, producing `0x80070005` (Access denied) on every profile. This secondary error is a downstream symptom — it resolves automatically once the enrolment conflict is cleared. Do not investigate `0x80070005` as a standalone permissions failure in this scenario.

---

## 4. Detection — Confirming This Is the Issue Before Acting

Work through these checks in order. Each one narrows or confirms the root cause.

---

### Check 1 — MDM Diagnostic Export (Primary)

**How to collect:**  
On the device at OOBE (press `Shift + F10` to open a command prompt):
```cmd
mdmdiagnosticstool.exe -area Autopilot -zip C:\MDMLogs.zip
```
Or run from a live Windows session:
```cmd
mdmdiagnosticstool.exe -area DeviceEnrollment;Autopilot -zip C:\MDMLogs.zip
```

**What to look for:**

| Field | Confirms this issue if value is... |
|---|---|
| `EnrollmentState` | `Failed` |
| `ErrorCode` | `0x80180014` |
| `MDMEnrolled` | `Yes` with a date before the current migration date |
| `EnrolmentSource` | `Legacy manual MDM enrolment` or similar non-Autopilot value |
| `ProfilesApplied` | `0 of [n]` |
| `LastError` | `0x80070005` |

If `ErrorCode` is `0x80180014` AND `MDMEnrolled: Yes` with a pre-migration date — root cause is confirmed. Stop investigating other factors.

---

### Check 2 — Windows Event Log (Device-Side)

**Log location:**  
`Event Viewer > Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider > Admin`

**Event IDs to look for:**

| Event ID | Meaning | What confirms this issue |
|---|---|---|
| **72** | MDM enrolment was attempted | Present — confirms Autopilot tried to enrol |
| **75** | MDM enrolment failed | Present with `0x80180014` in the description — confirms the enrolment was rejected |
| **76** | MDM enrolment succeeded | Absent — confirms enrolment did not complete |

**Field to check in Event ID 75:**  
`Description` field — should contain the text `"The device is already enrolled"` and the hex code `80180014`.

> ⚠️ **Note on Event ID confidence:** Event IDs 72, 75, and 76 are documented in the DeviceManagement-Enterprise-Diagnostics-Provider channel. If these IDs are not present in your environment, search the Admin log for any event containing `0x80180014` or `80180014` in the Description field as an alternative.

**Log location (Autopilot-specific):**  
`Event Viewer > Applications and Services Logs > Microsoft > Windows > ModernDeployment-Diagnostics-Provider > Autopilot`

Look for any event with `ErrorCode` or `HResult` containing `80180014`. Events in this log track each phase of the Autopilot sequence — a failure entry here confirms the enrolment phase specifically failed rather than a later provisioning phase.

---

### Check 3 — Registry (Device-Side)

Open a command prompt (`Shift + F10` at OOBE, or elevated PowerShell in a live session):

```powershell
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments" |
    ForEach-Object {
        $date = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).EnrollmentStartDate
        [PSCustomObject]@{ GUID = $_.PSChildName; EnrollmentStartDate = $date }
    }
```

**What confirms this issue:**  
- One or more GUIDs present with an `EnrollmentStartDate` predating the current migration
- Any GUID present on a device that should be at a clean OOBE state

**Unaffected device (baseline):**  
No GUIDs present, or one GUID with today's date if enrolment has already completed successfully.

---

### Check 4 — Intune Admin Center (Cloud-Side)

**Path:** `intune.microsoft.com > Devices > All devices`

Search by device serial number or hostname.

**What confirms this issue:**
- A device record exists with `Last check-in` date from before the migration start date
- `Enrolment type` = `Manual`, `userEnrolment`, or `deviceEnrollmentManager` (not `Autopilot`)
- A second record may exist for the same serial showing today's date with `EnrolmentState: Failed`

**Path:** `intune.microsoft.com > Devices > Windows > Windows enrollment > Devices (Autopilot)`

Confirm the serial number is present and a deployment profile is assigned. If the serial is absent here — the issue is a missing hardware hash, not a stale enrolment (different resolution path).

---

### Check 5 — Azure AD Device Object (Cloud-Side)

**Path:** `entra.microsoft.com > Devices > All devices`

Search by device hostname or serial number.

**What confirms this issue:**
- A device object exists with `Registered` date from before the migration
- `Join type` = `Azure AD joined` from the legacy enrolment (not a fresh Autopilot join)
- `MDM` field shows the old Intune enrolment, not the new one

---

## 5. Resolution — Step-by-Step Fix

> **Critical rule:** Steps 1–3 (cloud cleanup) must be completed before Step 4 (device wipe). Wiping first without clearing cloud records causes the same failure on OOBE reconnection.

---

### Step 1 — Delete the Legacy Intune Device Record

**Path:** `intune.microsoft.com > Devices > All devices`

1. Search for the device by serial number
2. Identify the record with the pre-migration `Last check-in` date and `Enrolment type: Manual`
3. Select the record
4. Click **Delete** > confirm the deletion prompt

**Expected result after this step:**  
The legacy Intune device record no longer appears in `Devices > All devices` for this serial number. The hardware hash record under `Devices > Windows > Windows enrollment > Devices` is unaffected and remains present.

---

### Step 2 — Delete the Legacy Azure AD Device Object

**Path:** `entra.microsoft.com > Devices > All devices`

1. Search for the device by hostname or serial
2. Identify the object with the pre-migration `Registered` date
3. Select it
4. Click **Delete** > confirm

**Expected result after this step:**  
The AAD device object from the legacy enrolment is gone. The device's hardware hash Autopilot registration is unaffected.

---

### Step 3 — Verify Autopilot Profile Assignment Is Intact

**Path:** `intune.microsoft.com > Devices > Windows > Windows enrollment > Devices`

1. Search for the device serial number
2. Confirm it appears in the list
3. Confirm `Profile status` shows the correct deployment profile name — not `Not assigned`
4. If `Not assigned` or serial is missing: re-import the hardware hash via **Import** (CSV), then wait up to 15 minutes for the profile to assign before proceeding

**Expected result after this step:**  
Device serial present, profile assigned, status not showing any error.

---

### Step 4 — Wipe the Device

**Option A — Remote wipe via Intune (preferred, no physical access required):**

**Path:** `intune.microsoft.com > Devices > All devices > [legacy device record if still present, or use a fresh search] > Wipe`

> If the legacy record was already deleted in Step 1, the wipe must be done locally (Option B).

1. Select **Wipe**
2. Enable: **"Wipe device and continue to enrol the device even if wipe fails"**
3. Click **Wipe** — confirm

**Option B — Local factory reset (requires physical access):**

1. Settings > **System** > **Recovery** > **Reset this PC**
2. Select **Remove everything**
3. Select **Cloud download** (preferred over local reinstall — ensures a clean OS)
4. Confirm and allow to complete (~30–60 minutes)

**Expected result after this step:**  
Device boots to OOBE. No previous user profile, desktop, or Windows Hello PIN present. The screen shows the initial "Let's start with region" or organisation-branded Autopilot screen.

---

### Step 5 — Allow Autopilot to Complete

1. Connect to network at OOBE (Ethernet preferred)
2. Wait 30–60 seconds for the Autopilot deployment profile to load — the standard OOBE screens should be replaced by the organisation-branded setup screen
3. Do not intervene — allow all reboots to complete unattended
4. Provisioning is complete when the standard Windows sign-in screen appears

**Expected result after this step:**  
Device reaches the sign-in screen. Intune admin center shows a new device record with today's enrolment date and `Enrolment type: Autopilot`.

---

## 6. Verification — Confirming the Fix Worked

### Admin Center Checks

**Path:** `intune.microsoft.com > Devices > All devices > [new device record]`

| Check | Path | Expected Value |
|---|---|---|
| Enrolment type | Device overview | `Autopilot` |
| Enrolment date | Device overview | Today's date |
| Profiles applied | Device > Device configuration | All profiles: **Succeeded** (was 0 of 4) |
| Compliance | Device > Device compliance | **In grace period** or **Compliant** (not Failed or Pending >30 min) |
| Old record gone | Devices > All devices (search serial) | Only one record — today's date |

### Device-Side Checks

```powershell
# Confirm AAD join type and MDM enrolment type
dsregcmd /status
# Expected:
#   AzureAdJoined  : YES
#   MDMEnrolled    : YES
#   EnrollmentType : AzureAD   ← not "Manual"

# Confirm only one (new) enrolment GUID present
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments"
# Expected: one GUID only, EnrollmentStartDate = today

# Confirm no stale enrolment certificates remain
Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Issuer -like "*MDM*" }
# Expected: one certificate issued today
```

---

## 7. Rollback — If the Fix Makes Things Worse

This section covers the two most likely failure points during remediation.

---

### Scenario A — Wipe completes but Autopilot profile does not load at OOBE

**Symptom:** Device boots to standard Windows OOBE, no organisation branding appears after 5 minutes on a network connection.

**Cause:** Hardware hash is not registered in Autopilot, or profile assignment was lost.

**Action:**
1. Press `Shift + F10` at OOBE to open a command prompt
2. Run: `dsregcmd /status` — check `AzureAdPrt` and network connectivity
3. In Intune admin center — `Devices > Windows > Windows enrollment > Devices` — confirm serial is present with a profile assigned
4. If serial is absent: the hash was lost when the legacy cloud record was deleted (this should not happen but can occur if the hash was tied only to the old record). Re-capture the hardware hash:
   - At OOBE command prompt: `PowerShell` > `Install-Script -Name Get-WindowsAutopilotInfo -Force` > `Get-WindowsAutopilotInfo -Online`
   - Or collect the hash CSV and import it manually in the admin center
5. Wait 15 minutes after import, then run `shutdown /r /t 0` to restart and reload OOBE

---

### Scenario B — New enrolment completes but profiles still show Not Applicable or Error

**Symptom:** Device enrolls successfully (new Autopilot record in Intune) but one or more profiles show `Error` or `Not applicable` in Device configuration.

**Cause:** Profile assignment targets a group the device is not yet a member of, or a policy setting conflict with a surviving GPO.

**Action:**
1. `intune.microsoft.com > Devices > [device] > Device configuration` — click the failing profile
2. Check `Assignment filter` and `Assigned to group` — confirm the device or user is in the target group
3. Check `Error details` — note the specific CSP error code
4. If the error is `0x87D1FDE8` — the setting conflicts with an existing GPO. Identify via `gpresult /h c:\gpo.html` on the device and remove the conflicting GPO link.
5. Trigger a manual sync: `intune.microsoft.com > Devices > [device] > Sync`

---

## 8. Preventive Actions

### 8.1 Pre-Flight Audit — Before Next Autopilot Batch

Before importing any hardware hash for an existing device, run the following against the Intune export:

1. `intune.microsoft.com > Devices > All devices > Export` — download CSV
2. Open in Excel or PowerShell — filter:
   - `EnrollmentType` contains `Manual` OR `userEnrollment` OR `deviceEnrollmentManager`
   - `LastSyncDateTime` is older than 180 days from today
3. Cross-reference filtered list against the serial numbers queued for Autopilot import
4. For every match: retire the Intune record (`Devices > All devices > Retire`) then delete it, and delete the AAD object, before importing the hash

**PowerShell filter example (run against exported CSV):**
```powershell
Import-Csv "C:\IntuneExport.csv" |
    Where-Object {
        $_.EnrollmentType -match "Manual|userEnrollment|deviceEnrollmentManager" -and
        [datetime]$_.LastSyncDateTime -lt (Get-Date).AddDays(-180)
    } |
    Select-Object DeviceName, SerialNumber, EnrollmentType, LastSyncDateTime |
    Export-Csv "C:\LegacyEnrolmentRisk.csv" -NoTypeInformation
```

---

### 8.2 Autopilot Pre-Flight Checklist — Mandatory Before Hash Import

No hardware hash should be imported until the following are confirmed by the preparing engineer and recorded:

- [ ] Searched `Devices > All devices` — no existing Intune record for this serial
- [ ] Searched `entra.microsoft.com > Devices > All devices` — no existing AAD device object for this hostname/serial
- [ ] Device has been factory reset — OOBE reached, no previous profile present
- [ ] Hash captured from clean OOBE state (not from a running OS with existing enrolment)
- [ ] Hash imported and profile confirmed as assigned before device is sent to user

---

### 8.3 Intune Device Cleanup Rule

**Path:** `intune.microsoft.com > Tenant admin > Device cleanup rules`

Enable: **Delete devices that haven't checked in for this many days** — set to **90**

This automatically retires and deletes Intune records for devices offline for 90+ days, preventing accumulation of orphaned records that cause this failure.

> ⚠️ **Before enabling:** Communicate to stakeholders — devices belonging to users on long-term leave or stored as spares will be auto-retired. Review device groups and exclude any intentionally offline device pools before activating.

---

### 8.4 Scoped Query — Identify All At-Risk Devices in the Fleet Now

Run this regularly during the Autopilot migration wave to surface at-risk devices before they are submitted:

```powershell
# Requires Microsoft.Graph.Intune module
Connect-MSGraph
Get-IntuneManagedDevice -Filter "enrollmentType eq 'userEnrollment'" |
    Where-Object { $_.lastSyncDateTime -lt (Get-Date).AddDays(-180) } |
    Select-Object deviceName, serialNumber, enrollmentType, lastSyncDateTime |
    Export-Csv "C:\AtRiskDevices.csv" -NoTypeInformation
```

---

## 9. Related Incidents and Articles

| Reference | Type | Relationship |
|---|---|---|
| `RCA-Autopilot-Enrolment-Failure-0x80180014.md` | RCA | Source incident for this KB |
| `KE-MDM-2026-001` | Known Error | Single-field quick-reference for triage |
| `Autopilot-Enrolment-Failure-Analysis-0x80180014.md` | Analysis | Detailed diagnostic export and step-by-step remediation |
| `Comms-Autopilot-Enrolment-Failure-INC-AUTOPILOT-2026-0811.md` | Comms | Three-audience communications for this incident type |
| `KB-L1-Device-Setup-Not-Completing.md` | L1 KB | End-user self-service article for same symptom |
| `Intune-Compliance-Policy-Win11-Security-Baseline.md` | Policy | Compliance policy the device must meet post-enrolment |

**Potentially related error patterns (different root cause, similar symptoms):**
- Autopilot `0x80180018` — device not registered in Autopilot (missing hash). Resolution: import hash, not wipe.
- Autopilot `0x800705B4` — timeout during enrolment, often proxy or firewall blocking Intune endpoints. Resolution: check network connectivity to `*.manage.microsoft.com` and `*.microsoftazuread-sso.com`.
- `0x80070005` appearing without `0x80180014` — genuine CSP permissions issue, not an enrolment conflict. Investigate profile assignment and GPO conflicts instead.

---

*For questions about this article contact the DWP MDM team. Review date: 2026-11-11.*
