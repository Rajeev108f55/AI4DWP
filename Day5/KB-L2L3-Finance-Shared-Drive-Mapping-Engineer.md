# KB Article - Finance Shared Drive Missing After Sign-In (L2/L3 Engineer)

| Field | Detail |
|---|---|
| Version | v 1.0 |
| Date | 07/08/2026 |
| Status | Draft |

## Background

Finance users receive access to the Finance shared folder during sign-in through the script Map-FinBridgeDrives.ps1. The script maps drive letter S: to \\finbridge-fs01\\Finance. This matters because Finance daily processing depends on that mapped drive being available immediately after sign-in.

## Symptom

### What users report
- Finance shared drive S: is missing after sign-in.
- File Explorer cannot open Finance shared folder.
- Some users may see a network name error.

### What the engineer observes
- Affected endpoint shows no S: mapping in user session.
- Group Policy appears successful, but mapping still fails.
- Incident is limited to Finance scope.

### Comparison check: affected user vs unaffected user
- Affected user on DESKTOP-FB* device: S: missing, Event ID 98 present.
- Unaffected user on non-impacted device: S: present, no new Event ID 98 at sign-in.

## Root Cause

The script Map-FinBridgeDrives.ps1 was moved from user logon execution to Intune Platform script execution as SYSTEM, but the script still required user-context access to \\finbridge-fs01\\Finance. In SYSTEM context, the script failed with Network name cannot be found, so S: was never created.

Evidence confirming this cause:
- Intune Management Extension log shows script context as SYSTEM and script failure on UNC path access.
- System Event ID 1500 shows Group Policy succeeded, ruling out a GPO engine failure.
- System Event ID 98 shows S: was not assigned.
- Event ID 7036 confirms Workstation service running, so the failure is context/path access, not service stopped.

## Detection

Run the fast path below first. Target: confirm or reject this issue in under 3 minutes.

### 3-minute fast path (PowerShell)

1. Open Windows PowerShell as administrator on an affected endpoint.
Expected result: Elevated PowerShell window opens.

2. Run this command to capture required System log events (exact Event IDs 7036, 1500, and 98).
```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; Id=7036,1500,98} -MaxEvents 60 |
Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message |
Sort-Object TimeCreated
```
Expected result: Output includes events from the System log with IDs 7036, 1500, and 98.

3. Run this command to capture Intune script execution evidence.
```powershell
Select-String -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" -Pattern "Map-FinBridgeDrives.ps1|SYSTEM account|not accessible from SYSTEM context|Network name cannot be found|exit code 1" | Select-Object -Last 20
```
Expected result: Output shows script execution lines for `Map-FinBridgeDrives.ps1` in SYSTEM context and failure text.

4. Run this command in the same user session to confirm mapped drive state.
```powershell
Get-PSDrive -Name S -ErrorAction SilentlyContinue
```
Expected result: On affected endpoint, no valid S: mapping is returned.

### What to confirm in logs (exact locations and fields)

1. Confirm Group Policy success event.
Log location: Event Viewer > Windows Logs > System
Event ID: 1500
Field to check: General message contains "Group Policy settings processed successfully"
Confirmed when: Event ID 1500 is present in the incident sign-in window.

2. Confirm Workstation service running event.
Log location: Event Viewer > Windows Logs > System
Event ID: 7036
Field to check: General message contains "Workstation service entered running state"
Confirmed when: Event ID 7036 is present before or near the mapping failure.

3. Confirm drive mapping failure event.
Log location: Event Viewer > Windows Logs > System
Event ID: 98
Field to check: General message contains "File system could not map drive letter S:" and "drive letter has not been assigned"
Confirmed when: Event ID 98 appears after Event ID 1500.

4. Confirm script context mismatch evidence.
Log location: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log
Field to check: Line contains "Executing: Map-FinBridgeDrives.ps1"
Field to check: Line contains "Script context: SYSTEM account"
Field to check: Line contains "Network name cannot be found"
Confirmed when: All lines appear in the same sign-in execution window.

### Comparison baseline (affected vs unaffected)

1. Repeat the same System log command on one unaffected endpoint/user.
Expected unaffected result: No new Event ID 98 in the same time window and `Get-PSDrive -Name S` returns S: mapped.

2. Use this baseline statement for final confirmation against change records:
"Drive mapping script migrated from GPO logon script (runs as USER) to Intune PowerShell script (runs as SYSTEM). Script not updated to handle SYSTEM context - network paths via UNC require the Workstation service and mapped credentials which are not available to SYSTEM at login time"

Diagnosis is confirmed only when Event IDs 7036, 1500, and 98 match as above, Intune log shows SYSTEM-context script failure, and unaffected comparison endpoint remains healthy.

## Resolution

Perform in this order. Target completion: 5 to 10 minutes.

