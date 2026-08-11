# Adding a Windows Application to the Intune App Catalog
**Version:** 1.0 | **Date:** 2026-08-11 | **Status:** Draft  
**Audience:** DWP Engineers — no prior Intune app deployment experience assumed  
**Worked example throughout:** FinBridge Connect v3.1 (.intunewin package)

> ⚠️ **UI label notice:** Microsoft updates the Intune admin center regularly. Label names, menu positions, and field names in this guide reflect the portal as of mid-2026. Where labels are known to vary between tenant versions, this is flagged with ⚠️. Always verify against your live tenant before assuming a label is wrong.

---

## Prerequisites Before You Start

Before opening the portal, confirm you have:

- [ ] The `.intunewin` package file for the application (created using the [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool))
- [ ] The exact install and uninstall command strings from the application vendor or packaging team
- [ ] The detection rule details (registry key, MSI product code, or file path) confirmed against a test installation
- [ ] Intune role with at minimum **Mobile Device Management / App Manager** permissions
- [ ] A pilot AAD group already created containing 10–25 test devices

---

## Part 1 — Where to Add an App in Intune

### 1.1 Navigation Path

1. Open a browser and go to `intune.microsoft.com`
2. Sign in with your Intune admin credentials
3. In the left navigation pane, click **Apps**
4. Click **All apps**
5. Click **+ Add** in the top toolbar

> ⚠️ **Label may vary:** In some tenant versions the left navigation shows **Apps > Windows** directly rather than **Apps > All apps**. If you do not see **All apps**, look for **Windows** under the Apps section and click **+ Add** from there. The outcome is the same.

---

### 1.2 Selecting the Correct App Type

When you click **+ Add**, a pane opens on the right asking you to select an app type. The type you choose determines which fields appear and how Intune handles the package.

| Scenario | App Type to Select |
|---|---|
| Windows LOB app — a `.intunewin` package you have prepared yourself | **Windows app (Win32)** |
| Microsoft Store app (e.g. Company Portal, Teams) | **Microsoft Store app (new)** ⚠️ *label has been "Microsoft Store app" in older tenants — verify* |
| A website the user should open from Company Portal | **Web link** |

**For FinBridge Connect v3.1:** Select **Windows app (Win32)**.

Click **Select** to proceed.

---

## Part 2 — Required Fields When Creating the App

You will work through a series of tabs. Complete every tab before clicking **Create** at the end. Required fields are marked with a red asterisk in the portal.

---

### 2.1 Tab: App Information

This tab identifies the app in the Intune catalog and in the Company Portal.

| Field | What to Enter | FinBridge Example |
|---|---|---|
| **App package file** *(first prompt)* | Upload your `.intunewin` file using the file picker | `FinBridgeConnect_v3.1.intunewin` |
| **Name** \* | The display name shown to users and in reports | `FinBridge Connect` |
| **Description** \* | What the app does — shown in Company Portal | `FinBridge Connect is the DWP finance integration tool. Version 3.1.` |
| **Publisher** \* | The software vendor or internal team | `FinBridge Ltd` |
| **App version** | The version string — used for your records and reports | `3.1` |
| **Category** | Optional — helps users find it in Company Portal | `Business` or `Productivity` |
| **Show this as a featured app in Company Portal** | Toggle — use for high-priority or widely used apps | Off (unless directed otherwise) |
| **Information URL** | Optional link to documentation | Leave blank if none |
| **Privacy URL** | Optional | Leave blank if none |
| **Developer** | Optional | Leave blank or use vendor name |
| **Owner** | Optional — internal owner for admin reference | `DWP Desktop Team` |
| **Notes** | Optional — internal deployment notes | `Finance priority rollout — see deployment plan` |
| **Logo** | Optional — upload a PNG icon | Upload if available |

Click **Next** when complete.

---

### 2.2 Tab: Program

This tab tells Intune exactly how to install and uninstall the application and where to run those commands.

| Field | What to Enter | FinBridge Example |
|---|---|---|
| **Install command** \* | The full command Intune runs to install the app silently | `FinBridgeConnect_Setup.exe /silent` |
| **Uninstall command** \* | The full command Intune runs to remove the app | `FinBridgeConnect_Setup.exe /uninstall /silent` |
| **Install behavior** \* | Whether the installer runs as the logged-in user or as the local system account | `System` (see note below) |
| **Device restart behavior** | What happens after install completes | `Determine behavior based on return codes` (recommended default) |
| **Return codes** | See Section 2.5 | Covered separately below |

