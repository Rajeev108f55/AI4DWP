# Reflection & Prevention — Floor 6 Incident (2026-08-14)

This note closes out the exercise with the two required elements — a concrete
prevention control and a documented reasoning correction — plus an explicit
walk-through of how each non-negotiable was satisfied and why.

---

## Prevention Note — the one control that would have caught this before Monday

**Concrete control:** Add a mandatory **Pilot Ring gate** to the Intune deployment
process: no app assignment may target the Floor 6 full-site device group directly.
Instead, the assignment must first target a `Ring-Pilot` group (≤10 devices) for a
minimum of **1 full business day**, and the Full-Floor assignment group's membership
can only be activated by a **second approver** manually toggling a "Pilot Complete"
flag once that bake period has passed with zero P1/P2 incidents logged against the
pilot ring.

**Why this — not "test more" — would have caught it:** Friday's rollout went
straight to the full-floor group with no intermediate ring. If a Pilot Ring gate
had existed, the drive-mapping script's SYSTEM-context failure (see root cause in
[KB-L2L3-Floor6-Login-Issues-20260814.md](KB-L2L3-Floor6-Login-Issues-20260814.md))
would have surfaced against 10 pilot devices on Friday afternoon — generating the
same Event ID 98 / IME log error, but affecting a handful of test devices instead of
a dozen+ production users on Monday morning. The second-approver toggle makes this
a structural blocker, not a reminder or checklist item someone can skip under
deadline pressure.

(Root cause reference: [KB-L2L3-Floor6-Login-Issues-20260814.md](KB-L2L3-Floor6-Login-Issues-20260814.md))

---

## The Required Reflection — where my first instinct was wrong

**Initial instinct:** When reviewing the AI-generated evidence-collection script
(`Script-AI generated-Evidence-Collection-DriveMapping.ps1`), my first read treated
`[CmdletBinding(SupportsShouldProcess = $true)]` as sufficient evidence that
`-WhatIf`/`-Confirm` already worked. The declaration is the standard PowerShell
signal for "this cmdlet supports ShouldProcess," so I initially assumed the
safety behavior was already in place because the switch was *declared*, and moved on
to reviewing other requirements (logging, idempotency, rollback) instead of tracing
each action block.

**What the evidence showed instead:** Reading through every mutating action line by
line (`New-Item`, `Copy-Item`, `Remove-Item`, the `gpresult`/`Export-Csv` writes), I
found `$PSCmdlet.ShouldProcess()` was **never actually called anywhere** — only the
custom `-DryRun` switch gated any action. That meant `-WhatIf` alone would have
silently let every real copy and delete execute. The declaration was cosmetic; the
implementation was missing entirely.

**What changed my mind:** The absence of any `ShouldProcess(...)` call in the code
itself — not an assumption, but a direct read of the script's logic — is what
corrected the initial instinct. This is documented in full, before/after, in
[Script-AI generated-Evidence-Collection-DriveMapping-AI-vs-Corrected.md](Script-AI%20generated-Evidence-Collection-DriveMapping-AI-vs-Corrected.md),
which shows the original AI draft (declaration only, no calls) next to the
hand-corrected version (real `ShouldProcess` checks wired into every action) with a
one-line reason for each fix.

---

## Non-Negotiables — how each was satisfied, with reasoning

**1. The Copilot incident is a security signal, not a bug.**
Reasoning: an AI assistant surfacing client-matter data to a user who has never had
permission to see it is, by definition, an access-control/data-exposure event —
the AI's output is only a symptom; the underlying fault is a permissions or indexing
boundary failure. Treating it as "AI weirdness" would have meant closing a
potential data breach without investigation. This is why it was escalated separately
in [Escalation-Copilot-Unauthorized-Access-Incident-20260814.md](Escalation-Copilot-Unauthorized-Access-Incident-20260814.md)
and explicitly kept apart from the login/drive-mapping RCA in every downstream
document (Runbook Notes section, KB-L2/L3 Related section, and the engineer-to-engineer
comms note all flag it as a separate, security-tracked issue).

**2. At least one script shown both AI-generated and hand-corrected.**
Satisfied by [Script-AI generated-Evidence-Collection-DriveMapping-AI-vs-Corrected.md](Script-AI%20generated-Evidence-Collection-DriveMapping-AI-vs-Corrected.md) —
contains the original v1 code blocks (declared-but-unused `SupportsShouldProcess`)
directly alongside the v2 corrected blocks (real `ShouldProcess` calls), with a
fixes table giving a one-line reason per change.

**3. The runbook is the single source for the L1 and L2/L3 articles.**
Reasoning for why this holds, not just an assertion: both KB articles re-express the
same runbook facts at different depths rather than introducing new ones —
- [KB-L1-Floor6-Login-Issues-20260814.md](KB-L1-Floor6-Login-Issues-20260814.md)
  re-expresses only the Runbook's user-safe actions (sign out/in once, don't
  self-repair, contact desk) and its Notes-section warning about unusual
  on-screen data — with no event IDs, portal paths, or scripts, because those
  aren't user-actionable facts.
- [KB-L2L3-Floor6-Login-Issues-20260814.md](KB-L2L3-Floor6-Login-Issues-20260814.md)
  re-expresses the same Runbook Procedure/Verification/Rollback steps, adding only
  the technical layer the Runbook already implied but didn't spell out in portal
  terms (exact Event IDs 1500/98, exact Intune blade paths, exact log file path) —
  it does not introduce a different root cause, different fix, or different
  verification criteria than the Runbook.
Both trace back to the same four facts established in the Runbook: cause (drive-mapping
script + Friday deployment), fix (remove from deployment ring), verification (logon
time + mapped drive present), and the Copilot issue being out of scope.

**4. The partner-facing note is genuinely readable by a non-technical audience.**
Satisfied by the Audience 1 (executive) version in
[Comms-Floor6-Login-Issues-Multi-Audience-20260814.md](Comms-Floor6-Login-Issues-Multi-Audience-20260814.md) —
65 words, zero technical terms (no "script," "SYSTEM context," "Event ID," or
"Intune"), leads with the reassurance ("your access and data remain fully secure"),
and ends with the only action required of that audience (none, right now).
