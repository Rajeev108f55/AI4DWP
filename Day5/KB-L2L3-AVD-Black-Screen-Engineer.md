# KB Article — AVD Black Screen Post-Login (L2/L3 Engineer Reference)

| Field | Detail |
|---|---|
| **Version** | 1.0 |
| **Date** | 07/08/2026 |
| **Author** | Rajeev |
| **Reviewed** | Self |
| **Status** | Draft |
| **Change** | Initial version — derived from RCA-AVD-Black-Screen-POOL-FIN-01-20240315 |

---

## 1. Background

Azure Virtual Desktop (AVD) delivers Windows desktops to end users via session host virtual machines grouped into host pools. When a user logs in, the AVD broker selects an available session host and creates a Windows session on it. The **Desktop Window Manager (dwm.exe)** — the Windows compositor process — starts automatically at logon to render the desktop surface. If DWM fails to start or crashes immediately after logon, the user sees a black screen because there is no compositor to render the desktop.

POOL-FIN-01 is the Finance department's AVD host pool. It services approximately 100 Finance users during the morning peak (07:00–10:00). Disruption to this pool directly impacts Finance operations. POOL-FIN-02 is the IT department's host pool and runs independently — it does not share session hosts, images, or update schedules with POOL-FIN-01.

---

## 2. Symptoms

### What users report
- Black screen immediately after AVD login — desktop never appears
- Some users report the screen recovering after approximately 30 seconds; others remain on a black screen indefinitely
- Multiple users calling in at the same time, all from the Finance team
- Problem persists on reconnect — logging off and back in does not consistently resolve it

### What the engineer observes
- AVD auto-reconnect cycling — repeated logon (Event 21) → crash (Event 1000) → disconnect (Event 40) → reconnect (Event 21) loop visible in the event logs
- Only POOL-FIN-01 users affected; POOL-FIN-02 (IT) users unaffected
- Symptom onset correlates with the morning logon wave following an overnight maintenance window
- Approximately 40% of POOL-FIN-01 users affected — not 100% — because the AVD broker distributes sessions across hosts and not all hosts may have received the update

---

## 3. Root Cause

An incompatible Intel GPU display driver (`igdumd64.dll`, version `31.0.101.4146`) was introduced into the POOL-FIN-01 session host image during an overnight update at 02:00. On every user session logon, `dwm.exe` loaded this driver and crashed immediately with an access violation (exception code `0xc0000005`). With the compositor down, no desktop surface could be rendered, producing the black screen.

AVD's auto-reconnect mechanism restarted the session on each crash, but DWM crashed again on every retry, creating a crash loop. Users who recovered did so by chance when DWM briefly stabilised on a retry attempt; users who did not recover remained in the loop until force-logged off.

POOL-FIN-02 was unaffected because it was excluded from the overnight update wave and continued running the pre-update image (`build-20240313`) which did not contain the faulty driver.

**Root cause of the process failure:** The image release pipeline had no canary validation step — the new image was deployed directly to 100% of POOL-FIN-01 production hosts without a single test logon being verified first.

---

## 4. Detection

Use these steps to confirm this is the issue before taking any action. Do not skip to Resolution without completing all checks.

### 4.1 Scope check — confirm the fault is pool-specific

**Check 1 — POOL-FIN-01 vs POOL-FIN-02 comparison**

| What to check | Where | Pass (this issue) | Fail (different issue) |
|---|---|---|---|
| POOL-FIN-01 session hosts status | Azure Portal → Azure Virtual Desktop → Host pools → POOL-FIN-01 → Session hosts | One or more hosts showing active sessions with users reporting black screen | No active sessions or no user complaints |
| POOL-FIN-02 session hosts status | Azure Portal → Azure Virtual Desktop → Host pools → POOL-FIN-02 → Session hosts | All hosts show **Available**; IT users confirm sessions are working | Hosts showing Unavailable or IT users also affected |

If POOL-FIN-02 is also affected, this is a shared-infrastructure fault (Azure AD, Conditional Access, AVD gateway, or network). Do not proceed with this article — raise a Major Incident.

---

### 4.2 Fast Path — PowerShell one-shot diagnostic (target: under 3 minutes)

Run this block from your local machine. Requires PowerShell remoting (WinRM) to the session hosts and local admin credentials. Replace `SHFIN-01-A` and `SHFIN-02-A` with the actual host names from your scope check in 4.1.

```powershell
$affectedHost  = "SHFIN-01-A"   # affected POOL-FIN-01 host
$baselineHost  = "SHFIN-02-A"   # unaffected POOL-FIN-02 host

Write-Host "`n=== CHECK 1: DWM crash on igdumd64.dll — Application log, Event 1000 ===" -ForegroundColor Cyan
Get-WinEvent -ComputerName $affectedHost `
    -FilterHashtable @{ LogName = 'Application'; Id = 1000 } `
    -MaxEvents 20 -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -like '*dwm.exe*' -and $_.Message -like '*igdumd64.dll*' } |
    Select-Object TimeCreated, Message | Format-List

Write-Host "`n=== CHECK 2: DWM compositor down — Application log, Event 9009 ===" -ForegroundColor Cyan
Get-WinEvent -ComputerName $affectedHost `
    -FilterHashtable @{ LogName = 'Application'; Id = 9009 } `
    -MaxEvents 10 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Message | Format-List

