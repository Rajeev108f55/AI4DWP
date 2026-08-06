# Finance Shared Drive Access Issue — Hypothesis Ranking
**Analyst:** DWP Engineer
**Date:** 2026-08-06

## Scope Facts
- **Symptom:** Cannot access shared drives
- **Who:** Finance team
- **Since:** ~08:40 this morning
- **Change:** Yes

## Ranked Hypotheses (Most Probable First)

### 1. Recent GPO or logon script change broke drive mapping for Finance
- **Why this fits the scope facts:** The issue started this morning and there was a change, which makes a newly applied policy or script error the strongest match for a team-specific shared-drive problem.
- **Fastest check:** Compare the current drive-mapping GPO and logon script for Finance against yesterday's version and test `gpresult` on one affected user.

### 2. File server or share behind the mapped drives is unavailable
- **Why this fits the scope facts:** If the target share is down, users would report shared drives as inaccessible regardless of their workstation.
- **Fastest check:** From an affected Finance device, try opening the UNC path directly and confirm whether the file server responds.

### 3. DNS or domain controller resolution failure after the morning change
- **Why this fits the scope facts:** Shared drives depend on locating the domain and file server; a change that affected name resolution could block access for a whole team.
- **Fastest check:** On one affected machine, run `nslookup` for the file server and test whether it can resolve and reach the domain controller.

### 4. Permissions or security filtering changed for Finance
- **Why this fits the scope facts:** A change could have altered group membership, GPO security filtering, or share permissions so only Finance lost access.
- **Fastest check:** Check whether one affected user still has the expected group membership and whether the share permissions include that group.

### 5. Client network path issue on Finance devices
- **Why this fits the scope facts:** If Finance users are on a different subnet, VLAN, or VPN path, a recent change could have isolated them from the file share while others remain unaffected.
- **Fastest check:** Compare network settings and reachable routes from one affected Finance workstation against a known-working machine.

## Status
Root cause not yet confirmed. This ranking is based on the limited scope facts only.

---

## Addendum: Event Details, Surviving Hypothesis, and Resolution

### Event Details That Drove the Elimination
- **08:00:01, ScriptRunner Info:** `Map-FinBridgeDrives.ps1` started.
- **08:00:02, ScriptRunner Info:** the script ran in the **SYSTEM** account context.
- **08:00:03, ScriptRunner Warning/Error:** the network path `\\finbridge-fs01\\Finance` was not accessible from SYSTEM context and the script failed with **Error: Network name cannot be found**.
- **08:00:04, ScriptRunner Info:** no retry was configured.
- **08:00:05, Service Control Manager Event 7036:** Workstation service entered running state on DESKTOP-FB041.
- **08:00:06, GroupPolicy Event 1500:** Group Policy settings processed successfully, confirming this was **not** a Group Policy failure.
- **08:00:07, Ntfs Event 98:** file system reported drive letter S: had not been assigned.
- **2024-03-14 23:30, migration note:** the drive-mapping script was migrated from a **GPO logon script running as USER** to an **Intune PowerShell script running as SYSTEM**, but the script was not updated to work in SYSTEM context.

### Surviving Hypothesis
The surviving hypothesis is that **the drive-mapping script was moved from user context to Intune SYSTEM context without being updated for that execution model**. In SYSTEM context, the UNC path `\\finbridge-fs01\\Finance` was not accessible at execution time, so the Finance drive mapping failed even though Group Policy itself processed successfully.

### Resolution Steps
1. Update `Map-FinBridgeDrives.ps1` so it does not rely on user-only network access when running under SYSTEM, or move the mapping action back to **user context**.
2. Confirm the script can reach `\\finbridge-fs01\\Finance` from the intended execution context before redeployment.
3. If the script must remain in Intune SYSTEM context, defer the mapping until the network and Workstation service are fully available and remove any dependency on mapped credentials at login time.
4. Redeploy the corrected script to the Finance device group.
5. Test on one affected Finance workstation and confirm the S: drive maps successfully.
6. Verify there are no further `Map-FinBridgeDrives.ps1` failures in the Intune Management Extension log.
7. Roll the fix out to the rest of the Finance devices after the pilot device is clean.
