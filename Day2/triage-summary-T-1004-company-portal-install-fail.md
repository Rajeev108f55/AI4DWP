# Triage Summary — T-1004: Company App Install Fails from Company Portal

## Summary
Company app fails to install from Company Portal, showing error 0x87D1041C.

## Impact
- **Who:** User reporting (name/ID — to-verify); whether other users installing the same app are affected — to-verify.
- **How many affected:** 1 confirmed; scope beyond this user — to-verify.
- **Business urgency:** to-verify — no role/criticality stated; depends on whether the app is required for the user's immediate work.

## Known Facts
- User attempted to install a company app via Company Portal.
- Installation fails with error code 0x87D1041C (as reported by user).
- Ticket reference: T-1004.

## Missing Information to Gather
- User's name, ID, and contact details (to-verify).
- Device hostname/asset tag (to-verify).
- Name of the specific app that failed to install (to-verify).
- Exact point of failure — install doesn't start, fails partway through, or completes but app doesn't launch (to-verify).
- Whether this is the first install attempt or a reinstall/update of an existing app (to-verify).
- Whether other Company Portal apps install successfully on this device (to-verify).
- Device enrolment status in Intune/MDM — enrolled successfully, pending, or with errors (to-verify).
- Network/VPN connectivity at time of install attempt (to-verify).
- Available disk space on the device (to-verify).
- When this started, and whether it followed any recent change (OS update, re-enrolment, policy change) (to-verify).
- Whether the user has tried a retry, device restart, or re-sync of Company Portal, and the result (to-verify).

## Likely Category
Endpoint management / Intune-Company Portal app deployment issue. Category to confirm once more detail is gathered.

## Suggested First Diagnostic Step
Ask the user to open Company Portal, sync the device (Settings > Access Work/School Account > Info > Sync), and retry the install, while checking whether other apps deploy successfully on the same device — this helps distinguish an app-specific deployment issue from a broader device enrolment/policy sync problem.
