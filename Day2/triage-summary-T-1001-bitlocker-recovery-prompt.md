# Triage Summary — T-1001: BitLocker Recovery Key Prompt Every Boot

## Summary
New Win11 laptop (T-1001) is prompting for the BitLocker recovery key on every boot.

## Impact
- **Who:** Single end user reporting (name/ID — to-verify).
- **How many affected:** 1 (whether other new-build devices are similarly affected — to-verify).
- **Business urgency:** to-verify — no role/criticality stated; being locked out at every boot blocks device use entirely, which is typically high priority, but should be confirmed with the user/manager.

## Known Facts
- Device is a new Windows 11 laptop.
- BitLocker recovery key prompt appears on every boot (not a one-off event).
- Ticket reference: T-1001.

## Missing Information to Gather
- User's name, ID, and contact details (to-verify).
- Device hostname/asset tag (to-verify).
- When this started — first boot after receiving the device, or after a specific event (update, reboot, docking/undocking, BIOS/firmware change) (to-verify).
- Whether the user has a recovery key available (e.g. via Microsoft/Entra account, or provided by IT at build time) and whether entering it lets the device boot normally (to-verify).
- Whether TPM is present/enabled in BIOS/UEFI, and whether Secure Boot settings have been changed (to-verify).
- Any recent changes: BIOS/firmware update, hard drive/hardware change, docking station changes, or Boot order changes (to-verify).
- Whether this is a pooled/shared device or the user's first time using it (to-verify).
- Whether Autopilot/Intune/MDM enrolment completed successfully on this build (to-verify).
- Any on-screen text or prompt wording exactly as shown (no error codes to be assumed — capture verbatim if the user can share it) (to-verify).

## Likely Category
Endpoint security / BitLocker-TPM configuration issue — possibly related to new-build provisioning (e.g. TPM/Secure Boot state not finalised, or a firmware/config change triggering a new recovery key requirement). Category to confirm once more detail is gathered.

## Suggested First Diagnostic Step
Ask the user to check BIOS/UEFI for TPM and Secure Boot status (enabled/unchanged), and confirm whether entering the recovery key allows a normal boot — this indicates whether the issue is a one-off TPM/PCR measurement change (e.g. from a recent firmware update) versus a persistent hardware/config fault requiring escalation.
