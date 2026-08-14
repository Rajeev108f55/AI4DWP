# Runbook — Floor 6 Login Delay, System Slowness & Missing Mapped Drives

**Incident context:** Floor 6, following Friday's document management app deployment.
**Related documents:** [Ranked-Login-issues-Floor6-20260814.md](Ranked-Login-issues-Floor6-20260814.md), [Resolution-Floor6-Login-Issues-20260814.md](Resolution-Floor6-Login-Issues-20260814.md), [Script-AI generated-Evidence-Collection-DriveMapping.ps1](Script-AI%20generated-Evidence-Collection-DriveMapping.ps1)

---

## 1. Prerequisites

Before starting, confirm you have:

- **Access rights:**
  - Local admin rights on at least one affected Floor 6 device *(elevated permission required)*
  - Intune/Microsoft Graph role with `DeviceManagementApps.ReadWrite.All` and `GroupMember.ReadWrite.All` scopes, or equivalent Intune admin portal access *(elevated permission required)*
- **Tools:**
  - PowerShell 5.1 or later on the affected device
  - Microsoft Graph PowerShell SDK (`Microsoft.Graph` module) installed on your admin workstation
  - The evidence collection script: `Script-AI generated-Evidence-Collection-DriveMapping.ps1`
- **System/info to have on hand:**
  - Name (hostname) of at least one confirmed affected Floor 6 device
  - The Intune app name/ID for Friday's document management app deployment — **to confirm** before Step 6
  - The deployment ring/assignment group name or ID used for Friday's rollout — **to confirm** before Step 6
- **Access to:** Intune admin center (or Graph PowerShell), the affected device (remote or in person)

---

## 2. Procedure

Perform steps in order. Each step is a single action with its expected result.

1. **Log the incident start time and affected device list in the incident ticket.**
   *Expected result:* Ticket has a timestamp and at least one confirmed affected device name.

2. **Connect to the affected Floor 6 device (remote session or in person) using an account with local admin rights.** *(elevated permission required)*
   *Expected result:* You have an active session on the affected device.

3. **Copy `Script-AI generated-Evidence-Collection-DriveMapping.ps1` to the affected device.**
   *Expected result:* The script file exists locally on the affected device.

4. **Run the script in dry-run mode first: `.\Script-AI generated-Evidence-Collection-DriveMapping.ps1 -DryRun`.**
   *Expected result:* The console/log shows a baseline version banner and a list of files/actions that *would* be collected, with no files actually copied.

5. **Run the script for real: `.\Script-AI generated-Evidence-Collection-DriveMapping.ps1`.** *(elevated permission required if source log paths need admin access)*
   *Expected result:* An evidence folder is created under `C:\DWP-Evidence\Floor6-LoginIssue\<RunId>` containing copied Intune Management Extension logs, `gpresult.html`, and `GroupPolicy-NTFS-Events.csv`, plus a summary printed at the end of the run.

6. **Open `gpresult.html` and `GroupPolicy-NTFS-Events.csv` from the evidence folder and check for a drive-mapping script error (e.g., "Network name cannot be found") around the time of Friday's deployment.**
   *Expected result:* You either confirm the drive-mapping/logon script failure (Event ID 1500 present, Event ID 98 present, script error visible in IME log) or rule it out.

7. **If confirmed: identify the Intune app name/ID and deployment ring group ID for Friday's document management app rollout in the Intune admin center.**
   *Expected result:* You have the exact App ID and Ring Group ID recorded in the ticket.

8. **Connect to Microsoft Graph: `Connect-MgGraph -Scopes "GroupMember.ReadWrite.All","Device.Read.All"`.** *(elevated permission required)*
   *Expected result:* `Connect-MgGraph` returns a successful authenticated context (no error).

