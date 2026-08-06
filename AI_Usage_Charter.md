# Personal AI Usage Charter — DWP Engineer (Desktop/Endpoint)

**Purpose:** Personal rules for using public AI assistants (e.g. ChatGPT, Copilot, Gemini) safely and productively in day-to-day DWP endpoint/desktop engineering work. Review and re-sign quarterly.

## 1. Tasks OK to use public AI assistants for
- Generic scripting help: PowerShell/batch syntax, regex, JSON/CSV parsing logic, using *sanitised or synthetic* sample data.
- Explaining error messages, log formats, or vendor documentation (Microsoft, Intune, SCCM, etc.) using generic/public text only.
- Drafting generic runbook/SOP templates, comment blocks, or documentation structure (no live hostnames, IPs, ticket numbers).
- Learning/explaining concepts: GPO behaviour, imaging processes, driver/patch mechanics, general troubleshooting methodology.
- Boilerplate code: reusable functions, formatting output, building test harnesses with dummy data.
- Drafting non-sensitive comms (e.g. generic user-facing "how to" wording) with no case-specific detail.

## 2. Tasks NOT appropriate for public AI assistants
- Anything containing real citizen/claimant data: names, NI numbers, DOB, addresses, benefit details, case references.
- Real DWP hostnames, IP ranges, server names, internal URLs, ticket/incident numbers, or architecture diagrams.
- Credentials, tokens, API keys, hashes, certificates, or connection strings — real or masked-but-recognisable.
- Pasting actual error logs, config exports, or screenshots that may contain user or system-identifiable data.
- Security-sensitive config (firewall rules, AV/EDR exclusions, vulnerability details) tied to live DWP systems.
- Anything classified OFFICIAL-SENSITIVE or above, or that policy/line manager has flagged as restricted.
- **Rule of thumb:** if you wouldn't paste it into a public forum post, don't paste it into a public AI tool.

## 3. Data-handling rule — end-user PII and credentials
- **Strip before you share.** Before pasting anything into a public AI tool: remove/replace all PII (names → "User A", NI numbers → "XX 12 34 56 X", hostnames → "HOST01"), and remove all secrets (passwords, keys, tokens) entirely — never mask-and-keep-partial.
- **Never paste raw exports.** Recreate the *shape* of the problem with fabricated data instead of copying real logs/tickets/screenshots verbatim.
- **No credential entry, ever.** Never type or paste a real password/token/key into a prompt, even "to test" — assume it is logged and unrecoverable.
- **If in doubt, don't send.** If you're unsure whether something counts as PII, treat it as PII and either anonymise fully or don't ask the AI.
- **Approved channel only.** Use only DWP-sanctioned AI tools/tenants where offered; treat any non-approved public tool as untrusted for anything beyond generic/synthetic input.

## 4. Personal "Generate → Verify" rule for scripts & system changes
1. **Generate** the script/command from the AI as a *draft only* — never trusted output.
2. **Read every line** before running anything. If you can't explain what a line does, don't run it.
3. **Verify against source of truth**: check against official docs/vendor reference or a colleague, not the AI's explanation alone.
4. **Test in isolation first**: run in a sandbox/test VM or `-WhatIf`/dry-run mode before touching a live endpoint or production system.
5. **No blind elevation**: never run AI-generated code with admin/SYSTEM rights without step 2–4 complete.
6. **Change control still applies**: AI-assisted scripts follow the same approval/CAB process as any other change — AI authorship doesn't fast-track it.
7. **Log the source**: note in change/ticket records that a script was AI-drafted and human-verified, for audit traceability.

---
**Signed:** ______________________  **Date:** ______________________
**Review due:** every 3 months, or immediately after any DWP AI policy update.