Write-Host "`n=== CHECK 3: Host boot time — System log, Event 1 (Kernel-General) ===" -ForegroundColor Cyan
Get-WinEvent -ComputerName $affectedHost `
    -FilterHashtable @{ LogName = 'System'; Id = 1; ProviderName = 'Microsoft-Windows-Kernel-General' } `
    -MaxEvents 1 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Message | Format-List

Write-Host "`n=== BASELINE: Clean DWM start on POOL-FIN-02 — Application log, Event 9011 ===" -ForegroundColor Green
Get-WinEvent -ComputerName $baselineHost `
    -FilterHashtable @{ LogName = 'Application'; Id = 9011 } `
    -MaxEvents 5 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Message | Format-List

Write-Host "`n=== BASELINE: Confirm no DWM crash on POOL-FIN-02 — Application log, Event 1000 ===" -ForegroundColor Green
Get-WinEvent -ComputerName $baselineHost `
    -FilterHashtable @{ LogName = 'Application'; Id = 1000 } `
    -MaxEvents 10 -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -like '*dwm.exe*' } |
    Select-Object TimeCreated, Message | Format-List
```

**Interpret the output:**

| Check | This issue confirmed | Not this issue |
|---|---|---|
| Check 1 — Event 1000 | Output shows entries. Message contains `dwm.exe` and `igdumd64.dll` and `0xc0000005` | No output, or faulting module is not `igdumd64.dll` |
| Check 2 — Event 9009 | Output shows entries. Message contains `0x40010004` | No output — DWM is not exiting; different cause |
| Check 3 — Event 1 | `TimeCreated` shows 02:00–03:00 on the incident date | `TimeCreated` is days old — host was not in the update wave |
| Baseline — Event 9011 on POOL-FIN-02 | Output shows entries with *"started successfully"* | No output — POOL-FIN-02 may also be affected; escalate |
| Baseline — Event 1000 on POOL-FIN-02 | **No output** — confirms fault is isolated to POOL-FIN-01 | Output present — shared infrastructure fault; escalate |

> ✅ **All five checks pass** → Root cause confirmed as `igdumd64.dll` on POOL-FIN-01. Proceed to Section 5 — Resolution.  
> ❌ **Any check fails** → Do not proceed. Document outputs and escalate to the AVD platform team.

---

### 4.3 Manual verification — Event Viewer GUI (use if PowerShell remoting is unavailable)

Connect to an affected POOL-FIN-01 session host (e.g. `SHFIN-01-A`) via Azure Bastion or RDP using a local admin account (`FINBRIDGE\<adminaccount>`). Open Event Viewer: press **Win + R** → type `eventvwr.msc` → press Enter.

---

**Check 2 — Confirm DWM is crashing (Event ID 1000)**

| Field | Value |
|---|---|
| **Log location** | Event Viewer → Windows Logs → **Application** |
| **Filter** | Event ID: `1000` |
| **Source column** | `Application Error` |
| **Field: Faulting application name** | `dwm.exe` |
| **Field: Faulting module name** | `igdumd64.dll` |
| **Field: Faulting module version** | `31.0.101.4146` |
| **Field: Exception code** | `0xc0000005` (access violation) |
| **Timestamp** | Must match the incident window — morning of the incident date |

✅ **Confirmed if:** Event 1000 present with all four fields matching above.  
❌ **Not this issue if:** Event 1000 is absent, or faulting module is not `igdumd64.dll`.

---

**Check 3 — Confirm compositor is down (Event ID 9009)**

| Field | Value |
|---|---|
| **Log location** | Event Viewer → Windows Logs → **Application** |
| **Filter** | Event ID: `9009` |
| **Source column** | `Desktop Window Manager` |
| **Field: Exit code** | `0x40010004` |
| **General text** | `The Desktop Window Manager has exited with code (0x40010004)` |

✅ **Confirmed if:** Event 9009 present with exit code `0x40010004`, timestamped after Event 1000 in Check 2.  
❌ **Not this issue if:** Event 9009 is absent — DWM is not crashing; investigate a different cause.

---

**Check 4 — Confirm the host received the overnight image update (Event ID 1, Kernel-General)**

| Field | Value |
|---|---|
| **Log location** | Event Viewer → Windows Logs → **System** |
| **Filter** | Event ID: `1`, Source: `Kernel-General` |
| **What to look for** | Host boot time shown in the event System Time field |
| **Expected value** | Boot timestamp between 02:00 and 03:00 on the incident date |

✅ **Confirmed if:** Boot time falls within the overnight maintenance window.  
❌ **Different problem if:** Boot time is from several days prior — this host was not updated and is not part of this fault.

---

**Check 5 — Confirm the crash loop pattern (Events 21, 40, 1000 sequence)**

Look at the Application and System logs together around the time of the first user complaint. The following repeating sequence confirms the crash loop specific to this incident:

| Time offset | Event ID | Log | Source | Meaning |
|---|---|---|---|---|
| T+0s | 21 | System | TerminalServices-LocalSessionManager | User logon succeeded |
| T+2s | 1000 | Application | Application Error | dwm.exe crashes on igdumd64.dll |
| T+3s | 40 | System | TerminalServices-LocalSessionManager | Session disconnected (consequence of DWM crash) |
| T+4s | 9009 | Application | Desktop Window Manager | DWM exited — black screen |
| T+30s | 21 | System | TerminalServices-LocalSessionManager | AVD auto-reconnect — session restarted |
| T+32s | 1000 | Application | Application Error | dwm.exe crashes again — same module |

This repeating 21 → 1000 → 40 → 9009 → 21 loop is the definitive signature of this incident.

---

**Check 6 — Confirm the unaffected host has clean DWM (Event ID 9011 on POOL-FIN-02 host)**

On an unaffected POOL-FIN-02 host (e.g. `SHFIN-02-A`), open Event Viewer and check:

| Field | Value |
|---|---|
| **Log location** | Event Viewer → Windows Logs → **Application** |
| **Filter** | Event ID: `9011` |
| **Source column** | `Desktop Window Manager` |
| **General text** | `The Desktop Window Manager has started successfully` |
| **Event 1000 for dwm.exe** | Absent — no crashes in Application log |

✅ **Baseline confirmed if:** Event 9011 present and Event 1000 absent on POOL-FIN-02 host. This cross-pool comparison is the strongest evidence isolating the fault to the image update.

---

## 5. Resolution

> ⚠️ **Permissions required before starting:**
> - AVD Contributor on POOL-FIN-01 host pool (for Drain mode and force-logoff)
> - Contributor on the AVD resource group (for image change)
> - Local admin on session host VMs (for Event Viewer access)
> - Approved change record or active P1 incident authority

> **Set these variables once before running any CLI commands.** Replace `[FILL IN]` values — confirm with your team lead if unsure.
> ```bash
> RG="[FILL IN: AVD resource group — e.g. rg-avd-finance-prod]"
> HOSTPOOL="POOL-FIN-01"
> VMSS="vmss-pool-fin-01"
> # Full Azure Compute Gallery resource ID for build-20240313:
> IMAGE_ID="[FILL IN: /subscriptions/<sub-id>/resourceGroups/<image-rg>/providers/Microsoft.Compute/galleries/<gallery-name>/images/<image-def>/versions/20240313.0.0]"
> ```
> **Note on `allowNewSession` values in CLI output:** `false` = drain ON (no new sessions). `true` = drain OFF (sessions allowed). This is the opposite of what the portal label says.

---

### Step 1 — Place POOL-FIN-01 into Drain mode

**CLI fast path:**
```bash
# Enable drain mode — repeat for each session host: SHFIN-01-A, SHFIN-01-B, etc.
az desktopvirtualization sessionhost update \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --name SHFIN-01-A \
  --allow-new-session false

