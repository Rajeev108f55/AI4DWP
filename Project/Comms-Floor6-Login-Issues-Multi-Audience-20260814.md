# End-User Communications — Floor 6 Login Delay & Missing Mapped Drives (20260814)

Same underlying facts across all three versions — only tone, length, and technical
depth differ per audience. No information has been added or removed between versions.

---

## Audience 1 — Non-Technical Executive (under 80 words)

> Your access and data remain fully secure. Some Floor 6 staff experienced slow logins
> and temporarily missing desktop shortcuts this morning, linked to a recent software
> update. Our team has identified the cause and has already taken corrective action.
> No client data was affected. There is nothing you need to do right now — we will
> confirm full resolution shortly and follow up if anything changes.

*(65 words)*

---

## Audience 2 — Affected End-User Team, 10 people (under 100 words)

> Hi team, some of you experienced slow logins or missing desktop shortcuts this
> morning after a recent software update on Floor 6. Your files and data are safe —
> nothing has been lost. If you're still seeing this, please sign out and back in
> once. If it continues, or you notice anything unusual on your screen, don't try to
> fix it yourself — contact the service desk with your name, desk location, and what
> you saw, and they'll help right away.

*(83 words)*

---

## Audience 3 — Engineer-to-Engineer Internal Note

**Incident:** Floor 6 login delay, system slowness, and missing mapped drives — 2026-08-14.

**Root cause:** Drive-mapping logon script failure introduced by Friday's document
management app deployment. Script attempts to reach a network share (UNC path) but
fails, matching the pattern in `Known-Error-FIN-001` (script executing in an
execution context — SYSTEM vs USER — it was not validated for, resulting in
`Network name cannot be found` and the drive letter never being assigned). The failed
script blocks/delays the rest of the logon sequence, accounting for the reported slowness.

**Evidence confirming root cause:**
- Intune Management Extension log (`C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`) shows the drive-mapping script starting in SYSTEM context, followed by `Network name cannot be found`, no successful completion.
- System Event Log: Event ID **1500** (Group Policy processing succeeded — rules out GPO delivery as cause) immediately followed by Event ID **98** (NTFS — drive letter not assigned).
- Comparison check: both events/log errors present on affected devices, absent on unaffected comparison device.
- Failure timestamps align with Friday's app deployment window, not prior baseline.

**Exact action taken:**
1. Ran `Script-AI generated-Evidence-Collection-DriveMapping.ps1` (dry-run first, then live) on an affected device to collect IME logs, `gpresult.html`, and `GroupPolicy-NTFS-Events.csv` as evidence.
2. Confirmed root cause via Detection steps in [KB-L2L3-Floor6-Login-DriveMapping-Failure-20260814.md](KB-L2L3-Floor6-Login-DriveMapping-Failure-20260814.md).
3. Removed affected device(s) from the Floor 6 app deployment ring group: Intune admin center > **Groups > All groups > [Floor 6 deployment ring group] > Members > Remove**, or via Graph PowerShell (`Remove-MgGroupMemberByRef -GroupId $RingGroupId -DirectoryObjectId $device.Id`).
4. Confirmed device no longer targeted: Intune admin center > **Apps > All apps > [Document Management App] > Monitor > Device install status**.

**Config detail:** Deployment ring group ID and app ID — **to confirm/record in ticket** (placeholders used in scripted commands pending exact IDs from Intune).

**Verification step:** Affected device restarted and re-logged in; confirmed logon completes within baseline duration, `S:` (or applicable drive letter) mapped without manual intervention, and Detection steps 1–3 (IME log, Event ID 1500, Event ID 98) show no new errors post-fix. At least 2–3 of the originally affected dozen+ users independently confirmed resolution before ticket closure.

**Preventive action needed:**
1. Mandatory pre-deployment UNC reachability test for any drive-mapping script, run in the exact target execution context (SYSTEM vs USER), against a pilot device before floor-wide Intune assignment.
2. Add a retry-with-logging wrapper to drive-mapping scripts emitting a distinct, searchable Application-log event on failure (reduces future detection time vs. relying solely on IME log).
3. Change Intune ring structure: pilot ring (5–10 devices) with mandatory 1-business-day bake period before floor-wide assignment, replacing current floor-wide-on-first-push pattern.
4. Execution-context validation added to app packaging checklist for any script migrated from GPO logon script (USER) to Intune Win32/PowerShell script (SYSTEM) — per corrective action already defined in `Known-Error-FIN-001`.

**Related:** `Known-Error-FIN-001`; [Ranked-Login-issues-Floor6-20260814.md](Ranked-Login-issues-Floor6-20260814.md); [Resolution-Floor6-Login-Issues-20260814.md](Resolution-Floor6-Login-Issues-20260814.md); [Runbook-Floor6-Login-Issues-20260814.md](Runbook-Floor6-Login-Issues-20260814.md); [KB-L2L3-Floor6-Login-DriveMapping-Failure-20260814.md](KB-L2L3-Floor6-Login-DriveMapping-Failure-20260814.md). Note: the Copilot unauthorized-access report from the same floor is tracked as a **separate security incident** — see [Escalation-Copilot-Unauthorized-Access-Incident-20260814.md](Escalation-Copilot-Unauthorized-Access-Incident-20260814.md) — do not conflate the two when updating either ticket.
