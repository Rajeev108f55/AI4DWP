# Triage Summary — Missing Desktop Shortcuts

## Summary (one line)
At least one Floor 6 user reports their desktop shortcuts have vanished.

## Impact (who / how many / business urgency)
- **Who:** At least one user — identity to confirm
- **How many:** 1 confirmed report; whether others are affected — to confirm
- **Business urgency:** to confirm — no explicit business priority or deadline stated in this issue

## Known Facts
- At least one user reported their desktop shortcuts have disappeared

## Missing Information to Gather
- Username/machine name of the affected user — to confirm
- Which shortcuts are missing (all, or specific apps) — to confirm
- Whether this is a local desktop, roaming profile, or AVD/VDI session — to confirm
- When the shortcuts disappeared and whether it correlates with a recent change (e.g., Friday's app rollout, profile reset, GPO change) — to confirm
- Whether the user can recreate the shortcuts manually or they reappear after relogin — to confirm
- Whether other Floor 6 users have the same symptom — to confirm

## Likely Category
Profile/Desktop configuration issue — possibly linked to profile corruption, roaming profile sync, or a recent application/GPO deployment; root cause not yet determined.

## Suggested First Diagnostic Step
Check the affected user's profile (local vs. roaming/FSLogix) and compare against a known-good profile to see if shortcut/config data was lost or not applied, and review whether the change coincides with Friday's application rollout.