1. Open Azure portal path: `https://portal.azure.com` -> All services -> Microsoft Intune -> Devices -> Scripts and remediations -> Platform scripts.
Expected result: Platform scripts list is visible.

2. Select `Map-FinBridgeDrives.ps1`.
Expected result: Script overview blade opens.

3. Select Properties -> Script settings -> Edit.
Expected result: Script settings editor opens.

4. Set Run this script using the logged on credentials = `Yes`.
Expected result: Setting is visibly set to Yes before saving.

5. Select Review + save.
Expected result: Notification shows settings update succeeded.

6. Select Assignments -> Edit included groups.
Expected result: Assignment group picker opens.

7. Remove one non-Finance group.
Expected result: That group disappears from included groups.

8. Repeat step 7 until only Finance scope groups remain (for example `OU=Finance`; if your environment uses floor-based OUs, keep only the affected floor OU such as `OU=Floor3`).
Expected result: Included groups list contains only intended affected scope.

9. Select Save on assignments.
Expected result: Notification shows assignment update succeeded.

10. Open Azure portal path: Microsoft Intune -> Devices -> All devices -> `DESKTOP-FB041` -> Sync.
Expected result: Sync action accepted.

11. Wait 5 minutes.
Expected result: Device has received latest policy and script config.

12. Sign in to `DESKTOP-FB041` with an affected Finance user.
Expected result: User reaches desktop without mapping pop-up error.

13. Run `Get-PSDrive -Name S` in user PowerShell.
Expected result: Output shows `Name : S` and `Root : \\finbridge-fs01\\Finance`.

14. Run `gpresult /scope:user /r` in Command Prompt.
Expected result: Output shows applied user policy objects and confirms expected Finance/floor scope policy is applied to the user session.

### Azure CLI fast path (optional)

Use this for faster execution than portal clicks.

```bash
# 1) Get script ID
az rest --method get \
	--url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts?$filter=displayName eq 'Map-FinBridgeDrives.ps1'"

# 2) Set script to run in user context (replace <SCRIPT_ID>)
az rest --method patch \
	--url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/<SCRIPT_ID>" \
	--headers "Content-Type=application/json" \
	--body "{\"runAsAccount\":\"user\"}"

# 3) Get managed device ID for affected device
az rest --method get \
	--url "https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter=deviceName eq 'DESKTOP-FB041'"

# 4) Trigger sync (replace <MANAGED_DEVICE_ID>)
az rest --method post \
	--url "https://graph.microsoft.com/beta/deviceManagement/managedDevices/<MANAGED_DEVICE_ID>/syncDevice"
```

## Verification

1. Open Event Viewer on fixed device.
Path: Event Viewer -> Windows Logs -> System
Check: Filter Current Log for Event IDs `7036,1500,98`.
Pass: Event 7036 and Event 1500 present after latest sign-in, and no new Event 98 after fix timestamp.

2. Run user-session mapping check.
Command: `Get-PSDrive -Name S`
Pass: `Name : S` and `Root : \\finbridge-fs01\\Finance` returned.

3. Run UNC reachability check.
Command: `Test-Path "\\finbridge-fs01\\Finance"`
Pass: Returns `True`.

4. Confirm user policy scope on affected machine.
Command: `gpresult /scope:user /r`
Pass: Expected Finance/floor user GPO scope appears as applied.

5. Compare with unaffected endpoint.
Path: Event Viewer -> Windows Logs -> System on unaffected device.
Check: Same Event ID filter `7036,1500,98` and user mapping command.
Pass: Unaffected device has no new Event 98 and S: is mapped.

### Azure CLI / PowerShell quick verification

```powershell
# On affected endpoint: verify required System events quickly
Get-WinEvent -FilterHashtable @{LogName='System'; Id=7036,1500,98} -MaxEvents 40 |
Select-Object TimeCreated, Id, ProviderName, Message

# On affected endpoint: verify mapping and path
Get-PSDrive -Name S
Test-Path "\\finbridge-fs01\\Finance"
```

## Rollback

Use rollback if failures increase or wider user impact begins after change.

1. Open Azure portal path: `https://portal.azure.com` -> Microsoft Intune -> Devices -> Scripts and remediations -> Platform scripts -> `Map-FinBridgeDrives.ps1` -> Properties -> Script settings -> Edit.
Action: Restore pre-change value for Run this script using the logged on credentials.
Expected result: Setting matches pre-change ticket backup.

2. Open Azure portal path: `Map-FinBridgeDrives.ps1` -> Assignments -> Edit included groups.
Action: Remove all affected Finance/floor groups from assignment.
Expected result: No affected groups are targeted by the Intune script.

3. Open console path: `gpmc.msc` -> Forest -> Domains -> production domain -> OU=Finance (or affected floor OU such as OU=Floor3).
Action: Link or re-enable known-good logon script GPO.
Expected result: GPO status is Linked and Enabled.