# Confirm drain mode is on for all hosts
az desktopvirtualization sessionhost list \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --query "[].{Host:name, Status:status, DrainOn:allowNewSession, Sessions:sessions}" \
  --output table
```
✅ *Expected:* `DrainOn` column shows `false` for every host (false = drain ON = no new sessions accepted).

**Portal path:**  
`portal.azure.com` → **[Search bar]** `Azure Virtual Desktop` → left menu: **Host pools** → click **POOL-FIN-01** → left blade menu: **Session hosts** → tick the **header checkbox** to select all hosts → button bar: **Turn drain mode on** → **Yes**

✅ *Expected:* **Allow new connections** column shows **Drain mode: On** for every host.

---

### Step 2 — Send end-user communication

Before forcing users off, send the incident communication using the template in `comms-avd-black-screen-POOL-FIN-01-20240315.md`. Give users 2 minutes to save their work.

✅ *Expected result:* Users are notified before disconnection. This prevents data loss complaints and reduces inbound calls.

---

### Step 3 — Force-logoff all active sessions on POOL-FIN-01

**CLI fast path:**
```bash
# List all active sessions across the entire host pool
az desktopvirtualization usersession list \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --query "[].{User:userPrincipalName, Host:sessionHostName, SessionId:id, State:sessionState}" \
  --output table

# Force-logoff a specific session — replace SHFIN-01-A and 3 with actual host and session ID
az desktopvirtualization usersession delete \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --session-host-name SHFIN-01-A \
  --user-session-id 3

# After clearing all sessions, confirm zero remain
az desktopvirtualization sessionhost list \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --query "[].{Host:name, Sessions:sessions}" \
  --output table
```
✅ *Expected:* `Sessions` column shows `0` for every host.

**Portal path:**  
`portal.azure.com` → **Azure Virtual Desktop** → left menu: **Host pools** → click **POOL-FIN-01** → left blade menu: **Session hosts** → click the name of a host showing **Active sessions > 0** → left blade menu: **Sessions** → tick the **header checkbox** → button bar: **Log off** → **Yes**  
Repeat for each host that shows sessions.

✅ *Expected:* All hosts show **Active sessions: 0**.

---

### Step 4 — Record the faulty image version

**CLI fast path:**
```bash
# Get the current image reference on the VMSS — copy this output into the incident record
az vmss show \
  --resource-group $RG \
  --name $VMSS \
  --query "virtualMachineProfile.storageProfile.imageReference" \
  --output json
