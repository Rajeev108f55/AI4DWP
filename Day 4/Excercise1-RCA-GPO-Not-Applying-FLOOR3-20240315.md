# Root Cause Analysis — Group Policy Not Applying on Floor 3
## DESKTOP-FB031 and related Floor 3 workstations | 2024-03-15

**Document prepared by:** DWP Engineer
**Date prepared:** 2026-08-06
**Incident date:** 2024-03-15
**Incident window:** 07:40 – 10:00
**Resolution confirmed:** 10:00
**Severity:** Medium — three users/workstations could not receive updated Group Policy until remediation was applied
**Status:** RESOLVED

---

## 1. Incident Summary

On 2024-03-15, three Windows 11 workstations on Floor 3 were unable to apply updated Domain Group Policy. Affected users reported missing mapped drives and desktop shortcuts, along with company settings not updating after startup. Restarting the devices did not resolve the issue.

The issue was isolated to Floor 3 devices. Other users on the same floor were unaffected, and DC01 itself was confirmed healthy. The incident was resolved after the Floor 3 DHCP scope was corrected so clients received the current DNS server instead of the decommissioned DNS server. Once leases were renewed and DNS connectivity was restored, users were able to log in to Floor 3 devices and no further issues were reported at 10:00.

---

## 2. Affected Systems and Users

| Item | Detail |
|---|---|
| Affected systems | Three Windows 11 workstations on Floor 3, including DESKTOP-FB031 |
| Affected users | Three users on Floor 3 |
| Scope | Floor 3 subnet only |
| Other users affected | None |
| Business impact | Group Policy settings did not apply, causing missing mapped drives, missing desktop shortcuts, and stale workstation configuration |
| Resolution time | 10:00 AM after DHCP/DNS remediation and lease renewal |

---

## 3. Timeline of Events

| Time | Event |
|---|---|
| **07:40:02** | Network Location Awareness service enters running state on DESKTOP-FB031 |
| **07:40:08** | Netlogon Event 5719 records failure to set up a secure channel to domain FINBRIDGE because no domain controller is available; DNS query for `FINBRIDGE-DC01.finbridge.local` returns no response |
| **07:40:09** | GroupPolicy Event 1058 reports failure to access `\\FINBRIDGE-DC01\\sysvol\\finbridge.local\\Policies\\{3A1B2C4D-E5F6-7890-ABCD-EF1234567890}\\gpt.ini` |
| **07:40:10** | GroupPolicy Event 1030 warns that the client cannot query the list of Group Policy objects |
| **07:40:11** | GroupPolicy Event 1058 repeats the same SYSVOL access failure |
| **07:40:12** | GroupPolicy Event 1129 states that Group Policy failed because there is no network connectivity to a domain controller |
| **07:41:05** | DNS Client Event 1014 reports name resolution timeout for `FINBRIDGE-DC01.finbridge.local`; none of the configured DNS servers respond |
| **07:42:18** | DHCP Client Event 50036 shows DESKTOP-FB031 receives IP 10.10.3.144 and DNS server 10.10.3.250, which is the old decommissioned DNS server |
| **07:44:01** | GroupPolicy Event 1129 repeats; the client still cannot reach a domain controller |
| **Morning triage** | Floor 3 scope is identified as using the stale DNS server via DHCP, while unaffected devices use the correct DNS server 10.10.0.10 |
| **Remediation applied** | DHCP scope is updated to hand out 10.10.0.10 instead of 10.10.3.250; affected clients renew leases and refresh DNS/GPO |
| **10:00** | Users confirm they can log in to Floor 3 devices and no further Group Policy issues are reported |

---

## 4. Supporting Evidence

### 4.1 Affected Host Event Log — DESKTOP-FB031

| Time | Event ID | Level | Detail |
|---|---|---|---|
| 07:40:08 | 5719 | Error | Netlogon cannot establish a secure channel; no domain controller available. DNS for `FINBRIDGE-DC01.finbridge.local` returned no response. |
| 07:40:09 | 1058 | Error | Group Policy cannot access `\\FINBRIDGE-DC01\\sysvol\\finbridge.local\\Policies\\{3A1B2C4D-E5F6-7890-ABCD-EF1234567890}\\gpt.ini`. Error code 0x3. |
| 07:40:10 | 1030 | Warning | Cannot query list of Group Policy objects. Error code 0x546. |
| 07:40:11 | 1058 | Error | Group Policy processing failed again; same SYSVOL path failure. |
| 07:40:12 | 1129 | Error | Group Policy failed because there is no network connectivity to a domain controller. |
| 07:41:05 | 1014 | Warning | Name resolution for `FINBRIDGE-DC01.finbridge.local` timed out. None of the configured DNS servers responded. |
| 07:42:18 | 50036 | Information | DHCP lease issued; DNS server assigned by DHCP was 10.10.3.250, the old decommissioned DNS server. |
| 07:44:01 | 1129 | Error | Group Policy processing failed again; no DC connectivity. |

### 4.2 Comparison Host — DESKTOP-FB029 (Unaffected)

| Time | Event ID | Level | Detail |
|---|---|---|---|
| 07:40:05 | 50036 | Information | DHCP lease issued; DNS server assigned was 10.10.0.10, the correct DNS server |
| 07:40:11 | 1500 | Information | Group Policy settings processed successfully |

### 4.3 DHCP Comparison Evidence

