# Microsoft 365 Copilot Readiness Checklist — Finance Department

**Date:** 2026-08-12
**Scope:** Finance department, ~200 users, M365 E5 licensed
**Context:** High data sensitivity (payroll, board packs, M&A documents, client financial data). SharePoint permissions inherited from a 2019 migration and never fully audited since. Copilot add-on not yet assigned.

---

## ⚠️ Priority Zero: Permissions & Oversharing Checks (Must Complete Before Any Rollout)

Copilot surfaces content based on each user's existing access. Because this department's permissions have never been audited since a 2019 migration, any oversharing today becomes immediately and effortlessly discoverable through Copilot prompts. This is the single highest-risk item in this checklist and must be treated as a **blocking prerequisite**, not a parallel task.

- [ ] Run a full SharePoint/OneDrive permissions audit across all Finance sites, libraries, and document sets (use SharePoint Advanced Management / access reviews or equivalent).
- [ ] Identify and remediate "Everyone" / "Everyone except external users" / broad "All Company" links on any site containing payroll, board packs, M&A, or client financial data.
- [ ] Identify and review all anonymous/"Anyone" sharing links still active; expire or convert to named-user links.
- [ ] Review site-level permission inheritance — flag any subsites/libraries with broken inheritance and unexplained unique permissions.
- [ ] Specifically audit access to M&A and board-pack document sets given confidentiality and insider-risk sensitivity; confirm access is limited to named individuals, not broad groups.
- [ ] Review Teams/Groups membership tied to Finance SharePoint sites for stale or unexpected members (leavers, contractors, cross-department staff).
- [ ] Confirm a named owner exists for each Finance SharePoint site who is accountable for ongoing access reviews.
- [ ] Re-run oversharing report after remediation to confirm reductions before enabling Copilot for any pilot users.
- [ ] Set a recurring (e.g. quarterly) permissions review cadence going forward — this must not be a one-off cleanup.

**Do not proceed to Copilot assignment for this department until the above items are signed off.**

---

## 1) Licensing Prerequisites

- [ ] Confirm all ~200 users hold an eligible base license (M365 E5 already confirmed).
- [ ] Confirm Copilot add-on licenses are procured and available for assignment.
- [ ] Decide and document rollout approach (full department vs. phased/pilot group first).
- [ ] Confirm license assignment method (direct, group-based licensing) and who owns this in IT.

## 2) Microsoft 365 Apps Client Version Requirements

- [ ] Confirm all Finance devices run Microsoft 365 Apps for enterprise (not perpetual/volume-licensed Office).
- [ ] Confirm apps are on the Current Channel (or Monthly Enterprise Channel) and meet Copilot's minimum supported build.
- [ ] Confirm Outlook, Word, Excel, PowerPoint, and Teams are all updated to compatible versions — check for any users still on outdated builds.
- [ ] Confirm Teams is running the new Teams client where required for Copilot features.
- [ ] Identify any devices/users on unsupported or legacy OS/app configurations and remediate before enablement.

## 3) Identity / MFA Readiness

- [ ] Confirm MFA is enforced for all 200 Finance users (not just conditionally).
- [ ] Confirm Conditional Access policies apply consistently to this department, including for Copilot/M365 endpoints.
- [ ] Review any legacy authentication protocols still enabled and disable where possible.
- [ ] Confirm privileged/admin accounts in Finance (if any) have additional protections (e.g. PIM, stricter Conditional Access).
- [ ] Confirm device compliance (Intune) is required for access where applicable.

## 4) Sensitivity Labelling

- [ ] Confirm sensitivity labels are published and available to Finance users (e.g. Confidential, Highly Confidential).
- [ ] Confirm auto-labelling or default labelling policies are applied to payroll, board pack, M&A, and client financial data locations.
- [ ] Confirm label-based encryption/access restrictions are enforced on the most sensitive document sets, not just visual labels.
- [ ] Spot-check a sample of high-sensitivity documents to confirm correct label is actually applied (not just policy existing on paper).
- [ ] Confirm DLP policies are active and aligned with labels for this department's data types.

## 5) End-User Comms / Enablement

- [ ] Prepare a short plain-language notice explaining what Copilot is, what it can/can't access, and that it only surfaces content the user already has permission to see.
- [ ] Include guidance on verifying AI-generated outputs before using them in client-facing or board materials.
- [ ] Provide a simple channel for reporting anything Copilot surfaces that looks like it shouldn't have been accessible.
- [ ] Run a short awareness session or guide for the pilot group before wider rollout.
- [ ] Set expectations that rollout may be phased and tied to completion of the permissions audit above.

---

## Recommended Sequencing

1. Complete Priority Zero permissions/oversharing audit and remediation.
2. Confirm licensing, client versions, and identity/MFA readiness in parallel.
3. Confirm sensitivity labelling coverage on high-risk data.
4. Run end-user comms/enablement.
5. Assign Copilot to a small pilot group first, re-verify no oversharing issues surfaced, then proceed to full department rollout.