```
✅ *Expected:* JSON block showing the image ID/version currently deployed. Save this before making any changes.

**Portal path:**  
`portal.azure.com` → **Azure Virtual Desktop** → left menu: **Host pools** → click **POOL-FIN-01** → left blade menu: **Session hosts** → click any host name → left blade menu: **Properties** → locate the **VM image** field → write down the exact value

---

### Step 5 — Roll back to known-good image (build-20240313)

**CLI fast path:**
```bash
# Update the VMSS image definition to the known-good build
az vmss update \
  --resource-group $RG \
  --name $VMSS \
  --set virtualMachineProfile.storageProfile.imageReference.id="$IMAGE_ID"

# Trigger reimaging of all VMSS instances to apply the new image
az vmss update-instances \
  --resource-group $RG \
  --name $VMSS \
  --instance-ids "*"
```
✅ *Expected:* Both commands return without error. VMSS provisioning state moves to `Updating`.

⛔ If `IMAGE_ID` is unknown or the command returns a resource-not-found error — **stop**. Do not guess an image ID. Contact the Image/Platform team to confirm the correct resource ID.

**Portal path:**  
`portal.azure.com` → **[Search bar]** `Virtual machine scale sets` → click **vmss-pool-fin-01** → left blade menu: **Settings** → **Operating system image** → button: **Change image** → select **build-20240313** from the gallery panel → **Save**

⛔ If `build-20240313` is not listed — **stop**. Contact the Image/Platform team.

---

### Step 6 — Monitor rebuild progress

**CLI fast path:**
```bash
# Poll every 5 minutes — run repeatedly until all instances show Succeeded
az vmss list-instances \
  --resource-group $RG \
  --name $VMSS \
  --query "[].{Instance:name, ProvisioningState:provisioningState, PowerState:instanceView.statuses[1].displayStatus}" \
  --output table
```
✅ *Expected:* `ProvisioningState` transitions from `Updating` → `Succeeded` for every instance. Typical rebuild: 30–60 minutes.  
If any instance shows `Failed` after 90 minutes, go to Rollback — Scenario B.

**Portal path:**  
`portal.azure.com` → **Azure Virtual Desktop** → left menu: **Host pools** → click **POOL-FIN-01** → left blade menu: **Session hosts** → click **Refresh** (circular arrow in button bar) every 5 minutes → monitor **Status** column

---

### Step 7 — Verify rebuilt host before restoring service

**CLI fast path (PowerShell remoting):**
```powershell
$rebuiltHost = "SHFIN-01-A"  # first host to return to Available status

# Check A: Event 9011 must be present — DWM started successfully
Get-WinEvent -ComputerName $rebuiltHost `
    -FilterHashtable @{ LogName = 'Application'; Id = 9011 } `
    -MaxEvents 5 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Message | Format-List

# Check B: Event 1000 must be absent — no DWM crash since rebuild
Get-WinEvent -ComputerName $rebuiltHost `
    -FilterHashtable @{ LogName = 'Application'; Id = 1000 } `
    -MaxEvents 10 -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -like '*dwm.exe*' }
```
✅ *Check A pass:* First command returns at least one Event 9011 entry timestamped after rebuild.  
✅ *Check B pass:* Second command returns **no output** — zero DWM crashes.  
❌ *Check B fails (Event 1000 returned):* Go to Rollback — Scenario A. Do not lift Drain mode.

**Portal path (if PowerShell remoting unavailable):**  
`portal.azure.com` → **Azure Virtual Desktop** → left menu: **Host pools** → click **POOL-FIN-01** → left blade menu: **Session hosts** → click the rebuilt host → button bar: **Connect** → **Connect via Bastion** → credentials: `FINBRIDGE\<adminaccount>` → on host desktop: **Win + R** → `eventvwr.msc` → left panel: **Windows Logs** → **Application** → right panel: **Filter Current Log** → Event ID `9011` (must have results) → repeat filter for `1000` (must have zero results for `dwm.exe`)

---

### Step 8 — Lift Drain mode and restore service

**CLI fast path:**
```bash
# Lift drain mode — repeat for each session host
az desktopvirtualization sessionhost update \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --name SHFIN-01-A \
  --allow-new-session true

# Confirm all hosts are accepting sessions
az desktopvirtualization sessionhost list \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --query "[].{Host:name, Status:status, AcceptingSessions:allowNewSession}" \
  --output table
```
✅ *Expected:* `AcceptingSessions` shows `true` and `Status` shows `Available` for every host.

**Portal path:**  
`portal.azure.com` → **Azure Virtual Desktop** → left menu: **Host pools** → click **POOL-FIN-01** → left blade menu: **Session hosts** → tick **header checkbox** to select all hosts → button bar: **Turn drain mode off** → **Yes**

✅ *Expected:* All hosts show **Drain mode: Off** and **Status: Available**. The AVD broker resumes routing logins to POOL-FIN-01.

---

## 6. Verification

Run the CLI block below first — it covers checks 1, 2, and 4 in under 60 seconds. Then complete checks 3 and 5 manually.

**CLI verification fast path:**
```bash
# Check 4: Confirm all hosts are Available and accepting sessions (drain off)
az desktopvirtualization sessionhost list \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --query "[].{Host:name, Status:status, AcceptingSessions:allowNewSession, Sessions:sessions}" \
  --output table