> **Install behavior — System vs User:**
> - **System context** runs the installer as the local SYSTEM account — no user needs to be logged in, and the app is installed for all users on the device. Use this for most enterprise LOB apps and for silent deployments via Intune. This is correct for FinBridge Connect v3.1.
> - **User context** runs the installer as the currently logged-in user. Use only if the application explicitly requires a user context installation (e.g. installs to `%APPDATA%` or requires the user's profile). These installs fail on devices with no logged-in user.

> ⚠️ **Label may vary:** In some tenant versions this field is called **Installation behavior** rather than **Install behavior**. Look for the System / User toggle regardless of the label.

Click **Next** when complete.

---

### 2.3 Tab: Requirements

This tab defines the minimum conditions a device must meet before Intune will even attempt the installation. Devices that do not meet these requirements will show as **Not applicable** — this is expected, not a failure.

| Field | What to Enter | FinBridge Example |
|---|---|---|
| **Operating system architecture** \* | 32-bit, 64-bit, or both | `64-bit` (confirm with vendor) |
| **Minimum operating system** \* | The oldest Windows version the app supports | `Windows 11 21H2` or match your fleet baseline |
| **Disk space required (MB)** | Optional — leave blank if unknown | Leave blank |
| **Physical memory required (MB)** | Minimum RAM | `4096` — flag: devices with exactly 4GB RAM are at the minimum; consider raising to `8192` if v3.1 requirements confirm 4GB is insufficient |
| **Minimum number of logical processors** | Optional | Leave blank unless specified by vendor |
| **Minimum CPU speed (MHz)** | Optional | Leave blank unless specified by vendor |

> **Legacy hardware note (FinBridge context):** 5% of the fleet (≈500 devices) have 4GB RAM. If `Physical memory required` is set to `8192`, those devices will automatically receive `Not applicable` status, protecting them from a failed install. Do not set this field blindly — confirm the v3.1 minimum RAM requirement with the FinBridge vendor before populating it.

Click **Next** when complete.

---

### 2.4 Tab: Detection Rules

Detection rules are how Intune determines whether the app is already installed on a device. If the detection rule passes, Intune considers the app installed and will not re-deploy it. If the rule fails (key absent or value wrong), Intune treats the app as not installed.

> ⚠️ **Critical:** A detection rule pointing at the wrong key, wrong value, or wrong version string will cause Intune to report the app as `Not installed` even when it is. Always verify the detection rule against an actual installed instance of the app before deploying to the fleet.

**Detection rule types:**

| Type | When to Use |
|---|---|
| **Registry** | App writes a version or install key to the registry (most common for enterprise LOB apps) |
| **MSI product code** | App is an MSI and you have the GUID from `Get-WmiObject -Class Win32_Product` |
| **File** | App does not write a registry key but creates a specific file at a known path |

**For FinBridge Connect v3.1 — Registry detection rule:**

Click **+ Add** on the Detection rules tab, then fill in:

| Field | Value |
|---|---|
| **Rule type** | Registry |
| **Key path** | `HKEY_LOCAL_MACHINE\SOFTWARE\FinBridge\Connect` |
| **Value name** | `Version` |
| **Detection method** | `String comparison` |
| **Operator** | `Equals` |
| **Value** | `3.1` |
| **Associated with a 32-bit app on 64-bit clients** | No (unless the app is 32-bit) |

**To verify this key exists on an already-installed device:**
```powershell
Get-ItemProperty "HKLM:\SOFTWARE\FinBridge\Connect" | Select-Object Version
# Expected output: Version : 3.1
```
Run this on a device where you have manually installed v3.1 before configuring the detection rule. The value returned must exactly match what you enter in the **Value** field — including capitalisation.

Click **Next** when complete.

---

### 2.5 Return Codes

Intune uses the installer's exit code to determine whether the installation succeeded, failed, or requires a restart. Default return codes are populated automatically — for most standard installers you do not need to change them.

| Exit Code | Default Intune Interpretation | Meaning |
|---|---|---|
| `0` | Success | Installation completed successfully |
| `1707` | Success | Installation completed successfully (MSI) |
| `3010` | Soft reboot required | Install succeeded — a restart is needed to complete |
| `1641` | Hard reboot required | Install succeeded — an immediate restart is required |
| `1618` | Retry | Another installation is in progress — Intune will retry |

**If the FinBridge installer uses non-standard exit codes**, the vendor's release notes will document them. Add custom codes by clicking **+ Add** on the Return codes section.

> ⚠️ **Do not remove the default codes** unless the vendor explicitly states a conflict. Removing `3010` (soft reboot) will cause post-install restarts to be reported as failures.

Click **Next** when complete.

---

### 2.6 Tab: Scope Tags (Optional)

Scope tags control which Intune admin roles can see and manage this app. For most DWP deployments, leave this as the default (`Default`) unless your tenant uses role-based access control (RBAC) to separate app management by team.

Click **Next**.

---

### 2.7 Tab: Assignments

**Do not assign to the full fleet here.** Leave assignments blank at creation time. You will add assignments after the app has been verified in the catalog. See Part 3.

Click **Next**, then **Create**.

Intune will upload the `.intunewin` package. Upload time depends on file size and network speed — do not close the browser tab. A progress bar appears during upload.

---

## Part 3 — Assignment Basics

Assignments control who receives the app and how it is delivered.

### 3.1 The Three Assignment Types

Navigate to the app in the catalog:  
`Apps > All apps > [FinBridge Connect] > Properties > Assignments > Edit`

| Assignment Type | What It Does | When to Use |
|---|---|---|
| **Required** | Intune silently installs the app on every device in the assigned group whether or not the user requests it. The user is not prompted. | Enterprise apps that must be present on all devices — including FinBridge Connect for Finance |
| **Available for enrolled devices** | The app appears in Company Portal and the user can choose to install it themselves. Intune does nothing automatically. | Optional tools the user may want but doesn't need |
| **Uninstall** | Intune silently removes the app from all devices in the assigned group. | Retiring an old version or removing an app from a group |

> **Required vs Available — key operational difference:** With `Available`, a device showing as not having the app installed is expected — the user simply hasn't installed it yet. With `Required`, a device not showing `Installed` after the grace period is a genuine failure that needs investigation.

---

### 3.2 Why Assign to a Pilot Group First

Assigning directly to 10,000 devices on day one creates three risks:

1. **Silent mass failure** — if the detection rule, install command, or package has an error, 10,000 devices fail simultaneously. Identifying the cause from fleet-scale noise is significantly harder than identifying it from 25 failures.
2. **No rollback window** — once the install runs on 10,000 devices, rolling back requires Intune to uninstall and reinstall across the entire fleet, which takes hours and creates user impact.
3. **No comparison baseline** — if issues emerge at scale you have no unaffected group to compare against.

**Start with Ring 0 (25 pilot devices) before Ring 1 (500 Finance devices) before the full fleet.** See the FinBridge v3.1 deployment plan (`FinBridge-v3.1-Intune-Deployment-Plan.md`) for the full ring structure and gate criteria.

**To assign to the pilot group:**  
`Apps > All apps > [FinBridge Connect] > Properties > Assignments > Edit > + Add group (under Required) > [IT Pilot group] > Select > Review + save`

---

## Part 4 — Verification Steps

### 4.1 Confirming the App Appears Correctly in the Catalog

**Path:** `Apps > All apps`

Search for `FinBridge Connect`. Confirm:

| Check | Expected Value |
|---|---|
| App name | `FinBridge Connect` |
| Platform | `Windows` |
| Type | `Win32` |
| Publisher | `FinBridge Ltd` |
| Version | `3.1` |
| Assigned | Yes (after assignment is added) |

Click into the app and navigate to **Properties** to verify detection rules, install/uninstall commands, and requirements are saved exactly as entered.

---

### 4.2 Checking Install Status on an Assigned Test Device

**Path:** `Apps > All apps > [FinBridge Connect] > Monitor > Device install status`

This view lists every device in the assigned group and its current install status. Filter by the pilot group name.

Alternatively, view from the device side:  
`Devices > All devices > [device name] > Apps`  
This shows every app assigned to that specific device and its status.

**To trigger an immediate install check without waiting for the next Intune check-in cycle:**  
`Devices > All devices > [device name] > Sync`  
Or on the device: open **Company Portal > Settings > Sync**. Intune check-in normally occurs every 8 hours; a manual sync forces it immediately.

---

### 4.3 Understanding Install Status Values

| Status | What It Means | Action Required |
|---|---|---|
| **Installed** | Detection rule passed — Intune confirmed the app is present at the expected version | None — success |
| **Not installed** | Detection rule failed — app is not detected at the expected registry path/value | Check whether the install actually ran; verify detection rule key and value against the device |
| **Failed** | Intune attempted the install and the installer returned a non-success exit code | Check `Device install status > [device] > Error details` for the exit code; cross-reference with return codes |
| **Not applicable** | Device does not meet the Requirements tab criteria (wrong OS, wrong architecture, insufficient RAM) | Expected for excluded devices; investigate if seen on devices that should qualify |
| **Pending** | Intune has queued the install but the device has not yet checked in or the install has not started | Wait for next check-in or trigger a manual sync; investigate if Pending for >4 hours |
| **In progress** | Install is actively running on the device | Wait — do not interrupt |

> **Not applicable vs Failed — important distinction:**  
> `Not applicable` means Intune decided not to try (requirements not met). `Failed` means Intune tried and the installer returned an error. These require different responses — do not treat them the same.

---

## Quick Reference — Field Checklist

Use this before clicking Create to confirm all required fields are populated:

- [ ] `.intunewin` file uploaded successfully
- [ ] App name, description, publisher, and version filled in
- [ ] Install command: `FinBridgeConnect_Setup.exe /silent`
- [ ] Uninstall command: `FinBridgeConnect_Setup.exe /uninstall /silent`
- [ ] Install behavior: `System`
- [ ] OS architecture and minimum OS version set
- [ ] Detection rule: Registry — `HKLM\SOFTWARE\FinBridge\Connect` — `Version` — Equals — `3.1`
- [ ] Detection rule verified against a real installed instance before saving
- [ ] Return codes: defaults retained
- [ ] Assignments: left blank at creation — added separately after catalog verification
- [ ] Pilot group assigned first before any broader rollout

---

*Next step: assign to the Ring 0 pilot group and monitor install status before proceeding to Ring 1. See `FinBridge-v3.1-Intune-Deployment-Plan.md` for the full ring schedule.*
