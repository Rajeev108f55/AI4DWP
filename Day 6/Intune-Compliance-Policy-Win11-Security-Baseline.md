# Windows 11 Intune Compliance Policy – Security Baseline Translation
**Author:** DWP Engineer  
**Date:** 2026-08-10  
**Scope:** Windows 11 managed devices enrolled in Microsoft Intune  
**Grace Period:** 7 days applied to all settings below  

---

## How to Apply Grace Period
In Intune > Devices > Compliance policies > [Your Policy] > **Properties > Actions for noncompliance**:  
Set "Mark device noncompliant" action to **Schedule (days after noncompliance): 7**

---

## Requirement 1 – BitLocker Must Be Enabled on the OS Drive

| Field | Detail |
|---|---|
| **Setting Name** | Require BitLocker |
| **UI Path** | Endpoint security > Disk encryption > Create policy > Platform: Windows 10 and later > Profile: BitLocker **— OR —** Devices > Compliance policies > Create policy > Windows 10/11 > Device Health > **Require BitLocker** |
| **Value** | Require |
| **Effect** | Intune queries the BitLocker status of the OS (C:) drive via the Health Attestation Service. Devices without encryption are marked non-compliant. |
| **False-Positive Risk** | • Device has BitLocker enabled but encryption is still **in progress** at time of check — reports as not compliant until 100% complete. <br>• TPM not provisioned or in a degraded state causes attestation failure even if BitLocker is on. <br>• Freshly re-imaged devices during the encryption warm-up window. |
| **Recommendation** | Pair with a BitLocker **configuration** profile (Endpoint security > Disk encryption) to enforce silent encryption via TPM. Monitor the "Not encrypted" report for devices legitimately mid-encryption rather than immediately blocking access. |

---

## Requirement 2 – Secure Boot Must Be Enabled

| Field | Detail |
|---|---|
| **Setting Name** | Require Secure Boot to be enabled on the device |
| **UI Path** | Devices > Compliance policies > Create policy > Windows 10/11 > **Device Health > Require Secure Boot to be enabled on the device** |
| **Value** | Require |
| **Effect** | Uses the Windows Health Attestation Service (HAS) to confirm Secure Boot state. Devices where Secure Boot has been disabled in firmware are non-compliant. |
| **False-Positive Risk** | • Older hardware (pre-2012) that does not support Secure Boot — these will always fail. <br>• Virtual machines (VMware, Hyper-V Generation 1 VMs) without Secure Boot configured. <br>• Dual-boot Linux/Windows setups where Secure Boot is deliberately disabled. |
| **Recommendation** | Identify legacy hardware via Intune Device Hardware inventory before enforcing. Exclude known VM pools via a separate compliance policy with relaxed hardware requirements, scoped by an AAD group. |

---

## Requirement 3 – Minimum OS Build (N-1 = 22621.2861)

| Field | Detail |
|---|---|
| **Setting Name** | Minimum OS version |
| **UI Path** | Devices > Compliance policies > Create policy > Windows 10/11 > **Device Properties > Minimum OS version** |
| **Value** | `10.0.22621.2861` |
| **Effect** | Devices running an OS build older than Windows 11 22H2 build 22621.2861 are flagged as non-compliant. This enforces the N-1 policy (allowing current and one prior cumulative update). |
| **False-Positive Risk** | • Patch Tuesday rollout lag — devices waiting for WUfB (Windows Update for Business) ring deployment may temporarily fall below the threshold. <br>• Deferred update rings (e.g., 21-day or 30-day deferral policies) will cause fleet-wide non-compliance immediately after a new baseline is set. <br>• Devices in bandwidth-limited locations with slow update downloads. |
| **Recommendation** | Align the minimum build with your **slowest WUfB deferral ring** so devices are non-compliant only if they have genuinely missed updates, not just deferred ones. Review and update this value each Patch Tuesday cycle. Current latest good build noted: `10.0.22621.3155`. |

---

## Requirement 4 – Windows Defender Real-Time Protection Must Be On

