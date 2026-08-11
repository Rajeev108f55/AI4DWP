# Known Error Record — DWP Knowledge Base
**KE ID:** KE-MDM-2026-001  
**Date Raised:** 2026-08-11  
**Raised By:** DWP Analyst  
**Status:** Active  
**Source RCA:** RCA-Autopilot-Enrolment-Failure-0x80180014.md

---

**Symptom:**  
The device fails Windows Autopilot enrolment and the user cannot access corporate resources. Zero of the expected Intune configuration profiles are applied, leaving the device unmanaged and non-compliant.

**Cause:**  
The device has a stale legacy manual MDM enrolment record from a previous Intune enrolment (confirmed source: manual enrolment dated 2023-11-04) that was never retired or deleted. The Intune enrolment endpoint blocks Autopilot from creating a new enrolment while the old record exists on both the device and in the tenant.

**Scope:**  
Affects any Windows device that was previously manually enrolled in Intune and is being submitted for Autopilot migration without a factory reset. Both the device-side MDM state and the cloud-side Intune and Azure AD records must be stale for this to fire; licensing, network, and hardware hash registration are not factors.

**Workaround:**  
In Intune admin center, delete the legacy device record (Devices > All devices) and the legacy Azure AD device object (Entra admin center > Devices > All devices). Then wipe the device (Intune > Devices > Wipe or local factory reset) and re-trigger Autopilot from OOBE. Cloud records must be deleted before the wipe — reversing the order reproduces the same failure.

**Permanent Fix:**  
Enforce the Autopilot pre-flight checklist (confirm no existing Intune record or AAD object for the device serial before importing the hardware hash) and enable the Intune device cleanup rule (Tenant admin > Device cleanup rules > delete devices not checked in for 90 days) to prevent orphaned records from accumulating.

**How to Spot It:**  
MDM diagnostic export shows `ErrorCode: 0x80180014` with `ErrorDescription: The device is already enrolled in MDM` and `MDMEnrolled: Yes` with an enrolment date predating the current migration. Secondary signal: `ProfilesApplied: 0 of 4` with `LastError: 0x80070005 (Access denied)` — this access-denied error is a downstream symptom of the enrolment conflict, not a standalone permissions issue. Check `HKLM:\SOFTWARE\Microsoft\Enrollments` on the device; more than one GUID or a GUID with a pre-migration date confirms stale local MDM state.
