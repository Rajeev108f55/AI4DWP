# Microsoft 365 Copilot Rollout Tiers — Finance Department

**Date:** 2026-08-12
**Source:** Derived from M365-Copilot-Readiness-Checklist-Finance-20260812.md

---

## MUST Complete Before Rollout (Blocking)
- Full SharePoint/OneDrive permissions audit across all Finance sites/libraries
- Remediate "Everyone"/"All Company" broad links on payroll, board pack, M&A, client financial data
- Review and expire/convert anonymous "Anyone" sharing links
- Audit M&A and board-pack access to confirm named-individual-only access
- Review Teams/Groups membership for stale or unexpected members
- Re-run oversharing report to confirm remediation before any pilot assignment
- Confirm MFA enforced for all 200 Finance users
- Confirm Conditional Access applies consistently, including for Copilot/M365 endpoints

## SHOULD Complete Before Rollout (High Risk if Skipped)
- Confirm named site owners accountable for ongoing access reviews
- Review legacy authentication protocols and disable where possible
- Confirm sensitivity labels published and auto-labelling applied to high-sensitivity locations
- Spot-check sample documents to confirm labels are actually applied correctly
- Confirm DLP policies active and aligned to labels
- Confirm Microsoft 365 Apps client versions/channel meet Copilot minimums
- Identify and remediate outdated/unsupported app or OS builds
- Prepare end-user comms explaining what Copilot can/can't access

## CAN Complete During/After Rollout (Lower Risk)
- Confirm license assignment method and rollout approach documentation
- Confirm privileged/admin account protections (PIM, stricter CA) if not already in place
- Confirm device compliance (Intune) enforcement refinements
- Run awareness/enablement session for pilot group (can run just ahead of/alongside pilot)
- Set up simple reporting channel for oversharing discoveries
- Establish recurring quarterly permissions review cadence (ongoing process, not a one-time gate)

---

## Why Permissions/Oversharing Belongs in MUST, Despite Being Harder Than Licensing or Client Version Checks

Licensing and client version checks are simpler to verify, but they are **binary and low-consequence**: a missing license just means a user can't access Copilot yet, and an outdated client version just means a feature doesn't render — both fail safely and are trivially reversible with no exposure risk.

Permissions and oversharing are different in kind, not just difficulty:

1. **Copilot inherits and amplifies existing access, instantly.** Copilot doesn't create new permissions — it makes every file a user can already technically reach immediately discoverable through natural-language search, including content the user never knew existed or would never have found by browsing manually. A 2019-era permission mistake that's been dormant and harmless for years becomes an active exposure the moment Copilot is switched on.

2. **The specific data at risk is the department's most sensitive category.** Payroll, board packs, M&A documents, and client financial data carry regulatory (data protection), contractual (client confidentiality), and market-sensitive (insider information/M&A) risk. A single oversharing gap surfaced via Copilot to the wrong person could trigger regulatory reporting obligations, client trust damage, or insider-trading exposure — consequences that are severe and, unlike a licensing gap, **not reversible after the fact.**

3. **The audit has never been done.** This isn't a "probably fine, let's double check" item — it's a known, six-year gap with no verification since. Treating it as anything less than blocking would mean knowingly deploying an AI discovery tool over an unaudited access surface in the highest-sensitivity department in the business.

4. **Remediation timelines are unpredictable, so it must gate the schedule, not follow it.** Licensing and client versions can be fixed same-day. Permissions remediation may uncover issues that take longer to resolve (ownership disputes, broken inheritance, legacy shares) — which is exactly why it must be started first and treated as the pacing item for rollout, not squeezed in alongside faster, lower-risk tasks.

In short: licensing and client version failures are inconvenient; a permissions failure here is a potential confidentiality and regulatory incident. That asymmetry in consequence — not the effort required — is why it sits alone at the top of the MUST tier.
