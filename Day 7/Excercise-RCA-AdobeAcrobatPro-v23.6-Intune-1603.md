# Root Cause Analysis — Adobe Acrobat Pro v23.6 Intune Deployment Failure
**Reference:** INC-APP-ADOBE-2024-0315  
**Author:** DWP Analyst  
**Date:** 2026-08-11  
**Status:** Draft  
**Environment:** Microsoft Intune Win32 app deployment (Windows 11 fleet)

---

## 1. Executive Summary

Adobe Acrobat Pro v23.6 deployment failed repeatedly through Intune. The installer returned error 1603 on each attempt, and post-install detection reported Not detected because the configured registry key/value was not found. The evidence indicates a deployment configuration mismatch and an unresolved MSI runtime failure path. The incident did not self-heal because Intune retried the same failing command and detection logic every 60 minutes.

Primary RCA finding: the detection rule targeted an Acrobat Reader registry location while the app being deployed is Acrobat Pro, creating a high-likelihood configuration mismatch and unreliable install-state reporting. Secondary unresolved factor: MSI 1603 requires verbose MSI logging to confirm exact technical failure cause.

---

## 2. Incident Scope and Impact

- Affected service: Intune-delivered Adobe Acrobat Pro v23.6 application install
- Affected workflow: automated Win32 app installation and compliance reporting
- User impact: application unavailable on targeted devices; repeated install retries consume endpoint and service desk effort
- Business impact: delayed availability of required application to assigned users

---

## 3. Evidence Collected

### 3.1 Relevant Log Lines Provided

- App install started in SYSTEM context
- Install command executed: msiexec /i AcrobatPro.msi /quiet
- Installer return code 1603 (repeated)
- Detection rule executed after failure using registry key under Adobe Acrobat Reader 23.0
- Detection value not found
- Detection result Not detected
- Retry scheduled every 60 minutes and failure repeated on retry 1

### 3.2 Distinct Error Code Present

- 1603 (observed multiple times)

Note: 1603 is a generic MSI fatal error and is not a root cause by itself.

### 3.3 Observed Behavioral Pattern

- Install fails first (1603)
- Detection then runs and fails to detect expected key/value
- Intune marks app Failed and schedules retry
- Same command and same detection logic repeat without environmental or config change

This confirms deterministic failure under current package/config conditions.

---

## 4. Timeline (From Provided Evidence)

- 2024-03-15 10:01:00 — Install started for Adobe Acrobat Pro v23.6
- 2024-03-15 10:01:03 — Install command launched (msiexec /i AcrobatPro.msi /quiet)
- 2024-03-15 10:01:44 — Return code 1603; install marked failed
- 2024-03-15 10:01:45 — Detection rule ran against Adobe Acrobat Reader key; value not found
- 2024-03-15 10:01:47 — App install result marked Failed; retry scheduled in 60 minutes
- 2024-03-15 11:01:47 — Retry attempt 1 started
- 2024-03-15 11:02:31 — Return code 1603 repeated
- 2024-03-15 11:02:32 — Retry 1 failed; next retry scheduled

---

## 5. Root Cause Statement

The deployment failed due to a combination of:

1. Confirmed deployment configuration defect: detection rule appears misaligned to product type (Reader path used while deploying Pro package), causing incorrect install-state validation behavior.
2. Unresolved installer execution failure: MSI returned 1603 repeatedly, indicating a fatal install path that was not diagnosable from high-level logs alone because verbose MSI logging was not captured at incident time.

The repeat cycle persisted because Intune retries reused the same failing command and unchanged detection configuration.

---

## 6. 5-Why Analysis

### Problem Statement
Adobe Acrobat Pro v23.6 did not install via Intune and kept failing repeatedly.

### Why 1
Why did the deployment fail?

Because the installer returned 1603 and Intune marked the app install as Failed.

### Why 2
Why did users still not show as installed after retries?

Because detection returned Not detected after each attempt, so Intune kept the app in failed state and retried.

### Why 3
Why did detection return Not detected?

Because the configured registry detection path pointed to Adobe Acrobat Reader 23.0 key/value and the expected value was not present.

### Why 4
Why was detection configured against a Reader location while deploying Acrobat Pro?

Because app packaging and detection rule design were not validated together on a known-good reference device before broad assignment.

### Why 5
Why was package and detection validation not completed before rollout?

Because the deployment process lacked a mandatory pre-release quality gate requiring evidence of:
- successful silent install in SYSTEM context,
- verified detection rule match against the installed product,
- and pilot acceptance criteria before wider assignment.

### 5-Why Conclusion
The systemic root cause is process control failure in release validation for Win32 Intune apps. The immediate technical trigger was a likely detection-rule/product mismatch, combined with unresolved MSI 1603 installer failure details.

---

## 7. Corrective Actions (Immediate)

1. Stop broad assignment and restrict deployment to a controlled pilot group.
2. Capture verbose MSI log using the same install command with logging enabled and identify first failure near Return value 3.
3. Correct detection rule to the actual Acrobat Pro registry or MSI identity confirmed from a known-good manual install.
4. Repackage or update install command if MSI log identifies command-line, prerequisite, or conflict issue.
5. Retest in pilot until thresholds are met, then re-enable phased rollout.

---

## 8. Preventive Actions (Process Improvements)

1. Introduce mandatory Win32 App Release Checklist before any assignment beyond pilot:
- SYSTEM-context install test evidence
- uninstall test evidence
- detection rule validation evidence (registry/MSI/file)
- return code review
- rollback assignment prepared and tested

2. Enforce two-stage approval:
- Packaging engineer sign-off (technical correctness)
- Service owner sign-off (business readiness)

3. Add gate in deployment workflow: no production assignment allowed unless pilot success is at or above target threshold with documented telemetry.

4. Create a standard Intune troubleshooting runbook for MSI 1603 including required logs, queries, and decision points.

---

## 9. Verification Criteria After Fix

The fix is considered successful only when all are true:

- Pilot group install success is at or above agreed threshold (for example 95%+)
- Failure rate remains below agreed threshold over monitoring window
- Detection status shows Installed for successful endpoints
- No repeating 1603 pattern in retry cycle
- Service desk ticket volume remains within normal range for this app rollout

---

## 10. Residual Risk and Open Items

- Open item: exact technical cause of MSI 1603 remains to be confirmed from verbose MSI logs.
- Residual risk: if only detection is corrected but installer root cause remains, failures will continue.
- Required verification against Microsoft/vendor documentation:
  - MSI 1603 remediation guidance
  - Adobe Acrobat Pro supported upgrade and coexistence matrix
  - Final production detection key/value for deployed channel and architecture

---

## 11. Closure Recommendation

Do not resume broad rollout until both conditions are satisfied:

1. MSI 1603 root-cause path is identified and corrected in package/command.
2. Detection rule is validated against actual Acrobat Pro installed state on reference and pilot devices.

Once both are evidenced, proceed with phased ring deployment only.
