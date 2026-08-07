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

1. Open Intune Admin Center in a browser.
Expected result: Intune portal home page loads.

2. Navigate to Devices -> Scripts and remediations -> Platform scripts.
Expected result: The list of platform scripts is visible.

3. Open the script object named `Map-FinBridgeDrives.ps1`.
Expected result: Script overview page opens.

4. Select Edit on the script object.
Expected result: Script settings page opens in edit mode.

5. Save a copy of the current script content and current settings into the incident ticket as "pre-change backup".
Expected result: A timestamped backup of script content and settings exists in the ticket.

6. Set "Run this script using the logged on credentials" to `Yes`. [ELEVATED]
Expected result: The execution context is configured to user context instead of SYSTEM.

7. Select Review + save.
Expected result: The script settings are saved successfully.

8. Open Assignments for `Map-FinBridgeDrives.ps1`.
Expected result: Assignment scope is shown.

9. Confirm the assignment targets only the Finance scope (Finance devices/users) and remove any non-Finance assignment. [ELEVATED]
Expected result: Only the intended Finance assignment remains.

10. Trigger a device sync for one affected Finance endpoint from Intune. [ELEVATED]
Expected result: Sync action is accepted by Intune.

11. Sign in to the synced endpoint with a Finance user account.
Expected result: User reaches the desktop without script error pop-ups.

12. Run `Get-PSDrive -Name S` in PowerShell on the endpoint.
Expected result: Drive `S:` is returned and mapped.

13. Run `Test-Path "\\finbridge-fs01\\Finance"` in the same user session.
Expected result: Command returns `True`.

14. Open File Explorer and browse `S:\`.
Expected result: Finance share content is visible and accessible.

## 3. Verification

Confirm all checks below before closing the incident.

1. Validate `S:` is present for the test user using `Get-PSDrive -Name S`.
Pass criteria: Output contains drive `S:` mapped to the Finance share.

2. Validate direct UNC access using `Test-Path "\\finbridge-fs01\\Finance"`.
Pass criteria: Command returns `True`.

3. Validate no new mapping failure event after latest logon.
Pass criteria: System log has no new Event ID `98` entries after the test logon timestamp.

4. Validate with one additional Finance user on a second affected device.
Pass criteria: Second user also receives `S:` successfully.

5. Validate incident monitoring channel for 30 minutes.
Pass criteria: No new Finance shared-drive failures are reported.

## 4. Rollback

Execute rollback immediately if users lose broader access, error rates increase, or mapping fails for more users after the change.

1. Open Intune Admin Center and return to the `Map-FinBridgeDrives.ps1` script.
Expected result: Script configuration page is open.

2. Reapply the exact pre-change script settings from the "pre-change backup" captured in Procedure step 5. [ELEVATED]
Expected result: Script settings match the recorded pre-change state.

3. Remove current Finance assignment from the Intune script. [ELEVATED]
Expected result: Intune script no longer targets Finance scope.

4. Re-enable the previously known-good Finance GPO logon script assignment recorded in the change record. [ELEVATED]
Expected result: Finance logon script policy is active again.

5. Trigger policy update on one affected endpoint with `gpupdate /force`.
Expected result: Group Policy refresh completes successfully.

6. Sign in with a Finance test user and check `S:` mapping.
Expected result: `S:` is restored through the GPO path.

7. Post an incident update that rollback is active and freeze further Intune script edits until root cause re-review is complete.
Expected result: Team has clear communication and change freeze is in place.

## 5. Notes

- Edge case: If `Test-Path "\\finbridge-fs01\\Finance"` fails but `S:` exists, treat this as intermittent network/share availability and engage file server team.
- Edge case: If mapping succeeds only after second sign-in, verify network initialization timing and consider delayed logon script execution.
- Warning: Do not run Finance drive mapping in SYSTEM context when the script depends on user session credentials.
- Warning: Keep assignment scope limited to Finance during remediation to avoid cross-business impact.
- Related incident pattern: Account lockout or stale credential incidents can present as drive mapping failures when cached credentials are invalid.
- Related knowledge record: Known Error FIN-001 (drive mapping script in system context).