```
✅ *Pass:* Every row shows `Status = Available` and `AcceptingSessions = true`.

```powershell
# Checks 1 & 2: Confirm DWM healthy on at least 2 rebuilt hosts — repeat for each host
$rebuiltHost = "SHFIN-01-A"

# Check 1: Event 9011 present — DWM started successfully after rebuild
Get-WinEvent -ComputerName $rebuiltHost `
    -FilterHashtable @{ LogName = 'Application'; Id = 9011 } `
    -MaxEvents 3 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Message | Format-List

# Check 2: Event 1000 absent — no DWM crash in last 60 minutes
Get-WinEvent -ComputerName $rebuiltHost `
    -FilterHashtable @{ LogName = 'Application'; Id = 1000 } `
    -MaxEvents 20 -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -like '*dwm.exe*' -and $_.TimeCreated -gt (Get-Date).AddHours(-1) }
```
✅ *Check 1 pass:* Event 9011 entries returned, timestamped after rebuild completion.  
✅ *Check 2 pass:* **No output** — zero DWM crash events in the last hour.

Complete all five checks before closing the incident:

| # | Check | Exact path | Pass Criteria |
|---|---|---|---|
| 1 | DWM starts cleanly on rebuilt hosts | PowerShell remoting → `Get-WinEvent` → Log: `Application` → Event ID: `9011` on at least 2 rebuilt POOL-FIN-01 hosts | Event 9011 present, timestamped after rebuild |
| 2 | No DWM crash on rebuilt hosts | PowerShell remoting → `Get-WinEvent` → Log: `Application` → Event ID: `1000` filtered to `dwm.exe`, time range: last 60 minutes | Zero results returned |
| 3 | Test session loads successfully | Browser → `https://client.wvd.microsoft.com/arm/webclient` → sign in as `AVD-Test-Account` (credentials: team password vault → `AVD-Test-Account`) → click **Finance Desktop** tile | Full desktop visible within 30 seconds, no black screen, mouse and Start menu responsive |
| 4 | Drain mode off, all hosts available | `az desktopvirtualization sessionhost list --resource-group $RG --host-pool-name POOL-FIN-01 --query "[].{Status:status,AcceptingSessions:allowNewSession}" --output table` | Every row: `Status = Available`, `AcceptingSessions = true` |
| 5 | No new user complaints | `portal.azure.com` → **[Search bar]** `[FILL IN: your Service Desk tool]` → filter queue by: **Category = AVD**, **Team = Finance**, **Keyword = black screen** | Zero new tickets opened in the last 30 minutes |

---

## 7. Rollback

> Find the scenario matching your situation. Each is self-contained. All CLI commands assume the variables `$RG`, `$HOSTPOOL`, `$VMSS` set in Section 5.

---

### Scenario A — Event 1000 for dwm.exe still present after rollback to build-20240313

*Trigger: Step 7 verification shows Event 1000 for `dwm.exe` still returned after image rollback. The faulty driver may exist in the baseline image itself.*

**CLI — confirm drain is still enforced:**
```bash
az desktopvirtualization sessionhost list \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --query "[].{Host:name, AcceptingSessions:allowNewSession}" \
  --output table
```
✅ *Expected:* `AcceptingSessions = false` for all hosts (false = drain ON). If any show `true`, re-run the drain commands from Resolution Step 1.

1. ⛔ **Do not lift Drain mode under any circumstances.**
2. Call the Image/Platform team. Read them this message verbatim: *"After rolling back POOL-FIN-01 to build-20240313, PowerShell Get-WinEvent on the Application log still returns Event 1000 for dwm.exe with faulting module igdumd64.dll. Requesting inspection of igdumd64.dll version in build-20240313 before any host in POOL-FIN-01 is returned to production."*
3. Redirect Finance users to POOL-FIN-02 — see Scenario C.

---

### Scenario B — Session hosts stuck on Unavailable after 90 minutes

*Trigger: `az vmss list-instances` or the portal Session hosts view shows one or more instances with `ProvisioningState = Failed` or stuck on `Updating` after 90 minutes.*

**CLI fast path:**
```bash
# Identify failed instances
az vmss list-instances \
  --resource-group $RG \
  --name $VMSS \
  --query "[?provisioningState=='Failed' || provisioningState=='Updating'].{Instance:name, State:provisioningState}" \
  --output table

# Reimage a specific stuck instance — replace 2 with the numeric instance ID from the output above
az vmss reimage \
  --resource-group $RG \
  --name $VMSS \
  --instance-ids 2
```
✅ *Expected:* Instance moves through `Updating` → `Succeeded` within 20 minutes. Confirm with `az vmss list-instances` again.

**Portal path (if CLI unavailable):**  
`portal.azure.com` → **[Search bar]** `Virtual machine scale sets` → click **vmss-pool-fin-01** → left blade menu: **Settings** → **Instances** → identify instance with red/Failed icon → click instance name → button bar: **Redeploy** → **Yes**

If the instance fails again after reimage/redeploy:  
Call the Azure platform team. Tell them: *"VM instance [instance name from output] in vmss-pool-fin-01 is failing to reprovision from image build-20240313 — ProvisioningState remains Failed after two reimage attempts. POOL-FIN-01 is in full Drain mode."* Do not attempt further image changes. Redirect Finance users — see Scenario C.

---