9. **Remove the affected device(s) from the deployment ring group, using the confirmed Ring Group ID and device name(s) from Step 1/7:**
   ```powershell
   $RingGroupId = "<confirmed-ring-group-id>"
   $device = Get-MgDevice -Filter "displayName eq '<affected-device-name>'"
   Remove-MgGroupMemberByRef -GroupId $RingGroupId -DirectoryObjectId $device.Id
   ```
   *Expected result:* Command returns without error; the device no longer appears in the ring group's member list in Intune.

10. **Ask the affected user to restart the device and log in again.**
    *Expected result:* User reports login completes in normal time and mapped drives (e.g., `S:`) appear.

11. **Send the plain-language update to Floor 6 (from [Resolution-Floor6-Login-Issues-20260814.md](Resolution-Floor6-Login-Issues-20260814.md)) once Step 10 is confirmed on at least one device.**
    *Expected result:* Floor 6 users have received an update; ticket is updated with the communication timestamp.

---

## 3. Verification

Before closing the incident, confirm **all** of the following:

- [ ] The previously affected device logs in within normal time (no more than the site's standard baseline logon duration).
- [ ] Mapped drive(s) (e.g., `S:`) are present and accessible after login, with no manual re-mapping needed.
- [ ] No new Event ID 98 (NTFS drive mapping failure) entries appear in the System log after the fix, checked via a fresh run of the evidence script (`-MinAgeDays 0`) or `Get-WinEvent`.
- [ ] At least 2–3 of the originally reported dozen+ users confirm the issue is resolved (not just the one test device).
- [ ] No new reports of the same symptom from Floor 6 in the following login cycle (e.g., next morning).

Only close the ticket once every box above is checked.

---

## 4. Rollback

If removing the device(s) from the deployment ring (Step 9) does **not** resolve the issue, or causes a new problem (e.g., the app is now missing but the user needs it):

1. **Re-add the device to the deployment ring group immediately:**
   ```powershell
   New-MgGroupMemberByRef -GroupId $RingGroupId -DirectoryObjectId $device.Id
   ```
   *Expected result:* Device reappears in the ring group's member list.

2. **If the app was already set to "Uninstall" via assignment change, revert the assignment intent back to "Available" or "Required" (whichever it was before) in the Intune admin center for that app and group.**
   *Expected result:* App assignment intent shown in Intune matches its pre-incident state.

3. **Force an Intune sync on the affected device to reapply the original assignment:**
   ```powershell
   # Run locally on the affected device (elevated permission required)
   Get-ScheduledTask -TaskName "PushLaunch" | Start-ScheduledTask
   ```
   or trigger **Sync** from the Intune portal (Devices > affected device > Sync).
   *Expected result:* Device check-in timestamp updates in Intune within a few minutes.

4. **If the device is now in a worse state (e.g., broken profile, no login at all), do not attempt further changes — escalate to the Tier 2/3 desktop engineering team with the evidence folder attached and mark the ticket as a major incident.**
   *Expected result:* Ticket is escalated with evidence attached; no further changes are made by Tier 1 until Tier 2/3 responds.

---

## 5. Notes

- **Edge case:** If the paralegal's Copilot data exposure report (see [Escalation-Copilot-Unauthorized-Access-Incident-20260814.md](Escalation-Copilot-Unauthorized-Access-Incident-20260814.md)) is linked to the same user/device, do **not** treat it as resolved by this runbook — it must be handled separately by the security/data protection team regardless of login fix status.
- **Warning:** Removing a device from the deployment ring only stops *future* policy/app processing for that device — it does not undo changes the app may have already made (e.g., partially written profile data). If issues persist after Step 9, investigate profile corruption as the next most-likely cause (see [Ranked-Login-issues-Floor6-20260814.md](Ranked-Login-issues-Floor6-20260814.md), cause #3).
- **Related known error:** This incident matches the pattern of `Known-Error-FIN-001` (drive-mapping script failing in SYSTEM context after migration from GPO logon script to Intune script) — reference that known error record when writing the permanent fix.
- **Do not** close this incident as "AI weirdness" or unrelated if any Copilot data-access reports come in from the same floor during this window — treat as a separate, security-tracked issue per the escalation note above.
