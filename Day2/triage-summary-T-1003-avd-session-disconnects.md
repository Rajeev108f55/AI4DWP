# Triage Summary — T-1003: AVD Session Disconnects After ~10 Minutes

## Summary
Azure Virtual Desktop (AVD) session disconnects after approximately 10 minutes, then reconnects.

## Impact
- **Who:** User reporting (name/ID — to-verify); whether other AVD users are similarly affected — to-verify.
- **How many affected:** 1 confirmed; scope beyond this user — to-verify.
- **Business urgency:** to-verify — no role/criticality stated; repeated disconnects during a session can interrupt work and cause data/progress loss, but severity should be confirmed with the user/manager.

## Known Facts
- User is connecting to an AVD session.
- Session disconnects after roughly 10 minutes of use.
- Session reconnects afterward (not a permanent failure).
- Ticket reference: T-1003.

## Missing Information to Gather
- User's name, ID, and contact details (to-verify).
- Client device/OS and AVD client type used (desktop app, web client, mobile) (to-verify).
- Network connection type and location — office LAN, home Wi-Fi, VPN — at time of disconnects (to-verify).
- Exact behaviour during disconnect: black screen, "reconnecting" message, full logout, or session drops to sign-in screen (verbatim text, no codes assumed) (to-verify).
- Whether the ~10 minute timing is consistent/exact or approximate, and whether it correlates with any user action (idle time, specific app use, screen lock) (to-verify).
- Whether unsaved work/session state is lost on reconnect, or the session resumes where it left off (to-verify).
- Whether this happens on every session or intermittently, and since when (to-verify).
- Whether other users on the same AVD host pool are experiencing similar disconnects (to-verify).
- Any recent changes to network, VPN, conditional access, or idle/session timeout policies (to-verify).
- Whether the user has tried a different network or device and the result (to-verify).

## Likely Category
Virtual desktop/AVD connectivity — possible session timeout policy, network stability, or gateway/host pool issue. Category to confirm once more detail is gathered.

## Suggested First Diagnostic Step
Ask the user to note the exact time of the next disconnect and check their local network stability (e.g. wired vs Wi-Fi, VPN status) during that window, while a colleague/admin checks whether other users on the same host pool are experiencing disconnects at similar intervals — this helps distinguish a client-side network issue from a host pool/session policy issue.