### Scenario C — Bridge Finance users to POOL-FIN-02

*Trigger: POOL-FIN-01 cannot be recovered quickly. Finance users need access now.*

**CLI — check POOL-FIN-02 capacity before redirecting:**
```bash
# Get the max session limit for POOL-FIN-02
az desktopvirtualization hostpool show \
  --resource-group $RG \
  --name POOL-FIN-02 \
  --query "{MaxSessionLimit:maxSessionLimit}" \
  --output table

# Get current active sessions across all POOL-FIN-02 hosts
az desktopvirtualization sessionhost list \
  --resource-group $RG \
  --host-pool-name POOL-FIN-02 \
  --query "[].{Host:name, Status:status, Sessions:sessions}" \
  --output table
```
✅ *Proceed only if:* Sum of `Sessions` column < `MaxSessionLimit`. If at or above capacity — do not redirect. Contact the platform team.

**Portal path (if CLI unavailable):**  
`portal.azure.com` → **Azure Virtual Desktop** → left menu: **Host pools** → click **POOL-FIN-02** → left blade menu: **Properties** → note **Max session limit** → left blade menu: **Session hosts** → sum the **Active sessions** column → confirm total < Max session limit

If capacity is confirmed, send Finance users this message:  
*"AVD Finance Desktop is temporarily unavailable. Please connect to the IT temporary workspace at https://client.wvd.microsoft.com/arm/webclient, sign in with your normal DWP account, and select the IT Desktop tile. Your files and profile will load as normal."*

Add to incident record: **"POOL-FIN-02 in use as Finance fallback from [time]. Freeze all image changes to POOL-FIN-02 until POOL-FIN-01 is fully restored."**

---

### Scenario D — Portal fails during Drain mode toggle

*Trigger: Azure Portal returns an error or times out when clicking Turn drain mode on/off.*

**CLI fast path:**
```bash
# Enable drain mode — repeat for each session host
az desktopvirtualization sessionhost update \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --name SHFIN-01-A \
  --allow-new-session false

# Confirm drain is on
az desktopvirtualization sessionhost list \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --query "[].{Host:name, AcceptingSessions:allowNewSession}" \
  --output table
```
✅ *Expected:* `AcceptingSessions = false` for all hosts. To lift drain mode later, re-run with `--allow-new-session true`.

---

### Scenario E — Sessions stuck after force-logoff

*Trigger: Sessions still appear in portal or `az desktopvirtualization usersession list` still returns entries 2 minutes after clicking Log off.*

**CLI fast path:**
```bash
# List remaining sessions and get their IDs
az desktopvirtualization usersession list \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --query "[].{User:userPrincipalName, Host:sessionHostName, SessionId:id, State:sessionState}" \
  --output table

# Force-delete a stuck session — replace SHFIN-01-A and 3 with actual values from the list above
az desktopvirtualization usersession delete \
  --resource-group $RG \
  --host-pool-name $HOSTPOOL \
  --session-host-name SHFIN-01-A \
  --user-session-id 3
```
✅ *Expected:* Delete command returns immediately with no output (success). Re-run the list command — session is gone. Repeat for each remaining stuck session.

**If CLI also fails** (session stuck at OS level — use as last resort):  
`portal.azure.com` → **Azure Virtual Desktop** → left menu: **Host pools** → click **POOL-FIN-01** → left blade menu: **Session hosts** → click the stuck host → button bar: **Connect** → **Connect via Bastion** → credentials: `FINBRIDGE\<adminaccount>`  
On host desktop: **Win + R** → type `cmd` → **Enter**
```cmd
qwinsta /server:localhost
```
Note the numeric session ID from the first column. Then:
```cmd
reset session 3 /server:localhost
```
✅ *Expected:* Command returns immediately. Re-run `qwinsta` — session is gone from the list. Repeat for each remaining stuck session.

---

## 8. Preventive Actions

> Controls are ordered by phase: Pre-deployment → During deployment → Post-deployment. Each control names who owns it, when it fires, what pass/fail looks like, and what happens on failure. Controls marked `[REQUIRES]` depend on a tool or process that must be built or confirmed before the control is active.

---

**C1 — Canary validation gate in image release pipeline**  
**Who:** Release engineer | **When:** Pre-deployment — before any fleet rollout begins | **Type:** Automated  
**Pass ✅:** Within 5 minutes of automated test logon on the canary host, Event ID `9011` (`Desktop Window Manager`) is present in the Application log AND zero Event ID `1000` for `dwm.exe` are recorded during a 10-minute soak window.  
**Fail ❌:** Pipeline automatically blocks fleet rollout and fires an alert to the image owner distribution list. Release engineer raises a build defect against the failing image version. No manual override to bypass this gate is permitted.  
**Detail:** Deploy the new image to a single canary session host. Run an automated logon using the `AVD-Test-Account` service account. Query the Application log for Events `9011` and `1000`. Gate must be enforced in the pipeline definition — not a manual checklist step.  
`[REQUIRES: CI/CD pipeline step configured in the AVD image release pipeline with automated logon capability]`

---

