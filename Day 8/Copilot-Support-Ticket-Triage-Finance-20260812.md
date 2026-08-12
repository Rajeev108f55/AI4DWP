# Copilot Support Ticket Triage — Finance Department

**Date:** 2026-08-12
**Triage principle:** Default to non-Copilot causes (permissions, indexing, labelling, licensing, external sharing) unless the evidence genuinely rules them all out. "Genuine Copilot fault" is a last resort, not a first guess.

---

## Ticket 1 — Finance lead: Copilot won't summarise the Q3 board pack in SharePoint. "It's right there, I can see it myself."

**Likely cause (ranked):**
1. Sensitivity label restriction — board packs are commonly protected with encryption/label restrictions that block AI processing even when the user can open the file manually.
2. Data indexing lag — if the board pack was recently uploaded/modified, it may not yet be crawled into the search index Copilot relies on.
3. Permissions/access boundary — the user may see the file via an inherited or link-based route that differs from what Copilot's permission check evaluates.

**Fastest check:** Open the file's sensitivity label/protection settings and confirm whether encryption or a restrictive label is applied.

**Is this actually a Copilot bug?** No — this pattern (visible to user, blocked for Copilot) is a well-known label/encryption restriction working as designed, not a fault.

---

## Ticket 2 — New hire (started yesterday): Copilot in Outlook seems to know nothing about my recent emails.

**Likely cause (ranked):**
1. Data indexing lag — a brand-new mailbox typically needs time before content is fully indexed for Copilot grounding.
2. License/client prerequisite issue — Copilot licensing/provisioning for new starters can lag behind account creation by a day or more.
3. Permissions/access boundary — unlikely for their own mailbox, but worth ruling out if any conditional access/onboarding policy is incomplete.

**Fastest check:** Confirm the Copilot license is actually assigned and active on the new hire's account, and note how long ago the mailbox was provisioned.

**Is this actually a Copilot bug?** No — this is expected onboarding/indexing lag for a 1-day-old account.

---

## Ticket 3 — HR manager: Asked Copilot in Word to pull data from a sensitive salary review spreadsheet, got "I don't have access to that content."

**Likely cause (ranked):**
1. Permissions/access boundary — the explicit "I don't have access" message strongly suggests the HR manager does not actually have direct permission to that specific file, despite assuming they should.
2. Sensitivity label restriction — the file may carry a restrictive label limiting AI/Copilot processing even for users with some level of access.
3. Data indexing lag — less likely given the explicit access-denial message rather than a "not found" response.

**Fastest check:** Verify the HR manager's actual permission level on that specific spreadsheet (not just the folder or site) in SharePoint/OneDrive.

**Is this actually a Copilot bug?** No — the explicit access-denied response indicates the permission boundary is functioning as intended (or is misconfigured), not a Copilot fault.

---

## Ticket 4 — Sales rep: Copilot in Teams can't find a client contract shared via a guest link from another org.

**Likely cause (ranked):**
1. Guest/external sharing limitation — Copilot has known constraints around indexing and grounding on externally-shared/guest-link content, especially from another organisation.
2. Permissions/access boundary — depending on how the guest link was set up, the rep's effective access may not align with what Copilot's permission check requires.
3. Data indexing lag — possible if the file is recently shared, but less likely to be the primary cause here.

**Fastest check:** Confirm the tenant's external/guest sharing settings and how the contract was actually shared (named guest account vs anonymous link).

**Is this actually a Copilot bug?** No — this matches a known limitation area for externally shared content, not a fault.

---

## Ticket 5 — IT admin: Copilot suddenly stopped working for the whole Finance team this morning, was fine yesterday.

**Likely cause (ranked):**
1. License/client prerequisite issue — a bulk license change, group-based licensing edit, or Conditional Access policy pushed overnight is the most common explanation for a sudden, team-wide change.
2. Permissions/access boundary — a change to group membership or a security group tied to Finance access could produce the same symptom.
3. Genuine Copilot fault (service outage) — only conclude this after ruling out recent admin-side changes, since a whole-team simultaneous failure could equally be a config change as an actual service incident.

**Fastest check:** Check Microsoft 365 admin center Service Health for active Copilot incidents, and simultaneously check for any overnight license/Conditional Access/group changes affecting the Finance security group.

**Is this actually a Copilot bug?** Unclear — a genuine outage is possible and should be checked via Service Health, but an overnight config/licensing change is at least equally likely and must be ruled out first, not assumed last.

---

## Ticket 6 — Manager: Copilot found and summarised a file I don't remember ever opening, from a folder I forgot I had access to.

**Likely cause (ranked):**
1. Permissions/access boundary — this is a case of pre-existing oversharing being surfaced: the manager already had access (likely inherited or via group membership) but was unaware of it. Copilot is simply making previously-hidden access visible.

**Fastest check:** Run an access/permissions report on that specific file or folder to confirm how the manager gained access (direct grant, inherited permission, or group membership) and whether that access is still appropriate.

**Is this actually a Copilot bug?** No — Copilot is behaving correctly by respecting existing permissions. The real issue is a permissions hygiene/oversharing finding, not a Copilot fault — and should be routed to the permissions audit workstream.

---

## Ticket 7 — Analyst: Copilot gives generic answers, doesn't seem to use any of our internal SharePoint content at all.

**Likely cause (ranked):**
1. License/client prerequisite issue — the analyst may be using a Copilot experience without enterprise data grounding (e.g. a consumer/web version instead of the licensed work experience), which would explain fully generic answers.
2. Permissions/access boundary — the analyst may genuinely lack access to the relevant SharePoint sites/content being asked about.
3. Data indexing lag — possible if the relevant content is very recent, though less likely to explain a consistent, total lack of grounding.

**Fastest check:** Confirm which Copilot experience the analyst is actually using and whether their Copilot license/entitlement is correctly assigned and active.

**Is this actually a Copilot bug?** No — this pattern is most consistent with a licensing/experience configuration issue rather than a product fault.

---

## Ticket 8 — Executive assistant: Copilot in Outlook can't see a shared mailbox's calendar managed on behalf of a director.

**Likely cause (ranked):**
1. Permissions/access boundary — shared mailbox delegate access is a distinct permission model from the EA's own mailbox, and Copilot may not resolve delegated shared-mailbox access the same way.
2. License/client prerequisite issue — Copilot support for shared mailboxes is limited/inconsistent depending on configuration and may not extend to calendar data in this way at all.
3. Data indexing lag — less likely to be the primary cause given this looks like a structural access-model limitation rather than a timing issue.

**Fastest check:** Verify the EA's delegate/Full Access permission level on the shared mailbox, and confirm whether Copilot in Outlook currently supports shared-mailbox grounding at all.

**Is this actually a Copilot bug?** Unclear — this closely matches a known product limitation around shared mailbox support rather than a fault, but should be confirmed against current documented Copilot capability before closing as "by design."
