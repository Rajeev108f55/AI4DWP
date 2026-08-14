**Version:** v1.0 | **Date:** 14/08/2026 | **Status:** Draft

# KB-L2/L3 — Floor 6 Login Delay, System Slowness & Missing Mapped Drives (Post-Deployment Drive-Mapping Script Failure)

## Background

Floor 6 devices use a drive-mapping mechanism (script-based) executed at logon to
connect users to their network shared drives (e.g., `S:`). This mechanism is
typically delivered either as a GPO logon script (running in **USER** context) or
as an Intune platform script/Win32 app dependency (running in **SYSTEM** context).

This matters because:
- Users depend on mapped drives to access shared/team files immediately after login.
- A script that hangs or retries against an unreachable network path will delay the
  entire logon sequence for the user, not just the drive mapping step.
- Application deployments to a floor/device group can unintentionally change the
  execution context, timing, or network dependencies of these logon scripts.

## Symptom

**What the engineer observes:**
- Dozen+ Floor 6 devices show abnormally long logon duration (well beyond the site's
  baseline logon time).
- Drive letter(s) normally mapped at logon (e.g., `S:`) are absent after logon completes.
- General system responsiveness is degraded on affected devices even after logon.

**What the user reports:**
- "Login is taking forever" / can't log in.
- Desktop shortcuts/mapped drives have "vanished."
- (Separately reported, track independently) unexpected data visible in Copilot — see Related section.

## Root Cause

The specific technical cause (pending confirmation via Detection steps below) is a
**drive-mapping logon script failure caused by Friday's document management app
deployment** — matching the previously confirmed pattern in `Known-Error-FIN-001`:
a script was migrated to run as SYSTEM (or its execution path/timing was altered by
the new app package) but was not updated for the new execution context, so it cannot
reach the network share (e.g., `\\<fileserver>\<share>`) and fails with
**"Network name cannot be found."** The failed/retrying script blocks or delays the
rest of the logon sequence, and because it fails, the drive letter is never assigned.

**Evidence that confirms it:**
- Intune Management Extension log shows the drive-mapping script starting in SYSTEM
  context, followed by a warning that the UNC path is unreachable, and error
  `Network name cannot be found`, with no retry configured.
- System event log shows **Event ID 1500** (Group Policy processing succeeded — rules
  out GPO processing itself as the cause) immediately followed by **Event ID 98**
  (NTFS — drive letter not assigned).
- Timestamps of the failure align with Friday's deployment window, not with any
  prior baseline.

## Detection

Confirm this is the issue **before taking any resolution action**. Perform all of
the following on at least one confirmed affected device, and compare against one
confirmed unaffected device (comparison check):

1. **Intune Management Extension log** — path:
   `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`
   Look for: the drive-mapping script name (e.g., `Map-<Floor6App>Drives.ps1`)
   starting in SYSTEM context, followed by `Network name cannot be found` and no
   successful completion line. **Compare:** this error should be present on affected
   devices and absent on the unaffected comparison device.

2. **System Event Log — Group Policy** — path: Event Viewer > Windows Logs > System.
   Filter: `Event ID = 1500`, Source = `Microsoft-Windows-GroupPolicy`.
   Look for: Event ID 1500 present (confirms GPO processing itself succeeded, so the
   fault is not GPO application). **Compare:** should be present on both affected and
   unaffected devices (rules out GPO as the differentiator).

3. **System Event Log — NTFS drive mapping** — path: Event Viewer > Windows Logs > System.
   Filter: `Event ID = 98`, Source = `Ntfs`.
   Look for: Event ID 98 indicating the drive letter (e.g., `S:`) was not assigned.
   **Compare:** should be present only on affected devices; absent on the unaffected
   comparison device.

4. **GPResult report** — run `gpresult /h gpresult.html /f` on the affected device.
   Look for: the drive-mapping GPO/script listed as applied, with no error banner in
   the report itself (this isolates the fault to script execution, not policy delivery).

5. **Intune app deployment timeline** — Microsoft Intune admin center path:
   **Apps > All apps > [Document Management App name] > Assignments**, then
   **Apps > Monitor > App install status**, filtered to the Floor 6 device group.
   Look for: install/update timestamps on Friday aligning with the first occurrence
   of the Event ID 98 / IME log errors above.

If all five checks align (log error present + Event ID 1500 present + Event ID 98
present + GPResult shows no policy delivery fault + Friday deployment timestamp
match on affected devices only), the root cause is confirmed.

## Resolution

Step-by-step fix, with exact portal paths and expected result after each step:

1. **Sign in to Microsoft Intune admin center** at `https://intune.microsoft.com`
   *(elevated permission required: Intune Administrator or App Manager role)*.
   *Expected result:* Intune admin center home page loads.

2. **Navigate to: Groups > All groups > [Floor 6 deployment ring group name]
   > Members.**
   *Expected result:* You see the list of devices currently in the Friday deployment ring.

