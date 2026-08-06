# Floor 3 Group Policy Issue — End-User Communications
**Incident:** Group Policy not applying on Floor 3 workstations
**Date:** 2024-03-15
**Resolved:** 10:00
**Related RCA:** Excercise1-RCA-GPO-Not-Applying-FLOOR3-20240315.md

---

## Audience 1 — Non-Technical Executive

**Subject: Floor 3 access issue — resolved**

Your team’s access is now restored. This morning, a Floor 3 DHCP setting gave workstations an old DNS server, which stopped them from reaching the domain controller and applying Group Policy. The issue was fixed by 10:00. If anyone still has trouble on Floor 3, please report it to the Service Desk.

---

## Audience 2 — Affected End-User Team

**Subject: Floor 3 login and policy issue this morning — fixed**

Hi team,

This morning, Floor 3 workstations were given an old DNS server by DHCP, which stopped them from reaching the domain controller and applying Group Policy. The issue was fixed by 10:00, and users were able to log in to Floor 3 devices again.

If you see the same issue again, please contact the Service Desk right away.

Thanks,
Service Desk

---

## Audience 3 — Engineer-to-Engineer Internal Note

**Subject: Floor 3 Group Policy outage resolved — DHCP DNS scope stale on client subnet**

**Root cause:**
Floor 3 clients were receiving DNS server `10.10.3.250` from DHCP, which is the decommissioned DNS server. That blocked DNS resolution to `FINBRIDGE-DC01.finbridge.local`, preventing domain controller reachability and SYSVOL access, which caused Group Policy processing failures on Floor 3 workstations.

**Exact action taken:**
The Floor 3 DHCP scope was corrected so option 006 advertised `10.10.0.10` instead of `10.10.3.250`. Affected clients then renewed their leases and refreshed DNS / Group Policy.

**Config detail:**
- Faulty DHCP DNS option on Floor 3 scope: `10.10.3.250`
- Correct DNS server: `10.10.0.10`
- Impacted path: `\\FINBRIDGE-DC01\\sysvol\\finbridge.local\\Policies\\...\\gpt.ini`
- Affected hosts: three Floor 3 Windows 11 workstations, including DESKTOP-FB031

**Verification step:**
Verify that an affected workstation can resolve and reach `FINBRIDGE-DC01.finbridge.local`, access the SYSVOL policy path, and process Group Policy successfully. The incident was confirmed resolved at 10:00 when users were able to log in to Floor 3 devices and no further issues were reported.

**Preventive action needed:**
- Audit all active DHCP scopes for stale DNS server references
- Add a post-change validation step after DNS migrations to confirm DHCP option 006 matches the current DNS design
- Include SYSVOL reachability and Group Policy processing checks in Floor 3 subnet validation after future network changes
- Monitor for clients receiving decommissioned DNS servers so stale scope configuration is detected before users are impacted
