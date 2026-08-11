# Exercise Analysis — Adobe Acrobat Pro v23.6 Intune Deployment Failure
**Author:** DWP Analyst  
**Date:** 2026-08-11  
**Scope:** Repeated install failure via Intune Win32 app deployment

---

## 1) Distinct Error Code(s) Present in Provided Logs

From the provided lines, there is **one distinct numeric error code**:

- **`1603`** (returned twice by `msiexec` during install attempts)

No other numeric error code appears in the snippet.  
`Detection result: Not detected` is a status outcome, not a numeric installer error code.

> ⚠️ **Verify against Microsoft documentation:** `1603` is commonly interpreted as a generic MSI fatal install error, but the precise root cause must be determined from MSI verbose logs and environment state. Treat `1603` as a symptom code, not a final diagnosis.

---

## 2) Ranked Remediation Plan (Most Likely Fix First)

The ranking below is based on the exact evidence shown: install fails first (`1603`), then detection fails because key/value is absent.

### 1. Validate and correct the detection rule target (Highest probability of policy/config mismatch)

**Why ranked #1:** The deployed app is **Adobe Acrobat Pro**, but detection is checking `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0` (Reader path). If packaging and detection are mismatched, deployment behavior and reporting become unreliable and retries continue.

**Specific check:**
1. On a known-good device with Acrobat Pro v23.6 installed manually, run:
   ```powershell
   Get-ItemProperty "HKLM:\SOFTWARE\Adobe\*" -ErrorAction SilentlyContinue
   ```
2. Identify the actual Pro product key path and version value.
3. Compare with Intune detection rule:
   - Intune admin center > Apps > All apps > Adobe Acrobat Pro v23.6 > Properties > Detection rules
4. Confirm detection references the **Pro** key/value, not Reader.

**Remediation action:** Update detection rule to the exact Pro registry location/version (or MSI product code if available and stable).

> ⚠️ **Verify against vendor/Microsoft docs:** Exact registry path for Acrobat Pro v23.6 can vary by installer channel (MSI vs Adobe setup wrapper / 32-bit vs 64-bit view).

---

### 2. Capture MSI verbose log and isolate the real 1603 cause

**Why ranked #2:** `1603` is non-specific. Without verbose MSI logging, root cause is unknown and repeated retries will continue.

**Specific check:**
1. Re-run install command locally (SYSTEM-context simulation where possible) with verbose logging:
   ```cmd
   msiexec /i AcrobatPro.msi /quiet /L*v C:\Windows\Temp\AcrobatPro_Install.log
   ```
2. Open the log and search for:
   - `Return value 3`
   - First custom action or prerequisite failure immediately preceding it
3. Confirm whether failure is due to permissions, prerequisite, transform/cab source, pending reboot, or existing product conflict.

**Remediation action:** Fix the exact failing prerequisite/action found in the verbose log, then retest.

> ⚠️ **Verify against Microsoft docs:** MSI log triage guidance for `Return value 3` and `1603` handling should be cross-checked with current Microsoft installer troubleshooting guidance.

---

### 3. Check for existing/conflicting Acrobat/Reader product state before install

**Why ranked #3:** `1603` frequently occurs when an existing product baseline, architecture mismatch, or upgrade path conflict blocks install.

**Specific check:**
1. On failed endpoints, check installed Adobe products and versions:
   ```powershell
   Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
     Where-Object { $_.DisplayName -like "*Adobe*Acrobat*" -or $_.DisplayName -like "*Adobe*Reader*" } |
     Select-Object DisplayName, DisplayVersion, Publisher
   ```
2. Confirm whether older Acrobat/Reader variants are present and whether v23.6 package expects removal/upgrade first.
3. Check if x86/x64 mismatch exists between current install base and package.

**Remediation action:**
- If conflict exists, deploy uninstall/supersedence sequence first, then install v23.6.
- Use Intune supersedence/dependency ordering to enforce sequence.

> ⚠️ **Verify against Adobe deployment docs:** Supported upgrade paths and coexistence rules between Reader and Acrobat Pro.

---

### 4. Confirm install context and content integrity for SYSTEM deployment

**Why ranked #4:** Logs show SYSTEM context. If package source/extraction permissions or command assumptions require user context, install fails silently as `1603`.

**Specific check:**
1. Confirm Intune app is configured for:
   - Install behavior: **System**
   - Correct install command path/file names exactly matching package contents
2. Validate `.intunewin` contents and source extraction behavior by testing on a clean VM.
3. Confirm local temp/cache paths are writable by SYSTEM and not blocked by security tooling.

**Remediation action:** Repackage Win32 content with validated folder structure and tested silent command, then redeploy to pilot ring.

> ⚠️ **Verify against Microsoft docs:** Current Intune Win32 content prep and command execution context behavior.

---

### 5. Check pending reboot / endpoint health conditions that can trigger repeat 1603

**Why ranked #5:** Common operational cause when all config appears correct.

**Specific check:**
1. Check pending reboot indicators on failed devices:
   - `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`
   - `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired`
2. Verify disk space and endpoint security blocks during install window.

**Remediation action:**
- Force reboot, re-sync Intune, retry install.
- If security tooling is blocking MSI custom actions, create controlled allow policy for installer path/signature.

> ⚠️ **Verify against Microsoft docs:** Current recommended pending reboot detection and enterprise MSI remediation flow.

---

## 3) Practical Next Step Order (Execution Sequence)

1. Fix detection rule mismatch (Reader vs Pro) in Intune app config.
2. Run one controlled test install with full MSI verbose logging and identify exact `Return value 3` root cause.
3. Resolve product conflict/pre-req found in step 2.
4. Repackage/retest in a 10-device pilot assignment group.
5. Expand once failure rate is below threshold and detection consistently reports Installed.

---

## 4) Confidence Statement

- **High confidence:** Only distinct code in your supplied log snippet is `1603`; detection mismatch risk is real and should be corrected immediately.
- **Medium confidence:** Exact technical root cause of `1603` cannot be asserted from the snippet alone; MSI verbose logging is required before final fix is chosen.
