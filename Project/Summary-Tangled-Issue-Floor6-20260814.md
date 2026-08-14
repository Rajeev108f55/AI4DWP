# Summary — Tangled Issues from Floor 6 Slack Report (09:14)

The original Slack message bundles three separate problems together. They are separated below and ordered by urgency, with the first diagnostic check and rationale for each.

---

## 1. Copilot Showing Unauthorized Client Matter Data (Highest Urgency)

**Issue:** A paralegal reports Copilot displayed a client matter she states she has never had access to.

**What to check first:** Escalate to the security/data protection team to review the paralegal's permission groups/roles and Copilot/SharePoint access scope for the client matter in question.

**Why:** This is a potential confidentiality/data breach involving client matter data. Unlike the other two issues, this carries regulatory and client-trust risk and cannot wait — it needs to be confirmed or ruled out before anything else, regardless of how the login/shortcut issues resolve.

---

## 2. Login Failures / Slow Logins (Medium-High Urgency)

**Issue:** A dozen+ Floor 6 users can't log in or logins are taking a long time.

**What to check first:** Pull event logs / sign-in logs from one or two affected Floor 6 machines to identify error codes, and check whether these logins correlate with Friday's document management app rollout (e.g., new permissions groups, GPO changes, or profile path changes).

**Why:** This affects the largest number of users and directly blocks them from working, making it a productivity-critical issue. Checking logs first (rather than reimaging or rolling back) narrows down whether the cause is authentication, profile, or network related before deciding on a fix.

---

## 3. Missing Desktop Shortcuts (Lower Urgency)

**Issue:** At least one user reports their desktop shortcuts have vanished.

**What to check first:** Check the affected user's profile (local vs. roaming/FSLogix) and compare it against a known-good profile to see if shortcut/configuration data was lost or not applied.

**Why:** This affects the fewest confirmed users so far and is a cosmetic/convenience issue rather than a blocker to logging in or working — shortcuts can be recreated manually as a workaround. However, it may still be a symptom of the same underlying profile/rollout issue as the login failures, so it's worth checking for a common root cause once the higher-urgency items are underway.

---

## Notes
- Whether all three issues share a common root cause (Friday's document management app rollout) is **to confirm** — this should be investigated as a possible link once each issue is triaged individually.
- No facts beyond what was stated in the original Slack message have been assumed.