| Scope / Host | DNS Assigned | Notes |
|---|---|---|
| Floor 3 affected hosts FB055-057 | 172.16.5.5 | Floor 3 local DNS, decommissioned 2024-03-14 overnight |
| FB058 | 10.10.0.10 | Central DNS, manually set before migration |
| Floor 3 DHCP scope | 10.10.3.250 | Old DNS server, not updated after migration |

### 4.4 Key Evidence Notes

- **Event 5719 at 07:40:08** shows the client could not establish a secure channel because it could not reach a domain controller.
- **Event 1058 at 07:40:09** shows the specific failure occurred while trying to read SYSVOL policy data from `gpt.ini`.
- **Event 1014 at 07:41:05** confirms the immediate issue was DNS name resolution failure for the domain controller.
- **Event 50036 at 07:42:18** provides the decisive root-cause clue: DHCP handed out the decommissioned DNS server, which blocked resolution of the domain controller and SYSVOL.
- **The unaffected comparison machine DESKTOP-FB029** confirms that when the correct DNS server is assigned, Group Policy processes successfully on the same floor.

---

## 5. Root Cause

The Floor 3 DHCP scope still advertised the decommissioned DNS server 10.10.3.250. Affected workstations received that stale DNS configuration at boot, which prevented them from resolving and reaching FINBRIDGE-DC01 and its SYSVOL path. Because Group Policy depends on DNS resolution to contact a domain controller and read policy data from SYSVOL, the clients failed with Event 5719, 1058, 1030, and 1129 until the DHCP scope was corrected and leases were renewed.

---

## 6. Five Whys Analysis

| # | Why? | Answer |
|---|---|---|
| 1 | Why were Group Policy settings not applying on Floor 3 workstations? | The clients could not reach a domain controller or access SYSVOL, so policy processing failed. |
| 2 | Why could they not reach a domain controller or SYSVOL? | DNS name resolution for `FINBRIDGE-DC01.finbridge.local` timed out, so the clients could not locate the DC. |
| 3 | Why did DNS name resolution fail? | DHCP assigned the decommissioned DNS server 10.10.3.250 instead of the current DNS server 10.10.0.10. |
| 4 | Why were affected clients still receiving the old DNS server? | The Floor 3 DHCP scope was not updated after the DNS migration and still contained the stale option. |
| 5 | Why was the stale DHCP option not caught before users were impacted? | There was no post-migration validation step to verify DHCP scope options against the new DNS design, and no alerting for clients receiving a decommissioned DNS server. |

**Root cause of the process gap:** The network migration changed the DNS infrastructure, but the Floor 3 DHCP scope was not updated or validated, allowing stale DNS configuration to persist and break domain connectivity for only the affected subnet.

---

## 7. Immediate Actions Taken

| Action | Time | Outcome |
|---|---|---|
| Identified stale DNS assignment in Floor 3 DHCP scope | Morning triage | Confirmed cause of DNS failure |
| Updated DHCP scope to advertise 10.10.0.10 | Remediation window | New clients receive correct DNS |
| Renewed affected client leases | During remediation | Clients picked up corrected DNS settings |
| Forced DNS refresh and Group Policy refresh on affected devices | During remediation | Clients regained DC connectivity and policy processing |
| Verified logon success at Floor 3 | 10:00 | Issue confirmed resolved |

---

## 8. Preventive Actions

| # | Action | Owner | Priority |
|---|---|---|---|
| 1 | **Add DHCP scope validation after DNS changes** — require a checklist item after any DNS migration or decommissioning to confirm every subnet scope advertises only supported DNS servers. | Network / Platform team | High |
| 2 | **Review all subnet DHCP scopes for stale DNS entries** — audit every active scope for references to 10.10.3.250 or other retired DNS servers and remove them. | Network team | High |
| 3 | **Document DNS/DHCP ownership change control** — ensure future DNS server changes include a formal DHCP option update step and sign-off before closure. | Infrastructure change management | High |
| 4 | **Add client-side validation to migration checks** — on at least one host per subnet, verify DNS resolution to the domain controller and successful Group Policy processing after any DNS migration. | Platform / Service Desk | Medium |
| 5 | **Create an alert for decommissioned DNS server usage** — monitor DHCP and endpoint telemetry for any client still receiving a retired DNS address. | Monitoring / Security team | Medium |
| 6 | **Include SYSVOL reachability in Floor 3 health checks** — extend the standard post-change validation to test access to `\\FINBRIDGE-DC01\\sysvol\\finbridge.local\\Policies\\...\\gpt.ini`. | Service Desk / Platform team | Medium |

---

## 9. Lessons Learned

- **A correct DC is not enough if clients cannot resolve it.** Group Policy depends on DNS first; a healthy domain controller is unreachable if the client receives stale DNS settings.
- **DHCP scope drift can create subnet-specific failures.** Only Floor 3 was affected because only that scope still referenced the retired DNS server.
- **Event 1014 and Event 50036 were the key clues.** DNS timeout followed by DHCP assigning the old server made the failure mode clear.
- **Comparison with an unaffected machine is valuable.** DESKTOP-FB029 showed the same floor could process Group Policy successfully when it received the correct DNS server.
- **Post-migration validation must include DHCP.** Infrastructure changes are incomplete until DHCP options are checked and clients are confirmed to resolve the domain controller.
