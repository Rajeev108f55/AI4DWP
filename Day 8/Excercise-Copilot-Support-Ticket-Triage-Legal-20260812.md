# Copilot Support Ticket Triage — Legal Team

**Date:** 2026-08-12

---

## 1) Paralegal — "I don't have access to that content" for a client NDA in SharePoint

**Likely cause (ranked):**
1. Permissions/access boundary — she genuinely lacks access to that folder (Copilot respects the same ACLs as SharePoint; hearing about a file in a meeting doesn't grant permission)
2. Data indexing lag — if access was *just* granted, Search/Graph indexing hasn't caught up yet
3. Sensitivity label restriction — label on the NDA folder may block AI processing even for authorized users

**Fastest check:** Have her (or IT) confirm in SharePoint directly whether she has Open/Read permission on that specific folder/file.

**Is this actually a Copilot bug?** No. Copilot is correctly enforcing the existing permission boundary — this is expected behavior, not a fault.

---

## 2) New associate (started this week) — Copilot in Outlook can't find case emails

**Likely cause (ranked):**
1. Data indexing lag — brand-new mailbox/account, mail and Graph index haven't fully populated
2. License/client prerequisite issue — Copilot license may not yet be provisioned/propagated for a first-week hire
3. Permissions/access boundary — she may simply not be on the case/shared mailbox yet

**Fastest check:** Verify her Copilot license is assigned and active in the admin center, and confirm account creation date vs. expected indexing SLA (typically up to 24–48 hrs for new accounts).

**Is this actually a Copilot bug?** Unclear, leaning No. Far more consistent with new-account provisioning/indexing delay than a product fault; revisit only if the issue persists after a few days with confirmed license and mailbox access.

---

## 3) Partner — Copilot surfaced a draft settlement from a matter they're not assigned to

**Likely cause (ranked):**
1. Permissions/access boundary — the partner actually has (likely inherited/over-broad) access to that folder, even if not "assigned" to the matter in the practice management sense
2. Guest/external sharing limitation — unlikely here, but worth ruling out if the file was shared via a broad link
3. Sensitivity label restriction — folder/file may be missing an appropriate restrictive label that should have scoped visibility

**Fastest check:** Check the partner's actual SharePoint permissions/group membership on that specific folder — matter assignment in a legal system and SharePoint ACLs are often not the same thing.

**Is this actually a Copilot bug?** No. This is very likely an over-permissioning issue (oversharing) — Copilot is surfacing content the underlying platform already says he can see. This is a priority access-governance finding, not a Copilot fault.

---

## 4) Legal ops manager — all 40 people on the Legal team suddenly lost Copilot access overnight

**Likely cause (ranked):**
1. License/client prerequisite issue — bulk license assignment change, expired license pool, or licensing group/policy change pushed overnight
2. Permissions/access boundary — a Conditional Access, security group, or tenant policy change affecting the whole team
3. Genuine Copilot fault — a service-wide outage (check Microsoft 365 Service Health first to rule in/out)

**Fastest check:** Check Microsoft 365 admin center Service Health for an active incident, then check license assignment/group membership for the Legal team.

**Is this actually a Copilot bug?** Unclear. A sudden, simultaneous, team-wide loss points strongly to a licensing/policy/service-health event; only classify as a genuine product bug if Service Health confirms an M365 Copilot incident.

---

## 5) Contract specialist — vague, generic answers about clauses in the contract templates library

**Likely cause (ranked):**
1. Data indexing lag — documents may be new/recently modified and not yet indexed for Copilot retrieval
2. Sensitivity label restriction — labels could be limiting how much content Copilot is allowed to extract/quote, causing generic fallback answers
3. License/client prerequisite issue — unlikely but worth confirming the correct SKU with grounding enabled

**Fastest check:** Confirm the templates were recently uploaded/edited and check whether they carry a restrictive sensitivity label; test with a known older, unlabeled document to compare grounding quality.

**Is this actually a Copilot bug?** Unclear. Generic answers are the classic symptom of Copilot falling back to general knowledge because it couldn't ground in the specific document (indexing or label restriction) — not a first-resort product fault.
</content>
