# Title: Runbook - Restore Finance Shared Drive Mapping (Context Mismatch)
# Version: 1.0
# Date: 07/08/26
# Author: Rajeev
# Reviewed: Self
# Status: Draft
# Change: Initial version from RCA

# Runbook - Restore Finance Shared Drive Mapping (Context Mismatch)

## 1. Prerequisites

Complete all prerequisite checks before starting the procedure.

| Requirement | Details |
|---|---|
| Access rights | [ELEVATED] Intune Administrator (or equivalent) with permission to edit Platform scripts and assignments. |
| Access rights | [ELEVATED] Local administrator on one affected Finance endpoint for validation commands and log checks. |
| Access rights | [ELEVATED] Read access to Entra group membership for the Finance device/user targeting groups. |
| Systems | Access to Intune Admin Center. |
| Systems | Access to one affected device in the `DESKTOP-FB*` estate (example: DESKTOP-FB041). |
| Systems | Network reachability to `\\finbridge-fs01\\Finance` from user sessions on Finance devices. |
| Tools | PowerShell 5.1+ on validation endpoint. |
| Tools | Event Viewer on validation endpoint. |
| Inputs required | Script name: `Map-FinBridgeDrives.ps1`; expected drive letter: `S:`; target share: `\\finbridge-fs01\\Finance`. |

## 2. Procedure

Follow steps in order without skipping.

1. Open `https://intune.microsoft.com` in a browser and sign in with your admin account.
Expected result: The Microsoft Intune admin center landing page loads with the left navigation menu.

2. Select Devices in the left navigation pane.
Expected result: The Devices workspace opens.

3. Select Scripts and remediations under the Manage devices section.
Expected result: The Scripts and remediations page opens.

4. Select Platform scripts.
Expected result: The platform scripts list is displayed.

5. Select the script named `Map-FinBridgeDrives.ps1`.
Expected result: The script Overview page opens and shows the script name at the top.

6. Select Properties.
Expected result: The properties panel opens and shows script settings.

7. Select Edit next to Script settings.
Expected result: Script settings open in edit mode.

8. Copy the current setting values into the incident ticket under "Pre-change backup".
Expected result: The ticket contains a timestamped backup of script settings.

9. Set Run this script using the logged on credentials to Yes. [ELEVATED]
Expected result: The setting value displays Yes before save.

10. Select Review + save.
Expected result: A portal notification shows the update completed successfully.

11. Select Assignments.
Expected result: The assignments view opens for `Map-FinBridgeDrives.ps1`.

12. Remove one non-Finance assignment group if present. [ELEVATED]
Expected result: The removed group no longer appears in assignment targets.

13. Repeat step 12 until only Finance assignment groups remain. [ELEVATED]
Expected result: Assignment list contains only Finance-targeted groups.

14. Select Devices -> All devices in Intune.
Expected result: Device inventory list is displayed.

15. Select one affected endpoint (example: DESKTOP-FB041).
Expected result: The selected device Overview page opens.

16. Select Sync. [ELEVATED]
Expected result: A portal notification shows Sync device initiated.

17. Wait 5 minutes.
Expected result: Device has time to receive updated policy.

18. Sign in to the synced endpoint using a Finance user account.
Expected result: User reaches desktop with no script or mapping errors.

19. Open Windows PowerShell on the endpoint.
Expected result: A PowerShell prompt opens in the user session.

20. Run `Get-PSDrive -Name S`.
Expected result: Output shows drive `S` with a root path of `\\finbridge-fs01\\Finance`.

21. Run `Test-Path "\\finbridge-fs01\\Finance"`.
Expected result: Output is exactly `True`.

22. Open File Explorer and select This PC.
Expected result: Drive `S:` is visible under Network locations.

23. Open drive `S:`.
Expected result: Finance share folders and files are visible and open without access denied errors.

## 3. Verification

Confirm all checks below before closing the incident.

1. Run `Get-PSDrive -Name S` in the first test user session.
Pass criteria: Output includes `Name : S` and `Root : \\finbridge-fs01\\Finance`.

2. Run `Test-Path "\\finbridge-fs01\\Finance"` in the first test user session.
Pass criteria: Output is exactly `True`.

3. Open Event Viewer on the first test endpoint.
Pass criteria: Event Viewer opens without errors.

4. Navigate to Windows Logs -> System in Event Viewer.
Pass criteria: System event list is visible.

5. Apply a filter for Event IDs `98` and `1500` with Logged time set to Last 1 hour.
Pass criteria: Filtered results display only matching events from the last hour.

6. Confirm there are no new Event ID `98` entries after the successful test logon timestamp.
Pass criteria: Zero Event ID `98` events exist after test logon time.

7. Confirm at least one Event ID `1500` entry exists after the same logon timestamp.
Pass criteria: At least one Event ID `1500` information event is present.

8. Repeat Procedure steps 18 through 23 on a second affected Finance endpoint with a different Finance user.
Pass criteria: The second user also receives drive `S:` mapped to `\\finbridge-fs01\\Finance`.

9. Check the service desk incident queue for Finance shared-drive alerts after 30 minutes.
Pass criteria: No new incidents are logged for missing Finance drive mapping.

## 4. Rollback

Use this rapid rollback if impact increases after the change. Target completion time: under 3 minutes.

1. Open `https://intune.microsoft.com` and sign in with your admin account.
Expected result: Intune home page loads.

2. Go to Devices -> Scripts and remediations -> Platform scripts -> `Map-FinBridgeDrives.ps1`.
Expected result: The script Overview page is open.

3. Select Assignments.
Expected result: Assignment list is visible.

4. Select Edit next to Included groups. [ELEVATED]
Expected result: Group picker opens.

5. Remove all included Finance groups from this Intune script assignment. [ELEVATED]
Expected result: Included groups list is empty.

6. Select Review + save.
Expected result: Portal notification shows assignment update completed successfully.

7. Open Group Policy Management on a domain admin workstation (`gpmc.msc`). [ELEVATED]
Expected result: Group Policy Management console opens.

8. In the left pane, expand Forest, expand Domains, expand the single production domain node, and select OU=Finance.
Expected result: OU=Finance is selected and linked GPOs are shown.

9. Link the known-good Finance drive-map GPO recorded in the change ticket if it is not already linked. [ELEVATED]
Expected result: Known-good GPO appears in Linked Group Policy Objects for OU=Finance.

10. Sign in to one affected endpoint as a Finance user.
Expected result: Desktop loads without script pop-up errors.

11. Run `gpupdate /force` in an elevated Command Prompt on that endpoint. [ELEVATED]
Expected result: Command returns "User Policy update has completed successfully".

12. Run `Get-PSDrive -Name S` in the same user session.
Expected result: Output shows `Name : S` and `Root : \\finbridge-fs01\\Finance`.

13. Post incident update: "Rollback complete - Intune assignment removed, GPO mapping restored".
Expected result: Incident timeline reflects rollback completion and current stable state.

## 5. Notes

- Edge case: If `Test-Path "\\finbridge-fs01\\Finance"` fails but `S:` exists, treat this as intermittent network/share availability and engage file server team.
- Edge case: If mapping succeeds only after second sign-in, verify network initialization timing and consider delayed logon script execution.
- Warning: Do not run Finance drive mapping in SYSTEM context when the script depends on user session credentials.
- Warning: Keep assignment scope limited to Finance during remediation to avoid cross-business impact.
- Related incident pattern: Account lockout or stale credential incidents can present as drive mapping failures when cached credentials are invalid.
- Related knowledge record: Known Error FIN-001 (drive mapping script in system context).
