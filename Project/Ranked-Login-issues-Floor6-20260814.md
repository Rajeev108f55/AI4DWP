# RCA-Login-Issues — Ranked Likely Fixes: Floor 6 Login Delay, System Slowness & Missing Mapped Drives

Ranked list of likely causes/fixes for the Floor 6 login delay, system slowness, and missing mapped drives following Friday's application deployment — most probable first, based on the pattern from the known Finance drive-mapping issue (Known-Error-FIN-001) and the triage summary.

## 1. Drive-mapping/logon script failure caused by the new app deployment (Most Likely)

- **Why likely:** Missing mapped drives combined with login delay is the exact signature seen before (Known-Error-FIN-001) — a logon script/task that can't reach a network share will hang/retry before timing out, delaying the whole login and leaving drives unmapped. Friday's rollout is the most recent change to that floor.
- **Check to confirm:** On an affected machine, check the Intune Management Extension log (or GPO logon script log) for the drive-mapping script — look for start time, execution context (SYSTEM vs USER), and errors like "Network name cannot be found" or long retry loops.
- **Evidence confirming/ruling out deployment as root cause:** If the script's failure timestamp aligns with Friday's deployment (e.g., script was modified/repackaged with the new app, or a new Intune policy changed execution context), that confirms it. If the script and its logs are unchanged since before Friday, this points away from the deployment.
- **Action if confirmed:** Revert or patch the script for the correct execution context (as done for FIN-001), validate UNC path reachability, and add pilot-device testing before re-deploying floor-wide.

## 2. Group Policy processing conflict/delay introduced by the new app

- **Why likely:** New apps often add GPOs, ADMX templates, or startup scripts that increase logon processing time; combined with drive mapping via GPO, a conflicting or slow-processing policy can cascade into both symptoms.
- **Check to confirm:** Run `gpresult /h` on an affected machine and review Group Policy Event IDs (e.g., 1500 for success, but check processing duration) for unusually long processing times or new policies tied to Friday's rollout.
- **Evidence confirming/ruling out deployment:** If new GPOs/settings appear with a Friday timestamp or reference the new app, this supports the link; if GPO processing time is unchanged, rule it out.
- **Action if confirmed:** Roll back or reorder the new GPO, disable synchronous processing if not required, and re-test logon times.

## 3. Profile bloat/corruption from the new app writing into user profiles (FSLogix/roaming)

- **Why likely:** Slowness across the whole system (not just login) plus missing shortcuts previously reported suggests profile-level issues; a new app writing large caches/config into profiles at first launch can bloat or corrupt profile containers.
- **Check to confirm:** Compare profile size/load time on an affected user vs. a known-good baseline; check FSLogix or profile event logs for errors during Friday's rollout window.
- **Evidence confirming/ruling out deployment:** Profile size/error timestamps coinciding with the new app's first run on Friday supports this; unchanged profile size/behavior rules it out.
- **Action if confirmed:** Clear/rebuild the affected profile container, exclude the new app's data path from full profile sync if applicable, and monitor profile size going forward.

## 4. Resource contention from the new app (AV scanning, background services) slowing logon and general performance

- **Why likely:** "Severe system slowness following deployment" (not just at login) is consistent with a heavy new app or its background processes/AV scanning consuming CPU/disk, especially right after a floor-wide rollout.
- **Check to confirm:** Check Task Manager/Resource Monitor or Perfmon on an affected machine during logon and normal use for high CPU/disk usage tied to the new app's processes or AV scanning of it.
- **Evidence confirming/ruling out deployment:** High resource usage specifically from the new app's process names confirms it; if resource usage is normal, rule it out.
- **Action if confirmed:** Add AV exclusions for the app's directories (if safe), throttle/delay background services, or adjust deployment to stagger startup load.

## 5. Network share/permissions change affecting the mapped drives directly

- **Why likely:** Least likely but possible — a permissions or file server change bundled with the rollout could independently break drive mapping without affecting login speed via script errors.
- **Check to confirm:** Verify the affected user's permissions on the target share and confirm the share/UNC path is reachable and correctly permissioned from an affected machine.
- **Evidence confirming/ruling out deployment:** If share permissions were modified in the same change window as Friday's rollout, this supports it; if permissions are unchanged and correct, rule it out.
- **Action if confirmed:** Restore correct share permissions/ACLs and re-test drive mapping.

## Note
All of the above are hypotheses pending confirmation — to confirm actual root cause, gather the diagnostic evidence in order (starting with #1) rather than acting on assumption.
