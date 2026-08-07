# Runbook — AVD Black Screen Post-Login
## POOL-FIN-01 | Based on RCA-AVD-Black-Screen-POOL-FIN-01-20240315

| Field | Detail |
|---|---|
| **Title** | Runbook — AVD Black Screen Post-Login (POOL-FIN-01) |
| **Version** | 1.0 |
| **Date** | 07/08/26 |
| **Author** | Rajeev |
| **Reviewed** | Self |
| **Status** | Draft |
| **Change** | Initial version from RCA |

---

**Applies to:** Azure Virtual Desktop — Finance host pool (POOL-FIN-01)  
**Trigger:** Users report black screen immediately after AVD login, with or without eventual recovery

---

## 1. Prerequisites

### Access Rights
| Requirement | Detail |
|---|---|
| Azure Portal access | Reader + AVD Contributor role on POOL-FIN-01 host pool — required to view session hosts, drain mode, and force-logoff sessions |
| Azure Portal — Image management | ⚠️ **ELEVATED** — Contributor or higher on the AVD resource group to redeploy session hosts from a known-good image |
| RDS / Remote Desktop access | Local admin (or delegated admin) on session host VMs to read Event Viewer logs remotely |
| Change record | An approved change record or P1 incident authority to place hosts into Drain mode and force-logoff live users during business hours |

### Tools Required
| Tool | Purpose |
|---|---|
| Azure Portal (portal.azure.com) | Manage AVD host pool, session hosts, drain mode, force-logoff |
| Event Viewer (eventvwr.msc) or PowerShell remoting | Read Application and System event logs on session host VMs |
| PowerShell (Az module) | Optional — remote event log query if portal access is slow |

### Information to Gather Before Starting
- Name of the affected host pool (expected: `POOL-FIN-01`)
- Name of at least one affected session host (e.g. `SHFIN-01-A`)
- Name of the last known-good image build (expected: `build-20240313`)
- Current incident/change reference number

---

## 2. Procedure

### Phase 1 — Confirm Scope

