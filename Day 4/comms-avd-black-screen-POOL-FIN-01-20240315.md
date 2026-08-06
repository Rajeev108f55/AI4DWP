# AVD Black Screen — Incident Communications
**Incident:** POOL-FIN-01 black screen post-login
**Date:** 2024-03-15
**Resolved:** 10:00
**Related RCA:** RCA-AVD-Black-Screen-POOL-FIN-01-20240315.md

---

## Audience 1 — Non-Technical Executive

**Subject: This morning's AVD desktop issue — resolved**

Your team's access and all data are completely safe. This morning, a routine overnight technical update caused some Finance staff to see a blank screen when opening their virtual desktop. No data was lost or at risk. Our team identified the cause within the hour and fully restored normal access by 10:00 AM. No further action is needed from you or your team.

---

## Audience 2 — Affected End-User Team

**Subject: AVD black screen this morning — fixed**

Hi team,

This morning's blank screen issue on your virtual desktop has been resolved as of 10:00 AM. It was caused by a software update applied overnight to your desktop environment that conflicted with how your screen is displayed.

If you experienced a black screen and haven't tried logging in again yet, please disconnect and reconnect now — everything should work normally. No data was lost.

If you still see any issues, please contact the Service Desk straight away and quote reference **T-POOL-FIN-01**.

Thanks for your patience.

---

## Audience 3 — Engineer-to-Engineer Internal Note

**Subject: P1 resolved — AVD black screen POOL-FIN-01 / dwm.exe crash on igdumd64.dll**

**Root cause:**
Overnight image update to POOL-FIN-01 (02:00, 2024-03-15) introduced Intel GPU driver `igdumd64.dll` v31.0.101.4146 into the session host image. On every user logon, `dwm.exe` loaded the driver and immediately faulted — exception 0xc0000005 (access violation), offset `0x0000000000047f12`. DWM exited (Event 9009, code 0x40010004) producing a black screen. AVD auto-reconnect triggered a crash loop for most users. ~40% of POOL-FIN-01 affected (those brokered to updated hosts); POOL-FIN-02 clean throughout (pre-update image `build-20240313`, never included in update wave).

**Confirming events on SHFIN-01-A:**
- `07:02:16` — App Event 1000: `dwm.exe` faulting on `igdumd64.dll` v31.0.101.4146
- `07:02:18` — DWM Event 9009: exit code 0x40010004
- Repeated at `07:02:46` / `07:03:01` and `07:08:24` (second user akapoor — confirms host-wide, not user-specific)
- `07:02:14` — Kernel Event 1: boot time 02:03:11, confirms host took the update

**Clean baseline on SHFIN-02-A (pre-update):**
- `07:01:46` — DWM Event 9011: started successfully; zero Event 1000 in window

**Actions taken:**
1. All updated POOL-FIN-01 hosts → Drain mode ON (~08:00)
2. Stuck users force-logged off via Azure Portal → Sessions; re-brokered
3. Rollback to `build-20240313` initiated (~08:30) — new hosts deployed from pre-update Compute Gallery image
4. Rebuilt hosts verified: Event 9011 confirmed, zero Event 1000 for `dwm.exe` (~09:30)
5. Drain mode lifted; full user access restored 10:00

**Verification step if this recurs:**
On any suspect host: `Get-WinEvent -LogName Application | Where-Object {$_.Id -eq 1000 -and $_.Message -like "*dwm*"} | Select-Object TimeCreated, Message -First 5` — also check `Get-WinEvent -LogName "Desktop Window Manager" | Where-Object {$_.Id -eq 9009}`. Clean host shows Event 9011 with no 1000/9009.

**Driver detail:**
`igdumd64.dll` is an Intel OEM display driver. AVD session hosts use a virtual GPU adapter — this driver is almost certainly not required and was likely pulled in via Windows Update OEM driver delivery or a driver catalog included in the image build. Check image build manifest diff between `build-20240313` and the overnight update to confirm the exact source.

**Preventive action required (critical — raise as a change):**
- Gate all fleet image rollouts behind a canary host validation step: deploy to 1 host → log in test account → confirm Event 9011 + absence of Event 1000 for `dwm.exe` → only then promote to full pool
- Implement staged rollout (10–20% of hosts first, soak period before completing)
- Exclude or pin OEM GPU drivers in the image build pipeline
- Enforce separate update waves per pool with minimum 24h gap
- Add automated post-deploy DWM health check: alert + auto-drain host if Event 9009 or Event 1000 (`dwm.exe`) fires within first 10 min of operation

Retain one affected host image version for driver source investigation before fully decommissioning.