3. **Remove the confirmed affected device(s) from this group**, using
   **Members > Remove**, or via Graph PowerShell (see
   [Resolution-Floor6-Login-Issues-20260814.md](Resolution-Floor6-Login-Issues-20260814.md)
   for the exact command).
   *Expected result:* Device no longer listed under the group's Members tab.

4. **Navigate to: Apps > All apps > [Document Management App name] > Monitor >
   Device install status.**
   *Expected result:* The removed device no longer appears as a pending/managed
   target for this app's assignment.

5. **Ask the affected user to restart the device and log in again.**
   *Expected result:* Logon completes within the site's normal baseline duration and
   the mapped drive (e.g., `S:`) appears.

6. **Re-run the Detection steps (1–3) on the same device.**
   *Expected result:* No new IME script error, no new Event ID 98 entries after the
   restart.

## Verification

Before closing the incident, confirm all of the following:

- [ ] Affected device(s) log in within the site's normal baseline duration.
- [ ] Mapped drive(s) are present without manual intervention.
- [ ] No new Event ID 98 entries appear in the System log after the fix (checked via
  Event Viewer or a fresh run of `Script-AI generated-Evidence-Collection-DriveMapping.ps1`).
- [ ] At least 2–3 of the originally affected dozen+ users independently confirm
  resolution (not just the one test device).
- [ ] No repeat reports from Floor 6 in the next login cycle (e.g., following morning).

## Rollback

If removing the device from the deployment ring group does not resolve the issue,
or introduces a new problem (e.g., the user now lacks the app they need):

1. **Re-add the device to the deployment ring group:** Intune admin center >
   **Groups > All groups > [Floor 6 deployment ring group name] > Members > Add members**,
   select the device, and save.
   *Expected result:* Device reappears in the group's Members list.

2. **If the app assignment intent was changed to Uninstall, revert it:** Intune
   admin center > **Apps > All apps > [Document Management App name] > Properties >
   Assignments**, change the intent back to its pre-incident value (Available or
   Required) for the Floor 6 group, and select **Review + Save**.
   *Expected result:* Assignment intent shown in the Assignments blade matches the
   pre-incident configuration.

3. **Force a device check-in:** Intune admin center > **Devices > All devices >
   [device name] > Sync**.
   *Expected result:* "Last check-in" timestamp for the device updates within a few minutes.

4. **If the device is now in a worse state (e.g., broken profile, no login at all),
   stop making further changes and escalate to the desktop engineering escalation
   team, attaching the evidence folder generated by
   `Script-AI generated-Evidence-Collection-DriveMapping.ps1`.**
   *Expected result:* Ticket is reassigned/escalated with evidence attached; no
   further changes made until escalation team responds.

## Preventive

Specific changes to process/tooling to stop this recurring:

1. **Require a pre-deployment UNC reachability test** as a mandatory pipeline step
   for any script bundled with an app package that maps network drives — the
   pipeline must run the script in the exact target execution context (SYSTEM vs
   USER) against a pilot device before floor-wide assignment is enabled in Intune.
2. **Add a retry-with-logging wrapper** to all drive-mapping scripts so that a
   network path failure is logged with a distinct, searchable event/error string
   (e.g., a custom Event ID in the Application log) instead of only surfacing in the
   IME log, reducing detection time.
3. **Change the Intune deployment ring structure** so new app packages are assigned
   first to a pilot ring group (5–10 devices) with a mandatory 1-business-day bake
   period before assignment to a full-floor group, replacing the current
   floor-wide-on-first-push assignment pattern.
4. **Add execution-context validation** to the app packaging checklist: any script
   migrated from a GPO logon script (USER context) to an Intune Win32
   app/PowerShell script (SYSTEM context) must be explicitly re-tested for
   SYSTEM-context network access before sign-off, per the corrective action already
   defined in `Known-Error-FIN-001`.

## Related

- `Known-Error-FIN-001` — Finance Shared Drive Mapping Failure in SYSTEM Context
  (same failure pattern, different floor/share).
- [Ranked-Login-issues-Floor6-20260814.md](Ranked-Login-issues-Floor6-20260814.md) — full ranked cause analysis for this incident.
- [Resolution-Floor6-Login-Issues-20260814.md](Resolution-Floor6-Login-Issues-20260814.md) — resolution actions and Floor 6 communication.
- [Runbook-Floor6-Login-Issues-20260814.md](Runbook-Floor6-Login-Issues-20260814.md) — Tier 1/2 runbook for this incident.
- [Escalation-Copilot-Unauthorized-Access-Incident-20260814.md](Escalation-Copilot-Unauthorized-Access-Incident-20260814.md) — separately tracked security incident reported on the same floor; do not conflate with this drive-mapping issue.
- [KB-L1-Floor6-Login-Slowness-20260814.md](KB-L1-Floor6-Login-Slowness-20260814.md) — end-user self-service article for this incident.
