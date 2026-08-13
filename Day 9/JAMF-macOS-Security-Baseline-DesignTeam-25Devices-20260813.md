# JAMF Translation - macOS Security Baseline (Design Team, 25 Devices)

Date: 2026-08-13  
Audience: DWP engineering and endpoint compliance operations

## Scope and Caution
This document maps baseline security requirements to JAMF configuration profile settings for macOS.

Important verification discipline:
- JAMF UI labels, payload grouping, and option wording can change by Jamf Pro version and Apple OS generation.
- Treat payload names and exact field labels below as implementation guidance, not immutable strings.
- Verify each setting path and label in your own JAMF instance before production rollout, same operational discipline used in Day 6 Intune labs.

## Baseline-to-JAMF Mapping

| # | Requirement | Payload type (JAMF) | Value | Effect | False-positive risk |
|---|-------------|---------------------|-------|--------|---------------------|
| 1 | FileVault disk encryption must be enabled | Disk Encryption (FileVault) payload in a Configuration Profile (or FileVault policy controls, depending on Jamf version/workflow) | Enable FileVault for managed users; escrow personal recovery key to JAMF (or institutional key if used by policy) | Encrypts disk at rest so data is inaccessible without authorized unlock credentials | Devices can be healthy but report non-compliant during key escrow delay, first encryption cycle, deferred enablement window, or if inventory is stale |
| 2 | Gatekeeper must be enabled (identified developers only) | Restrictions payload or Security & Privacy/Privacy Preferences area (naming varies by Jamf version) | Allow apps from App Store and identified developers; do not allow Anywhere | Blocks unsigned/untrusted applications while permitting signed developer apps | Local admin temporary overrides, delayed inventory, or app launch prompts pending user approval can make compliant devices appear out of policy briefly |
| 3 | Minimum macOS version: current stable minus one point release | Software Updates payload plus Smart Group/compliance scoping logic (OS version criteria) | Enforce minimum OS version equal to N-1 (current stable minus one point release); notify/force update by maintenance window | Prevents devices from remaining on unsupported or lagging OS minor versions | Devices can false-flag when Apple releases update metadata before device catalog refresh, during phased rollout windows, or when version parsing/group criteria are mis-scoped |
| 4 | Firewall must be enabled | Security & Privacy payload (Firewall controls) | Enable Application Firewall; optionally enable stealth mode per security standard | Reduces inbound attack surface by blocking unauthorized inbound connections | Third-party firewall products, duplicate profiles, or delayed MDM status updates can report transient mismatch |
| 5 | Login password required after sleep/screen saver | Security & Privacy payload (General/password lock) or Login Window controls where applicable | Require password immediately after sleep or screen saver starts (grace period = 0 or approved short value) | Prevents unattended-session access after idle/sleep | User session state timing, screensaver vs display sleep differences, and delayed profile application can produce temporary false non-compliance |
| 6 | Automatic software updates must be enabled for security updates | Software Update payload | Enable automatic check/download/install for security updates (and critical/system data files as required by policy) | Ensures security patches are applied without relying only on user action | Deferrals, power/network constraints, APNS/check-in delays, and Apple update catalog latency can show compliant devices as pending/non-compliant |

## Version-Sensitive Label Flags (Must Validate in Your JAMF)
The following are especially likely to have naming/path differences across Jamf Pro versions and modern macOS releases:
- Gatekeeper setting location and wording (Restrictions vs Security-oriented payload areas)
- Software update keys for automatic security updates and enforcement behavior
- Minimum OS enforcement implementation split between profile payload and Smart Group/compliance rules
- FileVault enablement workflow split between Configuration Profile and FileVault policy UI patterns

## Operational Recommendations for This 25-Device Design Fleet
- Pilot on 3 to 5 representative design endpoints before full 25-device rollout.
- Use a dedicated Smart Group for pilot compliance and event log review.
- Validate recovery key escrow success before broad FileVault enforcement.
- Time update enforcement to avoid active production design hours.
- Reconcile compliance using both profile state and latest inventory timestamp to reduce false positives.

## Quick Validation Checklist After Deployment
- FileVault status: On, and recovery key escrowed.
- Gatekeeper mode: App Store + identified developers only.
- OS version: Meets N-1 floor.
- Firewall: Enabled.
- Password on wake/screensaver: Required immediately or approved grace.
- Security auto-updates: Enabled and receiving updates.
