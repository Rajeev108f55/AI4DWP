# Triage Summary — T-1008: VPN Connects but No Internal Resources Reachable After Win11 Upgrade

## Summary
VPN connects successfully but internal resources are not reachable following a Windows 11 upgrade.

## Impact
- **Who:** Single end user reporting (name/ID — to-verify).
- **How many affected:** 1; whether other users upgraded around the same time are also affected — to-verify.
- **Business urgency:** to-verify — no role/criticality stated; being unable to reach internal resources while remote can block most work, so urgency should be confirmed with the user/manager.

## Known Facts
- Device was upgraded to Windows 11.
- VPN connection itself establishes successfully (shows connected).
- Internal resources are not reachable once connected.
- Ticket reference: T-1008.

## Missing Information to Gather
- User's name, ID, and contact details (to-verify).
- Device hostname/asset tag (to-verify).
- Whether this was an in-place upgrade or new/reimaged device (to-verify).
- Which internal resources are unreachable — specific servers, shared drives, intranet sites, internal apps (to-verify).
- Whether the issue affects all internal resources or only some (to-verify).
- Exact behaviour when trying to reach resources — timeout, "cannot find" message, access denied (verbatim text, no codes assumed) (to-verify).
- VPN client/software in use and version (to-verify).
- Whether the user can ping or resolve internal hostnames/IPs while connected (to-verify).
- Network location — home, office, public Wi-Fi — at time of connection (to-verify).
- Whether split-tunnel or full-tunnel VPN routing is configured, and whether this changed post-upgrade (to-verify).
- Whether firewall, antivirus, or network adapter settings changed as part of the Win11 upgrade (to-verify).
- Whether a reboot/VPN reconnect has been tried since the issue started, and result (to-verify).
- Whether other users on the same VPN profile/upgrade wave report the same issue (to-verify).

## Likely Category
Network/VPN connectivity — possible routing, DNS resolution, or network adapter/driver issue introduced by the Win11 upgrade. Category to confirm once more detail is gathered.

## Suggested First Diagnostic Step
Ask the user to attempt to ping or resolve a known internal hostname/IP while connected to VPN, to determine whether the issue is DNS resolution, routing, or a broader connectivity fault — this helps distinguish a VPN routing/config issue from a local network adapter/driver problem introduced by the upgrade.
