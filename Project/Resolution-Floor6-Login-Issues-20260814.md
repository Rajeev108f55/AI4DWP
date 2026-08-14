# Resolution — Floor 6 Login Delay, Slowness & Missing Mapped Drives

## Most-Likely Cause
Based on [Ranked-Login-issues-Floor6-20260814.md](Ranked-Login-issues-Floor6-20260814.md),
the top-ranked cause is: **the logon/drive-mapping script broke because of Friday's
document management app deployment** (execution-context/network-path failure, matching
the pattern of Known-Error-FIN-001). This is still **to confirm** via the diagnostic
evidence (Intune Management Extension logs, GPResult, Event IDs 1500/98) before final
sign-off, but it is the working hypothesis driving the actions below.

## Technical Action

### If confirmed: pull the affected devices out of the deployment ring
Remove Floor 6 devices from the app's assignment group (deployment ring) using
Microsoft Graph PowerShell, so the app assignment/script no longer applies to them
while the fix is validated:

```powershell
Connect-MgGraph -Scopes "GroupMember.ReadWrite.All","Device.Read.All"

# Replace with the actual deployment ring group ID and affected device list
$RingGroupId = "<Floor6-App-Deployment-Ring-Group-Id>"   # to confirm
$AffectedDevices = Get-Content ".\Floor6-Affected-Devices.txt"  # one device name per line

foreach ($deviceName in $AffectedDevices) {
    $device = Get-MgDevice -Filter "displayName eq '$deviceName'"
    if ($device) {
        Remove-MgGroupMemberByRef -GroupId $RingGroupId -DirectoryObjectId $device.Id
        Write-Host "Removed $deviceName from deployment ring $RingGroupId"
    } else {
        Write-Host "Device not found: $deviceName"
    }
}
```

### If a full rollback is required instead: set the app assignment to Uninstall for the ring
```powershell
Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All"

# Replace with the actual app ID and deployment ring group ID
$AppId       = "<DocumentManagementApp-Id>"        # to confirm
$RingGroupId = "<Floor6-App-Deployment-Ring-Group-Id>"  # to confirm

$body = @{
    "@odata.type" = "#microsoft.graph.mobileAppAssignment"
    intent        = "uninstall"
    target        = @{
        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
        groupId       = $RingGroupId
    }
}

New-MgDeviceAppManagementMobileAppAssignment -MobileAppId $AppId -BodyParameter $body
```

Both commands use placeholder IDs — the actual deployment ring group ID and app ID
need to be pulled from Intune before running (**to confirm**).

## Plain-Language Note to Floor 6

> Hi all — thanks for flagging the login and slow-down issues this morning. We've
> identified the most likely cause and are actively working on a fix related to
> Friday's document management app rollout. We don't have a fixed completion time
> yet, but we're prioritising this and will keep you updated as we make progress.
> In the meantime, please continue reporting any further issues (including anything
> unusual you see in Copilot) so we can track the full picture. Thank you for your
> patience.