**C2 — Exclude OEM GPU drivers from AVD image build**  
**Who:** Image owner | **When:** Pre-deployment — at image build time, before the image is published to the gallery | **Type:** Manual → should be automated  
**Pass ✅:** After the image is built, `driverquery /v` run against the image returns no entry for `igdumd64.dll`. Build manifest shows no Intel display driver package (`iigd_dch.inf` or equivalent) under display adapters.  
**Fail ❌:** Build pipeline blocks image promotion to the gallery. Image owner removes the driver from the exclusion gap, rebuilds the image, and re-runs the `driverquery` check before resubmitting.  
**Detail:** Add `igdumd64.dll` and `iigd_dch.inf` to the driver exclusion list in the image build pipeline config. AVD session hosts use virtual GPU adapters — OEM display drivers are not required and must not be installed via Windows Update or driver catalog pull during build.  
**Automation note:** Add `driverquery /v | findstr igdumd64` as a build pipeline assertion step — fail the build if output is non-empty.  
`[REQUIRES: Driver exclusion list maintained in image build pipeline configuration file]`

---

**C3 — Staged rollout — 10% canary wave before full fleet**  
**Who:** Release engineer (monitors); image owner (authorises fleet promotion) | **When:** During deployment — throughout the rollout and 2-hour soak window | **Type:** Automated monitoring, manual promotion decision  
**Pass ✅:** Zero Event ID `1000` (`dwm.exe`) and zero Event ID `9009` recorded on any canary host during the entire 2-hour soak window. Release engineer confirms pass in the change record before authorising fleet promotion.  
**Fail ❌:** Any single Event `1000` or `9009` on a canary host → release engineer immediately places all canary hosts into Drain mode using `az desktopvirtualization sessionhost update --allow-new-session false`, halts the rollout, and escalates to the image owner. Fleet rollout does not proceed until a root cause is identified and a new image build passes C1.  
**Detail:** Configure the deployment pipeline to deploy new images to a maximum of 10–20% of POOL-FIN-01 session hosts in the first wave.  
`[REQUIRES: Deployment pipeline with configurable rollout percentage and per-wave health check step]`

---

**C4 — Mandatory 24-hour gap between POOL-FIN-01 and POOL-FIN-02 update waves**  
**Who:** Change manager | **When:** Pre-deployment — at change scheduling and CAB approval | **Type:** Manual (CAB gate)  
**Pass ✅:** The change record for any POOL-FIN-01 image update shows a scheduled start time at least 24 hours after the most recent POOL-FIN-02 update in the same maintenance cycle. Change manager confirms this in the CAB checklist before approving.  
**Fail ❌:** Change manager rejects the change request and reschedules it. No exception is granted without explicit written sign-off from the service owner. A rejected change must be rescheduled — it cannot be overridden by the requesting engineer.  
**Detail:** Update the CAB change request template for AVD image updates to include a mandatory field: *"Date/time of most recent POOL-FIN-02 update"* with a validation that the gap is ≥ 24 hours. This ensures an unaffected reference pool is always available if a rollback comparison is needed.  
**Automation note:** Add a scheduling validation script to the ITSM tool that checks the 24-hour gap at submission time and blocks the change record from reaching CAB if the condition is not met.  
`[REQUIRES: CAB change request template updated with mandatory gap field and validation rule]`

---

**C5 — Automated DWM health alerting post-deployment**  
**Who:** Platform/Automation team (configures alert rule); DWP engineer (responds to alert) | **When:** Post-deployment — fires within the first 10 minutes of each session host starting after any image update | **Type:** Automated (alert and auto-drain)  
**Pass ✅:** No Event ID `9009` or Event ID `1000` (source: `Application Error`, application: `dwm.exe`) detected on any session host in the 10-minute monitoring window after the host becomes Available.  
**Fail ❌:** Alert fires within 15 minutes to the AVD operations team distribution list. The alert rule automatically places the affected host into Drain mode. DWP engineer must acknowledge the alert within 15 minutes and begin triage using Section 4 of this article. If no acknowledgement within 15 minutes, alert escalates to the on-call AVD platform engineer.  
**Detail:** Configure an Azure Monitor alert rule targeting the Application event log on all POOL-FIN-01 session hosts. Trigger condition: Event ID `9009` OR Event ID `1000` where source = `Application Error` and message contains `dwm.exe`. Action group: email + auto-drain via Logic App or Automation Runbook.  
`[REQUIRES: Azure Monitor alert rule + Action Group configured; Logic App or Azure Automation Runbook for auto-drain not yet confirmed as existing]`

---

**C6 — Build manifest diff on every image release**  
**Who:** Image owner (produces manifest and reviews diff); release engineer (makes pass/fail decision) | **When:** Pre-deployment — before the change record is raised for CAB | **Type:** Manual review, automation recommended  
**Pass ✅:** Diff of the new image build manifest against the previous build manifest shows zero new or changed entries under the categories: display drivers, GPU drivers, DirectX components. Release engineer records "manifest diff clean" in the change record.  
**Fail ❌:** Release engineer blocks the change record from reaching CAB until the image owner has reviewed every new/changed driver entry, documented the reason for the change, and confirmed it is intentional. If any entry cannot be explained, the image is rebuilt without that component and the diff is re-run.  
**Detail:** Each image build must produce a manifest file listing all installed driver versions. Store manifests alongside the image version tag in the image repository. Minimum manifest scope: display drivers, GPU drivers, DirectX, Visual C++ runtimes.  
**Automation note:** Add a `driverquery /fo csv > manifest-<version>.csv` step to the build pipeline and diff against the previous version's CSV automatically — flag any new row in the display adapter category.  
`[REQUIRES: Build manifest generation step added to image build pipeline; manifest storage location defined in image repository]`

