# Adding a Windows App to Intune — Step-by-Step
**Version:** 1.1 | **Date:** 2026-08-11 | **Status:** Draft  
**Worked example:** FinBridge Connect v3.1

> The Intune portal changes regularly. If a label in this guide does not match what you see on screen, look for the nearest equivalent — the steps are the same.

---

## Before You Start — Have These Ready

- The `.intunewin` app package file
- The install command: `FinBridgeConnect_Setup.exe /silent`
- The uninstall command: `FinBridgeConnect_Setup.exe /uninstall /silent`
- Your Intune admin login
- A small test group (10–25 devices) to assign the app to first

---

## Step 1 — Open the Add App Page

1. Go to `intune.microsoft.com` and sign in
2. Click **Apps** in the left menu
3. Click **All apps**
4. Click **+ Add** at the top of the page
5. A panel opens on the right — select **Windows app (Win32)**
6. Click **Select**

> Use **Windows app (Win32)** for any `.intunewin` package. Use **Microsoft Store app** for Store apps. Use **Web link** for a website shortcut.

---

## Step 2 — Upload the Package and Fill in App Details

1. Click **Select file** and upload the `.intunewin` file
2. Fill in the following fields:
   - **Name:** `FinBridge Connect`
   - **Description:** `FinBridge Connect is the DWP finance integration tool. Version 3.1.`
   - **Publisher:** `FinBridge Ltd`
   - **App version:** `3.1`
   - Everything else on this page is optional — leave blank
3. Click **Next**

---

## Step 3 — Set the Install and Uninstall Commands

1. **Install command:** type `FinBridgeConnect_Setup.exe /silent`
2. **Uninstall command:** type `FinBridgeConnect_Setup.exe /uninstall /silent`
3. **Install behavior:** select **System**
   - System means Intune installs the app silently in the background — no user needs to be logged in
   - Do not select User unless the vendor specifically tells you to
4. **Device restart behavior:** leave as `Determine behavior based on return codes`
5. Leave the return codes as they are — do not delete any of the defaults
6. Click **Next**

---

## Step 4 — Set the Requirements

Requirements tell Intune which devices are eligible for the app. Devices that don't meet these will be skipped (shown as **Not applicable** — this is normal).

1. **Operating system architecture:** select `64-bit`
2. **Minimum operating system:** select `Windows 11 21H2` (or your fleet baseline)
3. Leave all other fields blank unless the vendor specifies otherwise
4. Click **Next**

> If you set **Physical memory required** to `8192` (8GB), devices with only 4GB RAM will be automatically skipped. Only do this if the vendor confirms 4GB is not supported.

---

## Step 5 — Set the Detection Rule

The detection rule is how Intune checks whether the app installed correctly. If the rule passes, Intune marks the app as **Installed**. If it fails, the app shows as **Not installed** — even if it's actually there.

1. Click **+ Add**
2. Fill in:
   - **Rule type:** Registry
   - **Key path:** `HKEY_LOCAL_MACHINE\SOFTWARE\FinBridge\Connect`
   - **Value name:** `Version`
   - **Detection method:** String comparison
   - **Operator:** Equals
   - **Value:** `3.1`
3. Leave the 32-bit checkbox unticked
4. Click **OK**, then **Next**

> Before saving, verify the registry key exists on a device where you've already installed v3.1 manually. Open PowerShell on that device and run:
> ```powershell
> Get-ItemProperty "HKLM:\SOFTWARE\FinBridge\Connect" | Select-Object Version
> ```
> The output must show `3.1` — if it shows something different, update the **Value** field to match exactly.

---

## Step 6 — Skip Scope Tags and Assignments for Now

1. On the **Scope tags** page — click **Next** (leave as default)
2. On the **Assignments** page — do not add any groups yet
3. Click **Next**, then **Create**

The portal will upload the package. Do not close the browser tab. Wait for the upload to finish.

---

## Step 7 — Check the App Is in the Catalog

1. Go to **Apps > All apps**
2. Search for `FinBridge Connect`
3. Confirm it appears with Platform = `Windows` and Type = `Win32`
4. Click into it and check **Properties** to confirm the install command, detection rule, and version are all saved correctly

---

## Step 8 — Assign to Your Pilot Group First

Do not assign to the full fleet yet. Always test with a small group first.

1. Go to **Apps > All apps > FinBridge Connect**
2. Click **Properties**, then click **Edit** next to Assignments
3. Under **Required**, click **+ Add group**
4. Search for and select your pilot test group (10–25 devices)
5. Click **Select**, then **Review + save**

> **Required** = Intune installs the app automatically on every device in the group, silently.  
> **Available** = The app appears in Company Portal and users can install it themselves — Intune does nothing automatically.  
> **Uninstall** = Intune removes the app from every device in the group.

---

## Step 9 — Check the Install Status

After assigning, wait 15–30 minutes (or trigger a manual sync), then check the result.

**From the app:**  
Go to **Apps > All apps > FinBridge Connect > Monitor > Device install status**

**From the device:**  
Go to **Devices > All devices > [device name] > Apps**

**What the statuses mean:**

- **Installed** — worked correctly. No action needed.
- **Pending** — Intune hasn't tried yet. Wait or trigger a sync: **Devices > [device] > Sync**
- **Not applicable** — device didn't meet the requirements (OS, architecture, RAM). Expected for excluded devices.
- **Not installed** — detection rule failed. The app may have installed but the registry key doesn't match. Re-check Step 5.
- **Failed** — the installer ran and returned an error. Click the device name to see the error code.

> **Not applicable** and **Failed** are different things. Not applicable means Intune decided not to try. Failed means it tried and something went wrong.

---

## Checklist Before Clicking Create

- [ ] `.intunewin` file uploaded
- [ ] Name: `FinBridge Connect`, Version: `3.1`, Publisher: `FinBridge Ltd`
- [ ] Install command: `FinBridgeConnect_Setup.exe /silent`
- [ ] Uninstall command: `FinBridgeConnect_Setup.exe /uninstall /silent`
- [ ] Install behavior: **System**
- [ ] OS architecture and minimum OS set
- [ ] Detection rule: `HKLM\SOFTWARE\FinBridge\Connect` → `Version` = `3.1`
- [ ] Detection rule tested on a real installed device before saving
- [ ] Return codes: left as defaults
- [ ] Assignments: pilot group only — not the full fleet

---

*Once the pilot group shows Installed with no failures, proceed to the ring rollout. See `FinBridge-v3.1-Intune-Deployment-Plan.md`.*
