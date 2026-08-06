# Known-Error Record — AVD Black Screen Post-Login
**Knowledge Base Reference:** KE-AVD-001
**Date raised:** 2026-08-06
**Source incident:** POOL-FIN-01, 2024-03-15
**RCA document:** RCA-AVD-Black-Screen-POOL-FIN-01-20240315.md
**Status:** Verified

---

**Symptom:**
User logs in to an AVD session and is presented with a black screen. For some users the screen recovers after approximately 30 seconds; for others it persists indefinitely, with the session disconnecting and reconnecting in a loop without ever rendering a desktop.

**Cause:**
An incompatible Intel GPU driver (`igdumd64.dll` v31.0.101.4146) was introduced into the AVD session host image via an overnight image update. On every user logon, Desktop Window Manager (`dwm.exe`) loads the driver and immediately crashes with an access violation (exception 0xc0000005), removing the compositor and leaving the session with no rendered desktop surface.

**Scope:**
All AVD session hosts that received the affected image update are impacted; users brokered to non-updated hosts in the same pool are unaffected. In the source incident, ~40% of POOL-FIN-01 (Finance) users were affected while POOL-FIN-02 (IT), which was not included in the update wave, had zero impact.

**Workaround:**
Place all affected session hosts into Drain mode via Azure Portal to stop new sessions brokering to them, then force-log off any users stuck in a black screen loop so they are re-brokered to a clean host. If all hosts in the pool received the faulty image, temporarily broker affected users to an unaffected pool while the permanent fix is applied.

**Permanent fix:**
Roll back all affected session hosts to the last known-good image version (confirmed clean by DWM Event 9011 with no Event 1000 for `dwm.exe`). Before redeploying any new image to the pool, exclude or pin the OEM Intel GPU driver (`igdumd64.dll`) in the image build pipeline, as AVD session hosts use a virtual GPU adapter and do not require this driver.

**How to spot it:**
On the affected session host, Application log Event ID **1000** will show `dwm.exe` as the faulting application with `igdumd64.dll` as the faulting module, followed immediately by Desktop Window Manager Event ID **9009** (DWM exited). A clean host shows Event ID **9011** (DWM started successfully) with no Event 1000 for `dwm.exe`. The symptom will be scoped exclusively to session hosts that received the image update — any pool or host excluded from the update will be completely clean.