---

**C7 — Post-deployment validation gate before closing the change record** *(Gap: post-deployment confirmation)*  
**Who:** DWP engineer (runs checks); change manager (closes change record) | **When:** Post-deployment — after all session hosts show Available, before the change record is closed | **Type:** Manual  
**Pass ✅:** All five verification checks in Section 6 of this article pass — Event 9011 present on ≥ 2 rebuilt hosts, zero Event 1000 for `dwm.exe` in last 60 minutes, test logon succeeds at `https://client.wvd.microsoft.com/arm/webclient`, all hosts showing `Status = Available` and `AcceptingSessions = true`, zero new incident tickets for 30 minutes.  
**Fail ❌:** Change record remains open. DWP engineer re-escalates to image owner with the specific failing check identified. Change manager does not close the record until the DWP engineer has submitted a sign-off comment confirming all five checks passed.  
**Detail:** Add a mandatory sign-off comment template to the change record closure step. The comment must list each of the five checks with a pass/fail result and timestamp.

---

**C8 — Explicit rollback trigger threshold** *(Gap: automatic or manual rollback threshold)*  
**Who:** DWP engineer (monitors and triggers); release engineer (executes rollback) | **When:** During deployment — throughout the rollout and for 60 minutes post-completion | **Type:** Manual trigger, automated drain  
**Pass ✅:** Zero Event ID `1000` for `dwm.exe` across all deployed session hosts during the entire rollout window and for 60 minutes after the last host reaches Available status.  
**Fail ❌:** Any single Event `1000` for `dwm.exe` on any session host → DWP engineer immediately drains the affected host (`az desktopvirtualization sessionhost update --allow-new-session false`) and notifies the release engineer. If Event `1000` appears on two or more hosts within the rollout window → release engineer triggers full rollback to the previous image within 30 minutes, without waiting for further evidence.  
**Detail:** The two-host threshold for full rollback prevents delay caused by uncertainty. One event could be transient; two events on separate hosts confirms a fleet-wide regression. This threshold must be documented in the release engineer's rollout checklist.  
`[REQUIRES: Release engineer rollout checklist updated with this threshold before the next POOL-FIN-01 image release]`

---

**C9 — Knowledge update within 5 business days of incident closure** *(Gap: runbook and checklist update from incident learnings)*  
**Who:** DWP engineer (authors updates); service desk lead (approves and tracks) | **When:** Post-incident — within 5 business days of incident closure | **Type:** Manual  
**Pass ✅:** The following four artefacts are updated and version-bumped within 5 business days: `Runbook-AVD-Black-Screen-POOL-FIN-01.md`, `KB-L2L3-AVD-Black-Screen-Engineer.md`, `Known-Error-AVD-001-black-screen-post-login.md`, and the CAB change request template for AVD image updates.  
**Fail ❌:** Service desk lead logs the update as an open action against the incident record. Change manager is notified that the CAB template has not been updated. No further AVD image change records for POOL-FIN-01 are approved until the service desk lead confirms the knowledge update is complete.  
**Detail:** Each update must include: any new event IDs encountered, any new rollback steps discovered during the incident, and any gaps found in the existing runbook during live response.

---

## 9. Related Incidents and Knowledge Base Articles

| Reference | Type | Description |
|---|---|---|
| RCA-AVD-Black-Screen-POOL-FIN-01-20240315 | RCA | Source root cause analysis for the 2024-03-15 incident this article is based on |
| Runbook-AVD-Black-Screen-POOL-FIN-01.md | Runbook | Step-by-step operational runbook for responding to this incident — use this during live incidents |
| KB-L1-AVD-Black-Screen-Self-Service.md | L1 KB | End-user self-service article — send to users before raising an IT ticket |
| Known-Error-AVD-001-black-screen-post-login.md | Known Error | Known error record — log future recurrences against this record |
| comms-avd-black-screen-POOL-FIN-01-20240315.md | Comms template | End-user communication template for this incident type |
| closure-avd-black-screen-POOL-FIN-01-20240315.md | Closure note | Closure note from the 2024-03-15 incident for historical reference |

---

## Appendix — Quick Reference: Key Event IDs

| Event ID | Log | Source | Meaning | This incident? |
|---|---|---|---|---|
| 1000 | Application | Application Error | Application crash — check faulting module | ✅ Yes — `dwm.exe` / `igdumd64.dll` |
| 9009 | Application | Desktop Window Manager | DWM exited — compositor down, black screen | ✅ Yes — exit code `0x40010004` |
| 9011 | Application | Desktop Window Manager | DWM started successfully — healthy host | ✅ Yes — present on clean hosts, absent on faulty ones |
| 21 | System | TerminalServices-LocalSessionManager | User session logon | ✅ Yes — part of crash loop pattern |
| 40 | System | TerminalServices-LocalSessionManager | Session disconnected | ✅ Yes — follows every DWM crash |
| 1 | System | Kernel-General | Host boot time | ✅ Yes — confirms host received overnight update |