| Field | Detail |
|---|---|
| **Setting Name** | Real-time protection |
| **UI Path** | Devices > Compliance policies > Create policy > Windows 10/11 > **System Security > Defender > Real-time protection** |
| **Value** | Require |
| **Effect** | Checks that Microsoft Defender Antivirus real-time protection is active. Devices with RTP disabled or where a third-party AV has taken over the Windows Security Center registration are flagged. |
| **False-Positive Risk** | • Third-party AV solutions (CrowdStrike, Sophos, etc.) that register with Windows Security Center and **disable Defender RTP by design** — this is expected behaviour but will trigger non-compliance unless the policy accounts for it. <br>• Brief RTP suspension during certain software installations or AV definition updates. |
| **Recommendation** | If a third-party EDR/AV is deployed, use **Microsoft Defender for Endpoint (MDE) integration** with Intune instead. The MDE connector reports device risk level, which is a more accurate signal than the raw Defender state. Set "Require the device to be at or under the machine risk score" to **Medium** or **Low**. |

---

## Requirement 5 – Firewall Must Be Enabled for All Profiles

| Field | Detail |
|---|---|
| **Setting Name** | Firewall |
| **UI Path** | Devices > Compliance policies > Create policy > Windows 10/11 > **System Security > Device security > Firewall** |
| **Value** | Require |
| **Effect** | Enforces that Windows Firewall is enabled across all three network profiles: Domain, Private, and Public. Any profile with the firewall disabled triggers non-compliance. |
| **False-Positive Risk** | • Third-party firewall software (Cisco, Symantec) that disables Windows Firewall as part of its installation — the Windows Security Center may report firewall as "off" even though a third-party firewall is active. <br>• GPO conflicts from legacy on-premise Group Policy disabling the firewall for specific profiles. |
| **Recommendation** | Audit existing GPO firewall settings before deploying. If a third-party firewall is authorised, document it in a Known Exception register and use an Intune filter or AAD group exclusion for those devices, or validate via the third-party product's own compliance reporting. |

---

## Requirement 6 – A PIN or Password Must Be Configured

| Field | Detail |
|---|---|
| **Setting Name** | Require a password to unlock mobile devices / Password required |
| **UI Path** | Devices > Compliance policies > Create policy > Windows 10/11 > **System Security > Password > Require a password to unlock mobile devices** |
| **Value** | Require |
| **Supporting Settings** | - **Minimum password length:** 8 (DWP baseline) <br>- **Password type:** Alphanumeric recommended; at minimum Numeric complex (PIN, no repeating/sequential sequences) <br>- **Maximum minutes of inactivity before password is required:** 15 |
| **Effect** | Ensures the device has a local or Windows Hello credential configured. Devices with no lock screen credential are non-compliant. |
| **False-Positive Risk** | • Shared/kiosk devices configured intentionally without a PIN (auto-logon) — these will always be non-compliant under this requirement. <br>• Windows Hello for Business provisioning delay on new enrolments — device may report no PIN configured during the WHFB provisioning window. |
| **Recommendation** | Exclude dedicated kiosk/shared device AAD groups from this policy and apply a separate Kiosk compliance policy. For WHFB provisioning delays, the 7-day grace period should absorb the enrolment window for most users. |

---

## Requirement 7 – Device Must Not Be Jailbroken or Rooted

| Field | Detail |
|---|---|
| **Setting Name** | Block jailbroken devices (Device Health Attestation) |
| **UI Path** | Devices > Compliance policies > Create policy > Windows 10/11 > **Device Health > Require the device to be at or under the device threat level** — set to **Secured** **— OR —** for attestation-based check: **Device Health > Windows Health Attestation Service evaluation rules** |
| **Value** | Device Health Attestation — **Require** (all sub-settings) **AND/OR** Device threat level: **Secured** |
| **Effect** | On Windows 11, "jailbroken/rooted" maps to attestation failures: code integrity violations, boot configuration tampering, test-signing mode enabled, or early-launch antimalware (ELAM) disabled. "Secured" threat level (via MDE integration) means zero active threats detected. |
| **False-Positive Risk** | • Developer machines with **Test Signing** mode enabled (`bcdedit /set testsigning on`) will fail code integrity checks. <br>• Devices with custom Secure Boot keys or unsigned drivers. <br>• HAS reporting latency — attestation tokens are cached and may be stale on first check post-enrolment. |
| **Recommendation** | Enable MDE integration for richer signal. Identify developer/test machines via AAD group and apply a separate policy with "Low" threat level tolerance rather than "Secured". Review Windows Health Attestation report under Devices > Monitor > Device compliance for attestation failure details. |