4. Open console path: Group Policy Management -> OU target -> linked GPO -> Edit -> User Configuration -> Policies -> Windows Settings -> Scripts (Logon/Logoff) -> Logon.
Action: Confirm known-good mapping script path is present.
Expected result: Logon script entry exists and matches change record.

5. On one affected endpoint, run `gpupdate /force`.
Expected result: Computer Policy and User Policy updates complete successfully.

6. On same endpoint, run `gpresult /scope:user /r` and `Get-PSDrive -Name S`.
Expected result: Correct user GPO shows as applied and S: mapping is restored.

7. Post incident update: rollback active and Intune script unassigned from affected scope.
Expected result: Incident timeline and support team state are aligned.

### Azure CLI fast rollback (optional)

```bash
# 1) Restore script context to previous value (example: system). Replace <SCRIPT_ID>
az rest --method patch \
	--url "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/<SCRIPT_ID>" \
	--headers "Content-Type=application/json" \
	--body "{\"runAsAccount\":\"system\"}"

# 2) Trigger device sync again after assignment rollback
az rest --method post \
	--url "https://graph.microsoft.com/beta/deviceManagement/managedDevices/<MANAGED_DEVICE_ID>/syncDevice"
```

## Preventive

1. Mandatory execution-context gate in the change template. [REQUIRES: CAB template update process]
Owner: change manager | Timing: before deployment | Mode: manual (can automate by making template fields mandatory in change tool).
Pass/Fail: Pass = both fields "Context before" and "Context after" completed and unchanged or justified; Fail = blank fields or User->SYSTEM change without exception.
If fail: Change is rejected and returned to DWP engineer for correction before scheduling.

2. Automated pre-deploy context dependency check in release pipeline (smoke test gate). [REQUIRES: release pipeline policy check]
Owner: release engineer | Timing: before deployment | Mode: automated.
Pass/Fail: Pass = no UNC mapping command detected when runAsAccount=SYSTEM, or approved exception ID present; Fail = UNC mapping + SYSTEM with no exception.
If fail: Pipeline blocks promotion to production and opens failed gate record in change ticket.

3. Pilot ring enforcement in Intune assignments.
Owner: DWP engineer | Timing: during deployment | Mode: manual (can automate by policy that blocks broad assignment until pilot label is complete).
Pass/Fail: Pass = exactly 5 pilot devices targeted for 24 hours with 0 Event ID 98 and 100% `Get-PSDrive -Name S` success; Fail = any Event ID 98 or mapping failure.
If fail: Stop rollout, keep scope at pilot only, and escalate to image owner.

4. In-flight monitoring alert during rollout window. [REQUIRES: central endpoint log alerting]
Owner: service desk lead | Timing: during deployment | Mode: automated.
Pass/Fail: Pass = alert count for signature (SYSTEM + "Network name cannot be found" + Map-FinBridgeDrives.ps1) remains 0 per 15-minute window; Fail = >=2 affected devices in 15 minutes.
If fail: Trigger incident bridge and initiate rollback decision immediately.

5. Post-deployment validation checklist before change closure.
Owner: change manager | Timing: after deployment | Mode: manual (can automate by attaching script output artifact checks in ticket workflow).
Pass/Fail: Pass = on 2 affected and 1 unaffected device: Event IDs 7036 and 1500 present, no new Event ID 98, and `Test-Path "\\finbridge-fs01\\Finance"` returns True; Fail = any mismatch.
If fail: Keep change open and return to Resolution or Rollback section.

6. Rollback trigger threshold definition (go/no-go guardrail).
Owner: service desk lead | Timing: during deployment and first 60 minutes after deployment | Mode: manual.
Pass/Fail: Pass = fewer than 3 Finance users report missing S: and zero new Event ID 98 bursts; Fail = 3 or more user reports in 15 minutes or >=2 devices logging Event ID 98 after change.
If fail: Execute Rollback section immediately and freeze further assignment edits until review.

7. Knowledge update and checklist hardening from incident learnings.
Owner: DWP engineer | Timing: after deployment | Mode: manual.
Pass/Fail: Pass = Runbook, L1 KB, and L2/L3 KB updated within 2 business days and linked in Known Error record; Fail = any document missing or not linked.
If fail: Change cannot be marked "closed - lessons captured" and is reopened for documentation completion.

## Related

- Known Error: Day 4/Known-Error-FIN-001-drive-mapping-script-system-context.md
- RCA: Day 4/Excercise2-RCA-Finance-Shared-Drives-20260806.md
- Runbook: Day5/Excercise-Runbook-Finance-Shared-Drives-20260806.md
- L1 self-service article: Day5/KB-L1-Finance-Shared-Drive-Access-Self-Service.md
- Closure note: Day 4/Excercise2-Closure-Finance-Shared-Drives-20260806.md
