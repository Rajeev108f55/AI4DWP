# Triage Summary — T-1002: Shared Mailbox Inaccessible After Migration

## Summary
Finance user cannot open a shared mailbox following a migration.

## Impact
- **Who:** Finance user reporting (name/ID — to-verify); other Finance staff who use the same shared mailbox — to-verify.
- **How many affected:** 1 confirmed; whether other users of the shared mailbox are also affected — to-verify.
- **Business urgency:** to-verify — no role/criticality stated; loss of access to a shared mailbox may block Finance workflows (e.g. invoicing, approvals), but this should be confirmed with the user/manager.

## Known Facts
- User is in the Finance team.
- A migration has taken place (type/scope of migration — to-verify).
- The shared mailbox cannot be opened by this user since the migration.
- Ticket reference: T-1002.

## Missing Information to Gather
- User's name, ID, and contact details (to-verify).
- Name/address of the shared mailbox in question (to-verify).
- What migration occurred — e.g. on-prem to Exchange Online, tenant-to-tenant, mailbox move between databases — and when it completed (to-verify).
- Exact behaviour when trying to open the mailbox: not listed in Outlook, permission-denied prompt, spinning/hangs, or error message (verbatim text, no codes assumed) (to-verify).
- Whether the user can access their own primary mailbox normally (to-verify).
- Whether the user's permissions/delegate access to the shared mailbox were confirmed as migrated/re-applied (to-verify).
- Whether other Finance users with access to the same shared mailbox are experiencing the same issue (to-verify).
- Which client(s) affected — Outlook desktop, Outlook Web Access (OWA), mobile — and whether tested on more than one (to-verify).
- Whether the user has tried removing and re-adding the shared mailbox, or restarting Outlook, and the result (to-verify).
- Time the issue started relative to the migration completion (to-verify).

## Likely Category
Messaging/Exchange — shared mailbox permissions or migration-related access issue. Category to confirm once more detail is gathered.

## Suggested First Diagnostic Step
Confirm whether the user can access their own primary mailbox normally, then check (with a messaging/Exchange admin) whether the user's permissions on the shared mailbox were successfully migrated/re-applied post-migration — this distinguishes a permissions/replication issue from a broader migration fault affecting multiple users.
