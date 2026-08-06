# Root Cause Analysis (RCA) — Recurring Outlook Crash (Access Violation)

**Document prepared by:** DWP Analyst
**Date prepared:** 2026-08-05
**Incident date (per logs):** 2024-03-15
**Affected application:** OUTLOOK.EXE (version 16.0.17126.20132)
**Affected module:** KERNELBASE.dll (version 10.0.22621.3155)

---

## 1. Event ID Reference

| Event ID | Source | Records | Notes for this incident |
|---|---|---|---|
| **1000** | Application Error | A user-mode application crash: faulting application, faulting module, exception code, fault offset, process ID, and a Windows Error Reporting Report ID. | Occurred twice (09:14:22 and 09:17:45), both with the **same exception code (`0xc0000005`) and identical fault offset (`0x000000000003a4b2`)** — a strong indicator of a deterministic, repeatable trigger. |
| **0xc0000005** (exception code, not a separate event) | Within the 1000 event | Standard NTSTATUS code for `STATUS_ACCESS_VIOLATION` — the process attempted to read or write memory it did not have valid access to. | High confidence in this decode; verify exact wording against Microsoft's NTSTATUS reference if quoting formally in an external report. |
| **1001** | Windows Error Reporting | Confirms WER captured and classified the crash into a fault bucket (`APPCRASH`), for Microsoft-side telemetry. | This is a summary of the same 09:17:45 crash — it does not add new diagnostic detail beyond confirming crash classification. |
| **1026** | .NET Runtime | An unhandled exception terminated a .NET/CLR-hosted process. | Reports `System.AccessViolationException` in `OUTLOOK.EXE` — the **managed-code view of the same underlying access violation**, suggesting managed code (e.g., a VSTO/.NET add-in) was present on the call stack when the fault occurred. |

**Conclusion:** Events 1000 (×2), 1001, and 1026 all describe the **same underlying crash**, observed from three different logging sources, not four separate issues.

---

## 2. Reconstructed Sequence of Events (Plain English)

1. **09:13:44** — OUTLOOK.EXE started.
2. **09:14:22** — Approximately 38 seconds after launch, Outlook crashed with an access violation (`0xc0000005`) inside `KERNELBASE.dll`, at offset `0x3a4b2`.
3. **09:17:45** — Outlook crashed again, roughly 3.5 minutes later, with the **exact same exception code and fault offset** as the first crash — indicating the same code path was hit both times, not a random/one-off memory issue.
4. **09:18:01** — Windows Error Reporting logged the second crash into a fault bucket (`APPCRASH`), confirming it as a recognized crash type for telemetry purposes.
5. **09:18:05** — The .NET Runtime reported an unhandled `System.AccessViolationException` in `OUTLOOK.EXE` — the managed-code equivalent of the same access violation, pointing toward managed (.NET/VSTO) code being involved in triggering the fault.

---

## 3. Most Likely Cause (with Evidence)

**Most likely cause:** A third-party Outlook add-in — likely VSTO/.NET-based — is triggering an invalid memory access shortly after Outlook starts, surfacing as an access violation in `KERNELBASE.dll` at a consistent offset.

**Supporting evidence:**
- The **identical fault offset** in both 1000 events points to a deterministic, reproducible trigger (e.g., a specific code path executed on/shortly after startup) rather than random memory corruption, which would typically produce varying offsets across crashes.
- The **1026 .NET Runtime event** reporting `System.AccessViolationException` indicates managed code was on the call stack when the violation occurred — this is consistent with a VSTO/.NET-based Outlook add-in being involved, since a purely native-code crash would not typically also surface as a managed `AccessViolationException` via the CLR.
- Both crashes occurred within minutes of Outlook starting (09:13:44 start → 09:14:22 first crash; second crash at 09:17:45 implies Outlook was relaunched and crashed again quickly), consistent with an add-in that loads and misbehaves early in the Outlook startup sequence.

**Evidence gaps to flag before finalizing this cause:**
- **No specific add-in name is present in the provided logs.** This RCA does not assume a particular add-in — confirm via the `outlook.exe /safe` test (see Recommendations) before naming one in a change/remediation ticket.
- Build `16.0.17126.20132` should be **checked against Microsoft's official Office update history** to rule out (or confirm) a known, already-patched bug matching this signature — not confirmed here, flagged for verification.
- No evidence was reviewed regarding recent Windows updates, antivirus/DLP agent updates, or new software installs around 2024-03-15 that could correlate with the onset of this crash — recommend checking Windows Update/patch history and software inventory change logs for that date.

---

## 4. Five Whys Analysis

| # | Why? | Answer |
|---|---|---|
| 1 | Why did Outlook crash? | An access violation (`0xc0000005`) occurred inside `KERNELBASE.dll` at a specific, repeatable offset while Outlook was running. |
| 2 | Why did the access violation occur at that specific, repeatable location? | The identical fault offset across both crashes indicates a deterministic code path was executed each time — consistent with a specific add-in or component performing an invalid memory operation, rather than random corruption. |
| 3 | Why would an add-in trigger this? | The companion `.NET Runtime` event (1026) shows a `System.AccessViolationException`, indicating managed code was involved — pointing to a VSTO/.NET-based Outlook add-in with a bug (e.g., invalid pointer/interop call) that surfaces as a native access violation. **Not yet confirmed which add-in** — requires the safe-mode test recommended below. |
| 4 | Why wasn't this caught before affecting the user twice in a row? | There is no evidence of add-in crash monitoring/alerting or a "disable problem add-ins automatically" policy in place — Outlook by default will keep loading a misbehaving add-in on every relaunch unless it trips Office's own slow/crashing add-in detection, which was not observed in the provided log excerpt. |
| 5 | Why did the crash recur within minutes (09:14 and 09:17)? | The user (or Outlook's auto-restart behavior) relaunched Outlook shortly after the first crash, and since the underlying add-in/component was not disabled or fixed between attempts, the same fault was triggered again on the next launch. |

**Root cause:** A recurring access violation, most likely caused by a specific Outlook add-in (probable VSTO/.NET-based component) executing an invalid memory operation early in Outlook's startup sequence, with no automatic add-in fault isolation preventing the same crash from repeating on subsequent launches.

---

## 5. Recommendations

1. **Confirm the add-in as root cause** by running `outlook.exe /safe` and verifying the crash does not reproduce; then re-enable add-ins one at a time to isolate the specific one.
2. **Update Office/Outlook to the latest Click-to-Run build** and check Microsoft's official update history for build `16.0.17126.20132` to see if this crash signature is a documented, already-fixed issue — **verify against Microsoft documentation**, do not assume.
3. **Run Quick Repair (then Online Repair if needed)** on the Office installation to rule out corrupted Office components.
4. **Check/rebuild the Outlook OST and test a new profile** to rule out data-file/profile corruption as a contributing factor.
5. **Inventory non-Microsoft DLLs loaded into OUTLOOK.EXE** (via Process Explorer/Autoruns) to identify the specific add-in or shell-extension DLL responsible, and coordinate with the vendor/security team on a permanent fix or exclusion.
6. **Rule out hardware memory issues** only if the above steps do not resolve the crash — the identical fault offset makes this the least likely explanation, but a quick `mdsched.exe` run is low-cost.
