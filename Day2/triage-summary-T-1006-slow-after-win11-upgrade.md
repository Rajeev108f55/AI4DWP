# Triage Summary — T-1006: General Slowness Since Win11 Upgrade

## Summary
User reports "everything is slow" two days after upgrading to Windows 11.

## Impact
- **Who:** Single end user reporting (name/ID — to-verify).
- **How many affected:** 1; whether other users upgraded around the same time are also affected — to-verify.
- **Business urgency:** to-verify — no role/criticality stated; general slowness across all tasks can significantly impact productivity, but severity should be confirmed with the user/manager.

## Known Facts
- User's device was upgraded to Windows 11.
- Upgrade took place two days before this report.
- User describes performance as "everything is slow" (no specific app or task named).
- Ticket reference: T-1006.

## Missing Information to Gather
- User's name, ID, and contact details (to-verify).
- Device hostname/asset tag (to-verify).
- Whether this was an in-place upgrade from Windows 10 or a new device/reimage (to-verify).
- What "everything" covers — boot time, app launches, file access, browsing, all of the above (to-verify).
- Whether slowness is constant or worse at specific times (e.g. after login, during specific app use) (to-verify).
- Device age, specification (CPU/RAM/storage type), and whether it meets Windows 11 minimum requirements (to-verify).
- Whether Windows Update, driver installation, or AV scans are still completing post-upgrade (to-verify).
- Whether the user has rebooted since the upgrade, and result (to-verify).
- Disk space available post-upgrade (to-verify).
- Whether any specific error messages or on-screen warnings have appeared (to-verify, no codes to be assumed).
- Whether other recently upgraded devices show similar symptoms (to-verify).

## Likely Category
Endpoint performance — possible post-upgrade resource contention (e.g. driver compatibility, background optimisation tasks, disk/CPU load) following the Win11 migration. Category to confirm once more detail is gathered.

## Suggested First Diagnostic Step
Ask the user to open Task Manager and check CPU, Memory, and Disk usage during general use, to identify whether a background process (e.g. Windows Update, driver installation, AV scan, search indexing) still finishing post-upgrade tasks is consuming resources, which is common in the first few days after an OS upgrade.
