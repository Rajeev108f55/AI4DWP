# Closure Note — INC-AUTOPILOT-2026-0811
**Date Closed:** 2026-08-11  
**Reference:** INC-AUTOPILOT-2026-0811 / KE-MDM-2026-001

---

Resolved. Cause: Stale legacy manual MDM enrolment record from 2023-11-04 remained on both the device and in the Intune tenant; the Autopilot enrolment endpoint returned `0x80180014` (device already enrolled) blocking new enrolment and preventing all 4 configuration profiles from applying. Action: Deleted the legacy Intune device record and Azure AD device object from the admin center, wiped the device via Intune remote wipe, and re-triggered Autopilot from OOBE — all 4 profiles applied successfully and device reported compliant. Preventive: Autopilot pre-flight checklist to be enforced before any hardware hash import (confirm no existing Intune record or AAD object for the device serial); Intune device cleanup rule to be enabled (Tenant admin > Device cleanup rules > 90 days) to auto-retire orphaned records fleet-wide. User confirmed working.