---

## UI Path Verification Notes

> ✅ **Paths below verified against Microsoft Learn docs (last updated 2026-07-01). Source: [Windows compliance settings in Microsoft Intune](https://learn.microsoft.com/en-us/mem/intune/protect/compliance-policy-create-windows)**

| Setting | Verified Status | Notes |
|---|---|---|
| **Require BitLocker** | ✅ Confirmed — still in Compliance policy | Lives under **Device Health > Windows Health Attestation Service evaluation rules**. A separate **Encryption of data storage on a device** toggle exists under System Security > Encryption but uses a weaker CSP check (DeviceStatus, not TPM-backed HAS). Use the BitLocker HAS setting for stronger assurance. Requires a reboot after encryption completes before the device reports compliant. |
| **Require Secure Boot** | ✅ Confirmed | Under **Device Health > Windows Health Attestation Service evaluation rules**. Note: devices without TPM 2.0 will always report Not Compliant. |
| **Minimum OS version** | ✅ Confirmed | Under **Device Properties > Operating system version**. Use `10.0.22621.2861` — Windows 11 reports internally as `10.0.XXXXX`. A newer **Valid operating system builds** range setting is also available for more granular N-1 band control. |
| **Real-time protection** | ✅ Confirmed | Under **System Security > Defender > Real-time protection** (Defender sub-section, not top-level System Security). |
| **Firewall** | ✅ Confirmed | Under **System Security > Device security > Firewall** (Device security sub-section). Setting name in the portal is **Firewall**, not "Microsoft Defender Firewall". |
| **Password** | ✅ Confirmed | Under **System Security > Password > Require a password to unlock mobile devices**. |
| **Device threat level (MDE)** | ⚠️ Requires connector | **Require the device to be at or under the machine risk score** is under **Microsoft Defender for Endpoint** section. This setting does nothing if the MDE-Intune connector is not active. Verify under **Tenant admin > Connectors and tokens > Microsoft Defender for Endpoint**. |
| **Jailbroken / Rooted** | ℹ️ Not a native Windows setting | Microsoft docs confirm this is **Not applicable** on Windows. The correct Windows equivalent is the Device Health Attestation rules (code integrity, Secure Boot) combined with MDE risk score. |

---

## Summary Table

| Req | Setting Name | Value | Grace Period |
|---|---|---|---|
| 1 | Require BitLocker | Require | 7 days |
| 2 | Require Secure Boot | Require | 7 days |
| 3 | Minimum OS version | 10.0.22621.2861 | 7 days |
| 4 | Real-time protection | Require | 7 days |
| 5 | Firewall | Require | 7 days |
| 6 | Require a password to unlock mobile devices | Require | 7 days |
| 7 | Device threat level / Health Attestation | Secured / Require | 7 days |

---

## Policy Validation Steps

### 1. Where to Find a Device's Compliance Status for This Specific Policy

**Path:** `intune.microsoft.com` > **Devices** > **All devices** > [select device] > **Device compliance**

This opens the per-device compliance blade. You will see every policy assigned to the device listed by name. Click the policy name to expand it and see the per-setting result — each setting shows **Compliant**, **Not compliant**, or **Not applicable** individually.

Alternatively, to view from the policy side:
`Devices` > **Compliance policies** > [select this policy] > **Device status**
This lists every device the policy is assigned to and its current state. Use the **Setting compliance** tab to pivot by setting rather than by device — useful for identifying which single setting is causing the most failures across the fleet.

---

### 2. Compliance States and Their Conditional Access Impact

| State | What It Means | Conditional Access Impact |
|---|---|---|
| **Compliant** | The device has checked in with Intune and passed every setting in the policy. | Full access granted to resources protected by CA policies that require a compliant device. |
| **Not compliant** | The device has checked in and failed one or more settings, **and** the grace period has expired (or no grace period is set). | CA blocks access to protected resources (Exchange Online, SharePoint, Teams, etc.). The user sees an error in the app or browser directing them to the Company Portal. The device can still reach non-CA-protected resources. |
| **In grace period** | The device has checked in and failed one or more settings, **but** the grace period (7 days in this policy) has not yet expired. | **Access is not blocked.** The device behaves as compliant for CA purposes during the grace window. The user receives a notification in Company Portal that the device is at risk, but is not locked out. This window is intended to allow time for remediation without impacting productivity. |

> ⚠️ **Important:** "In grace period" does **not** mean the device is safe — it means enforcement is deferred. A device with BitLocker disabled is genuinely non-compliant even while in grace period. The 7-day window should be used for remediation, not ignored.

---

### 3. BitLocker Showing Non-Compliant Despite Being Enabled — Three Most Common Causes

The **Require BitLocker** setting uses the **Windows Health Attestation Service (HAS)**, which reads TPM-backed attestation data, not just the BitLocker UI status. This means BitLocker can be "on" visually but still fail the HAS check.

---

#### Cause 1: Device Has Not Rebooted Since Encryption Completed

**Why it fires:** HAS reads attestation data that is captured and sealed at boot time. If BitLocker encryption finished after the last boot, the attestation token still reflects the pre-encryption state. Intune sees the stale token and reports non-compliant.

**Fastest check:**
```powershell
manage-bde -status C:
```
Look for `Percentage Encrypted: 100%` and `Protection Status: Protection On`.
If both are true and the device is still non-compliant in Intune — **reboot the device**, then trigger a manual sync: Company Portal app > **Sync** (or Intune admin center > Device > **Sync**). Re-check compliance status after 15 minutes.

---

#### Cause 2: BitLocker Is On But Suspended (Protectors Off)

**Why it fires:** Certain operations — Windows feature updates, firmware updates, BIOS changes, or BitLocker recovery key rotation — cause Windows to automatically **suspend** BitLocker protection. The drive remains encrypted but protection is paused (`Protection Status: Protection Off`). HAS detects this and reports non-compliant.

**Fastest check:**
```powershell
manage-bde -status C:
```
Look for `Protection Status: Protection Off`. If you see this:
```powershell
manage-bde -resume C:
```
Then reboot and sync. If suspension is happening repeatedly, check Windows Update logs — feature upgrades temporarily suspend BitLocker by design and should auto-resume after 2 reboots.

---

#### Cause 3: TPM Is Not Provisioned, Cleared, or in a Degraded State

**Why it fires:** HAS validates BitLocker status through the TPM. If the TPM is not initialised, was cleared (e.g., after a motherboard swap or BIOS reset), or is reporting a firmware error, HAS cannot obtain a valid attestation token — it returns no data, which Intune treats as non-compliant. The BitLocker UI may show encryption is on because Windows can encrypt without a TPM (using a password protector), but HAS specifically requires TPM-backed key protection.

**Fastest check:**
```powershell
Get-Tpm
```
Check:
- `TpmPresent: True`
- `TpmReady: True`
- `TpmEnabled: True`

If `TpmReady: False` — open **tpm.msc** and check for error messages. A "TPM is not ready for use" state often requires clearing and re-initialising the TPM in UEFI, then re-enabling BitLocker with TPM key protectors:
```powershell
manage-bde -protectors -get C:
```
Confirm a `TPM` type protector exists (not only a `Password` or `Recovery Key` protector). If no TPM protector is listed, BitLocker is not TPM-backed and will always fail HAS regardless of encryption status.

---

*Paths verified against Microsoft Learn docs (last updated 2026-07-01). Always validate in a test tenant or pilot group before broad rollout.*