**Step 1.** Open a browser and go to [https://portal.azure.com](https://portal.azure.com). Sign in with your DWP admin account.  
*Expected result:* The Azure Portal home page loads. Your name and tenant are visible in the top-right corner.

**Step 2.** In the top search bar, type `Azure Virtual Desktop` and select it from the dropdown.  
*Expected result:* The Azure Virtual Desktop blade opens. You see a left-hand menu with options including Host Pools, Application Groups, and Workspaces.

**Step 3.** In the left menu click **Host pools**. In the list that appears, click **POOL-FIN-01**.  
*Expected result:* The POOL-FIN-01 host pool overview page opens. The host pool name `POOL-FIN-01` is shown in the header.

**Step 4.** In the POOL-FIN-01 left menu, scroll down and click **Session hosts**.  
*Expected result:* A table lists every session host in the pool (e.g. SHFIN-01-A, SHFIN-01-B). Each row shows the host name, status (Available / Unavailable / Drain), and active session count. Write down all host names — you will need them in later steps.

**Step 5.** For each session host in the list, note the **Active sessions** number in that row. Write down:  
  - Total number of hosts  
  - Which hosts have sessions > 0  
  - Which hosts show status other than **Available**  
*Expected result:* You have a written record of which hosts are active and their session counts. If all hosts show 0 sessions and no users are reporting problems, you may be looking at the wrong pool — re-confirm the incident details.

**Step 6.** Go back to **Host pools** (click it in the left menu or breadcrumb). Click **POOL-FIN-02** in the list.  
*Expected result:* The POOL-FIN-02 host pool overview page opens.

**Step 7.** In the POOL-FIN-02 left menu click **Session hosts**. Check whether any hosts show status **Unavailable** or have Event errors. Contact one IT user known to use POOL-FIN-02 and ask: "Can you open your AVD desktop right now and confirm it is working?"  
*Expected result:* POOL-FIN-02 session hosts all show **Available**, and the IT user confirms their desktop loads normally with no black screen.

**Step 8.** Make a decision based on Step 7:  
  - **POOL-FIN-02 is working normally** → the problem is isolated to POOL-FIN-01. Continue to Phase 2.  
  - **POOL-FIN-02 is also affected** → ⛔ STOP. This is not a pool image issue. The fault is in shared infrastructure (Azure AD, Conditional Access, AVD gateway, or network). Do not proceed with this runbook. Raise a separate Major Incident and escalate to the AVD platform/network team immediately.

---

### Phase 2 — Confirm Root Cause on a Session Host

**Step 9.** In the Azure Portal, go to **Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts**. Click the name of the first affected host (e.g. **SHFIN-01-A**) to open its detail blade.  
*Expected result:* The session host detail page opens showing the VM name, resource group, and current status.

**Step 10.** ⚠️ **ELEVATED — requires local admin on the session host VM.** On the session host detail page, click **Connect** in the top button bar, then select **Connect via Bastion** (or **Download RDP file** if Bastion is not configured).  
  - If using Bastion: enter your admin username (format: `FINBRIDGE\<youradminaccount>`) and password, then click **Connect**.  
  - If using RDP file: open the downloaded `.rdp` file, accept the certificate warning, and enter your admin credentials.  
*Expected result:* A desktop session opens on SHFIN-01-A. You see the Windows Server desktop. The taskbar shows the server hostname in the bottom-right.

**Step 11.** On the SHFIN-01-A desktop, press **Win + R**, type `eventvwr.msc`, and press Enter.  
*Expected result:* Event Viewer opens. The left panel shows a tree: **Event Viewer (Local) → Windows Logs → Application / Security / System**.

**Step 12.** In the Event Viewer left panel, click **Windows Logs → Application** to highlight it. In the right-hand **Actions** panel, click **Filter Current Log...**.  
*Expected result:* The Filter Current Log dialog opens. You see fields for Event level, Event ID, and date/time range.

**Step 13.** In the Filter dialog, clear any existing Event ID field. In the **\<All Event IDs\>** box, type `1000`. Leave all other fields as default. Click **OK**.  
*Expected result:* The Application log now shows only Event ID 1000 entries. If there are no results, the grid is empty — this means no application crashes were logged on this host (proceed to Step 15 to check a different host, or re-confirm the incident scope).

**Step 14.** In the filtered results, look for entries where the **Source** column shows `Application Error`. Double-click the most recent one to open the event detail. Read the **General** tab text and confirm it contains **both** of the following:  
  - `Faulting application name: dwm.exe`  
  - `Faulting module name: igdumd64.dll, version: 31.0.101.4146`  
*Expected result:* The event detail text contains both strings above, and the timestamp matches the incident window (morning of the incident date). A screenshot of this event is your evidence — take one now for the incident record. If either string is missing, the crash is caused by a different component — do not proceed; escalate to the AVD platform team.

**Step 15.** Without closing Event Viewer, click **Windows Logs → Application** again in the left panel. Click **Filter Current Log...** in the Actions panel. Change the Event ID to `9009`. Click **OK**.  
*Expected result:* One or more events appear with Source `Desktop Window Manager`. Double-click the most recent. The General text reads: `The Desktop Window Manager has exited with code (0x40010004)`. This confirms the compositor crashed and explains the black screen. If this event is absent, the black screen has a different cause — escalate to the AVD platform team.

**Step 16.** Click **Windows Logs → System** in the left panel. Click **Filter Current Log...**. Set Event ID to `1`. Set Source to `Kernel-General`. Click **OK**.  
*Expected result:* One or more events appear. Double-click the most recent. The General text includes a line like: `The system uptime is...` or the event properties show a **System Time** that corresponds to a boot at approximately 02:00–03:00 on the incident date. This confirms the host was restarted by the overnight image update.  
If the boot time is from several days ago, this host was **not** updated overnight — it is not part of the problem. Go back to Step 9 and repeat on a different host from your list.

> **Decision point after Steps 14–16:**  
> ✅ All three confirmed (dwm.exe crash on igdumd64.dll, Event 9009, boot time matches update window) → Root cause confirmed. Continue to Phase 3.  
> ❌ Any of the three not confirmed → Do not proceed. Document your findings and escalate to the AVD platform team with the Event Viewer screenshots.

---

### Phase 3 — Contain (Drain Mode + Force-Logoff)

> ⚠️ **Steps 17–20 require AVD Contributor role. Confirm you hold an approved change record or P1 incident authority before proceeding. Send the end-user communication using the template in `comms-avd-black-screen-POOL-FIN-01-20240315.md` BEFORE forcing users off in Step 19.**

**Step 17.** In the Azure Portal, go to **Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts**. Click the **checkbox** in the column header row to select all session hosts in the list.  
*Expected result:* All rows are highlighted/checked. The button bar at the top of the list activates.

**Step 18.** With all hosts selected, click **Turn drain mode on** in the button bar at the top of the session hosts list.  
*Expected result:* A confirmation dialog appears. Click **Yes** (or **Confirm**). After a few seconds the page refreshes. Every host in the list now shows **Drain mode: On** in the Allow new connections column. No new user sessions will be brokered to any of these hosts from this point.  
If the button is greyed out, you do not have sufficient permissions — contact your Azure admin before continuing.

**Step 19.** Send the end-user communication now (see `comms-avd-black-screen-POOL-FIN-01-20240315.md` for the template). Give users at least 2 minutes to save their work, then proceed.

**Step 20.** In the session hosts list, click the name of the first host that shows **Active sessions > 0** (e.g. SHFIN-01-A). On the host detail page, click **Sessions** in the left menu.  
*Expected result:* A list of all active sessions on this host is shown, with columns for username, session state, and session ID.

**Step 21.** Click the checkbox in the header row to select all sessions. Click **Log off** in the button bar. When prompted, click **Yes**.  
*Expected result:* The sessions list empties within 30–60 seconds. Users are disconnected and will receive the auto-reconnect prompt on their client — they will be brokered to a different pool (POOL-FIN-02) since POOL-FIN-01 is now in Drain mode.  
Repeat Steps 20–21 for each host that had active sessions.

**Step 22.** Go back to **POOL-FIN-01 → Session hosts**. Wait 2 minutes, then click **Refresh** (the circular arrow icon in the top button bar).  
*Expected result:* The **Active sessions** column shows **0** for every host in the list. If any host still shows sessions after 2 minutes, repeat Steps 20–21 for that specific host, or use the PowerShell fallback in Rollback step RB-4.

---

### Phase 4 — Rollback to Known-Good Image

> ⚠️ **Steps 23–28 require Contributor or higher on the AVD resource group. Confirm the known-good image name is `build-20240313` with your team lead before executing.**

**Step 23.** In the Azure Portal, go to **Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts**. Click the name of the first session host (e.g. SHFIN-01-A). On the detail page, click **Properties** in the left menu.  
*Expected result:* The properties blade opens. Locate the **Image** or **VM image** field. Write down the exact image name/version displayed — this is the faulty image. You will need this for the incident record.

**Step 24.** In the top Azure search bar, type `Virtual machine scale sets` and select it. Locate the scale set associated with POOL-FIN-01 (it will be named with the pool name or resource group, e.g. `vmss-pool-fin-01`). Click its name.  
*Expected result:* The Virtual Machine Scale Set overview page opens.

**Step 25.** In the scale set left menu, click **Operating system image** (under Settings). Click **Change image**.  
*Expected result:* An image selection panel opens showing available images in the attached Azure Compute Gallery or custom image library.

**Step 26.** In the image selection panel, locate and click **build-20240313**. Confirm the selection and click **Save**.  
*Expected result:* A notification appears: *"Updating operating system image..."*. The scale set status shows **Updating**. This triggers reprovisioning of the session host VMs from the known-good image.  
If `build-20240313` is not listed, stop. Do not guess or select a different image. Contact the Image/Platform team to confirm the correct image reference before proceeding.

**Step 27.** Go back to **Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts**. Click **Refresh** every 5 minutes and monitor the **Status** column for each host.  
*Expected result:* Hosts transition through **Unavailable** (rebuilding) and eventually return to **Available** (rebuild complete). Full rebuild typically takes 30–60 minutes. If any host remains **Unavailable** after 90 minutes, go to Rollback step RB-1.

**Step 28.** Once at least one host shows **Available**, connect to it via Bastion or RDP as a local admin (same method as Step 10, using the host that just rebuilt). Open Event Viewer (`eventvwr.msc`). Go to **Windows Logs → Application**. Click **Filter Current Log...**, set Event ID to `9011`, click **OK**.  
*Expected result:* At least one event appears with Source `Desktop Window Manager`. Double-click it. The General text reads: **"The Desktop Window Manager has started successfully."** This confirms DWM is healthy on this rebuilt host.  
Now filter for Event ID `1000` using the same method as Steps 12–13. Confirm the results are **empty** (no dwm.exe crash events since the rebuild). If Event 1000 is still present, go to Rollback step RB-2 — do not proceed to Phase 5.

---

### Phase 5 — Restore Service

**Step 29.** ⚠️ Only proceed if Step 28 confirmed Event 9011 present AND Event 1000 absent. In the Azure Portal, go to **Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts**. Click the checkbox in the header row to select all hosts. Click **Turn drain mode off** in the button bar.  
*Expected result:* A confirmation dialog appears. Click **Yes**. After the page refreshes, the **Allow new connections** column shows **Drain mode: Off** for every host. The AVD broker will now route incoming user logins to POOL-FIN-01 hosts.

**Step 30.** Open a new browser tab and go to [https://client.wvd.microsoft.com/arm/webclient](https://client.wvd.microsoft.com/arm/webclient). Log in using the AVD test service account (credentials in the team password vault under `AVD-Test-Account`). Click the **Finance Desktop** workspace tile.  
*Expected result:* A new browser window opens. Within 30 seconds, a full Windows desktop is displayed — not a black screen, not a loading spinner. The desktop is fully interactive (you can move the mouse, right-click, and open the Start menu).

**Step 31.** While still connected in the test session, switch back to the session host you connected to in Step 28. Open Event Viewer. Go to **Windows Logs → Application**. Click **Refresh** (F5). Filter for Event ID `9011`.  
*Expected result:* A new Event 9011 entry appears timestamped within the last 2 minutes, corresponding to the test session you just launched. No Event 1000 or 9009 entries appear after the rebuild timestamp. This is your final confirmation that the fix is working end-to-end.

**Step 32.** Contact two Finance users from the original incident report and ask them to attempt login. Ask them to confirm: (a) the desktop appeared within 30 seconds, (b) no black screen occurred.  
*Expected result:* Both users confirm successful login. If either reports a black screen, do not close the incident — return to Step 28 and check for Event 1000 on the specific host they landed on.

---

## 3. Verification

Before closing the incident, confirm **all** of the following:

| Check | How | Pass Criteria |
|---|---|---|
| DWM starts cleanly | Event Viewer → Application → filter Event ID `9011` on at least 2 rebuilt hosts | Event 9011 present; Event 1000 for `dwm.exe` absent |
| No crash loop in Application log | Event Viewer → Application → filter Event ID `1000` on all rebuilt hosts, time range = last 60 minutes | Zero matches for `dwm.exe` / `igdumd64.dll` |
| Finance users can log in | Ask at least 2 Finance users to log in to POOL-FIN-01 and confirm desktop loads | Desktop visible within 30 seconds, no black screen |
| Drain mode off on all hosts | Azure Portal → POOL-FIN-01 → Session Hosts | All hosts show Drain mode: Off and Status: Available |
| No open tickets for black screen | Service Desk queue for AVD / POOL-FIN-01 | No new tickets raised in the last 30 minutes related to black screen on login |

Only close the incident once all five checks pass.

---

## 4. Rollback

> **How to use this section:** Find the scenario heading that matches your situation. Follow the numbered steps in order. Do not skip steps. Each scenario is self-contained.
>
> ⚠️ **Before this runbook is put into service, the team lead must fill in the two placeholders marked `[FILL IN]` in Scenario D below.**

---

### Scenario A — Users are still getting a black screen after Drain mode was lifted (Step 29)

*Trigger: You lifted Drain mode and users are reporting black screen again.*

**1.** Go to [https://portal.azure.com](https://portal.azure.com). In the top search bar type `Azure Virtual Desktop`, select it. Click **Host pools** in the left menu → click **POOL-FIN-01** → click **Session hosts** in the left menu.  
**2.** Click the checkbox in the header row to select all hosts. Click **Turn drain mode on** in the button bar. Click **Yes** to confirm.  
*✅ Pass: Every host shows Drain mode: On. Users attempting to connect will be refused — this stops new victims immediately.*  
**3.** On each host that has **Active sessions > 0**: click the host name → click **Sessions** in the left menu → select all sessions → click **Log off** → click **Yes**.  
**4.** Call the AVD platform team on **[FILL IN: AVD on-call number]**. Tell them: "POOL-FIN-01 black screen has recurred after image rollback to build-20240313. All hosts are in Drain mode. Event ID 1000 for dwm.exe may still be present. Requesting platform team to inspect image before we re-enable." Do not lift Drain mode until the platform team confirms the image is clean.

---

### Scenario B — Session hosts are stuck on Unavailable after 90 minutes (Step 27)

*Trigger: It has been 90+ minutes since you changed the image in Step 26 and one or more hosts still show status Unavailable.*

**1.** Go to [https://portal.azure.com](https://portal.azure.com). In the top search bar type `Virtual machine scale sets`, select it. Click the scale set named `vmss-pool-fin-01`.  
**2.** In the left menu click **Instances** (under Settings). Look for any instance showing a status of **Failed** or **Updating** with a red icon. Click that instance name. Click **Redeploy** in the top button bar. Click **Yes** to confirm.  
*✅ Pass: The instance status changes to Updating then Available within 20 minutes. If it fails again, go to step 3.*  
**3.** If the instance fails again after Redeploy, call the Azure platform team on **[FILL IN: Azure platform on-call number]**. Tell them: "VM instance [name] in vmss-pool-fin-01 is failing to reprovision after image change to build-20240313. I need platform team to investigate. POOL-FIN-01 remains in Drain mode — Finance users are without AVD." Do not attempt further image changes.  
**4.** While waiting, go to Scenario C to temporarily move Finance users to POOL-FIN-02 to restore their service.

---

### Scenario C — Bridge Finance users to POOL-FIN-02 while POOL-FIN-01 is being fixed

*Trigger: POOL-FIN-01 is in Drain mode and cannot be recovered quickly. POOL-FIN-02 (IT pool) is confirmed working.*

**1.** Go to [https://portal.azure.com](https://portal.azure.com). Search `Azure Virtual Desktop` → **Host pools** → click **POOL-FIN-02** → click **Properties** in the left menu. Note the **Max session limit** value.  
**2.** Click **Session hosts** in the left menu. Add up the **Active sessions** column across all hosts. Confirm the total is less than the Max session limit noted in step 1.  
*✅ Pass: Total active sessions < max session limit. POOL-FIN-02 has capacity to absorb Finance users. If capacity is at or above the limit, do not redirect Finance users — call the platform team instead (see Scenario B step 3).*  
**3.** Send Finance users the following message by email and Teams: *"AVD Finance Desktop is temporarily unavailable. Please connect to the IT temporary workspace at [https://client.wvd.microsoft.com/arm/webclient](https://client.wvd.microsoft.com/arm/webclient), sign in with your normal DWP account, and select the 'IT Desktop' tile. Your files and profile will load as normal. We will notify you when Finance Desktop is restored."*  
**4.** Do **not** apply any image changes or updates to POOL-FIN-02 for the duration of this incident. Add a note to the incident record: "POOL-FIN-02 in use as Finance fallback — freeze all changes to this pool."

---

### Scenario D — Azure Portal is unresponsive when toggling Drain mode

*Trigger: Clicking Turn drain mode on/off in the portal returns an error, spins indefinitely, or times out.*

> ⚠️ **ELEVATED — requires AVD Contributor role in Azure.**  
> ⚠️ **Team lead must replace both `[FILL IN]` values below before this runbook goes live.**

**1.** Open PowerShell on your local machine. Run:
```powershell
Connect-AzAccount
```
A browser window will open. Sign in with your DWP admin account. Return to PowerShell.  
*✅ Pass: PowerShell prints your account name and the DWP tenant ID. No error message.*

**2.** Run the following command once for **each session host** in POOL-FIN-01 (repeat changing the `-Name` value for each host e.g. SHFIN-01-A, SHFIN-01-B):
```powershell
Update-AzWvdSessionHost `
    -ResourceGroupName "[FILL IN: AVD resource group name e.g. rg-avd-finance-prod]" `
    -HostPoolName "POOL-FIN-01" `
    -Name "SHFIN-01-A" `
    -AllowNewSession:$false
```
*✅ Pass: Command completes with no error. Run the same command again with `-AllowNewSession:$true` to lift Drain mode when ready.*

---

### Scenario E — Sessions are stuck after force-logoff in Steps 21–22

*Trigger: You clicked Log off on a session in the portal but the Active sessions count has not dropped after 2 minutes.*

> ⚠️ **ELEVATED — requires local admin on the session host VM.**

**1.** In the Azure Portal, go to **Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts**. Click the name of the host with the stuck session. Click **Connect** in the top button bar → select **Connect via Bastion**. Enter your admin credentials (format: `FINBRIDGE\<youradminaccount>`). Click **Connect**.  
*✅ Pass: A desktop session opens on the host VM.*  
**2.** On the host desktop, press **Win + R**, type `cmd`, press Enter. In the Command Prompt, run:
```cmd
qwinsta /server:localhost
```
*✅ Pass: A table is printed listing all sessions with a numeric ID in the first column and the username in the second. Identify the stuck session by username.*  
**3.** Run the following, replacing `3` with the session ID number from step 2:
```cmd
reset session 3 /server:localhost
```
*✅ Pass: The command returns immediately with no error. Run `qwinsta /server:localhost` again — the session is gone from the list.*  
Repeat steps 2–3 for any remaining stuck sessions on this host. Then return to Step 22 in the main procedure.

---

## 5. Notes

### Edge Cases
- **Partial black screen recovery (some users recover after ~30 seconds):** This is caused by AVD's auto-reconnect mechanism retrying DWM on a subsequent session attempt. Do not let spontaneous recovery mask the scope of the incident — check all active hosts for Event 1000, not just those with current complaints.
- **Only ~40% of users affected (not all):** Users are affected only if brokered to an updated session host. Users who happened to land on any non-updated host during the incident window were unaffected. The percentage affected will reflect broker distribution, not total pool membership.
- **POOL-FIN-02 also affected:** If POOL-FIN-02 shows the same symptoms, the cause is not the POOL-FIN-01 image update — investigate shared infrastructure (Azure AD, Conditional Access, AVD gateway, FSLogix profile store).
- **OEM GPU driver present in clean image:** Intel OEM display drivers (`igdumd64.dll`) are typically not required on AVD session hosts, which use virtual GPU adapters. If the driver appears in the baseline image (`build-20240313`), flag this to the Image team — see Preventive Action 3 in the source RCA.

### Warnings
- ⚠️ **Never lift Drain mode before verifying Event 9011 and absence of Event 1000 on rebuilt hosts.** Restoring service prematurely will loop users back into the crash cycle.
- ⚠️ **Do not apply any further image updates to POOL-FIN-01 while an incident is in progress.** Any new update could invalidate your rollback baseline.
- ⚠️ **Force-logoff will disconnect users without warning unless notified first.** Always send a communication to affected users before executing Step 12. Use the standard AVD incident comms template.

### Related Incidents and Documents
| Reference | Description |
|---|---|
| RCA-AVD-Black-Screen-POOL-FIN-01-20240315 | Source RCA this runbook is based on |
| Known-Error-AVD-001-black-screen-post-login | Known error record for this issue pattern |
| comms-avd-black-screen-POOL-FIN-01-20240315.md | End-user comms template used during the original incident |
| closure-avd-black-screen-POOL-FIN-01-20240315.md | Closure note from the original incident |

### Key Event IDs for AVD Black Screen Diagnosis
| Event ID | Source | Meaning |
|---|---|---|
| 1000 | Application Error | Application crash — check faulting module; `igdumd64.dll` = this issue |
| 9009 | Desktop Window Manager | DWM exited — compositor down, black screen imminent |
| 9011 | Desktop Window Manager | DWM started successfully — confirms healthy session host |
| 21 | TerminalServices-LocalSessionManager | User session logon |
| 40 | TerminalServices-LocalSessionManager | User session disconnected |
| 1 | Kernel-General | Host boot time — use to confirm overnight update was applied |
