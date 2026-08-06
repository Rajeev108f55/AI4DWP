# Group Policy Not Applying — Incident Analysis & Hypothesis
**Analyst:** DWP Engineer
**Date:** 2026-08-06
**Incident logged:** 2024-03-15 07:18
**Reported by:** Rajeev, Service Desk (ext 4417)

---

## Incident Summary

Three Windows 11 workstations on Floor 3 are not receiving updated Domain Group Policy. Affected users report missing mapped drives and desktop shortcuts that normally deploy via GPO, and company settings are not updating. Restarting the affected PCs did not resolve the issue. Other users on the same floor are unaffected. The machines were working normally the previous day. An overnight Group Policy push update was applied to DC01, and DC01 itself is confirmed healthy — every other user is unaffected.

---

## Scope Facts

| Fact | Detail |
|---|---|
| Symptom | Domain Group Policies not applying to client devices |
| Affected pool | 3 user devices, Floor 3 |
| Unaffected pool | Other users, same floor — DC01 confirmed fine for them |
| First reported | ~09:00, 2024-03-15 |
| Scope | Persists on 3 devices only |
| Recent change | Overnight Group Policy push update on DC01 |

---

## Key Discriminating Logic

The fact that **DC01 was updated and is completely fine for every other user, with only these 3 devices affected**, is the strongest scope clue. It rules out any explanation requiring DC01 itself to be broken, since DC01 is demonstrably serving everyone else correctly. The fault must be something that isolates these 3 devices specifically — either they are not receiving DC01's (correct) content due to a propagation/path gap, or the devices themselves have a local processing problem unrelated to DC01's health.

> Logical test applied to each cause: *"If this were true, would it explain why DC01 is fine for everyone but these 3 devices are stuck, without requiring DC01 itself to be at fault?"*
> If yes → consistent. If no → weakened or eliminated.

---

## Ranked Hypotheses (Most Probable First)

### 1. SYSVOL/DFSR Replication Lag to the DC Actually Serving These 3 Machines
- **Why it fits:** GPO client-side extensions read policy content (registry.pol, scripts) from SYSVOL, not directly from DC01. If these 3 machines are served by a DC whose SYSVOL replica hasn't yet caught up with DC01's overnight push, they would keep applying the old policy indefinitely — exactly matching "persists for 3 devices."
- **Consistency with DC01-fine clue:** Strongest fit — DC01's own copy is correct and the push succeeded there; the 3 devices are simply reading a stale replica elsewhere. Fully compatible with DC01 being fine and everyone else being fine.
- **Fastest check:** `dfsrdiag replicationstate` on the DC these 3 machines log onto, and compare the `gpt.ini` version number to DC01's copy.

### 2. AD Directory-Partition Replication Lag for the GPO Object/gpLink
- **Why it fits:** Same propagation-gap logic as #1 but at the AD object level (the GPO object or its link) rather than the file level — if the DC serving these 3 machines hasn't received the replicated AD change, it may still process/apply a prior policy state.
- **Consistency with DC01-fine clue:** Consistent, but ranked slightly below #1 since GPO application depends more directly on SYSVOL file content than on AD object metadata alone.
- **Fastest check:** `repadmin /showrepl` and `repadmin /replsummary` to check for a lagging or failed inbound replication partner.

### 3. These 3 Devices Are Pinned to a Different Domain Controller (DC Locator / Site Mapping Issue)
- **Why it fits:** Explains why exactly these 3 devices — and not others on the same floor — never pick up DC01's content: they are contacting a different DC entirely, which may or may not itself be healthy.
- **Consistency with DC01-fine clue:** Still ties to the timing clue indirectly (whichever DC they use may not have replicated yet), but is one step removed from a direct replication explanation — it's about *which* DC they reach rather than replication itself.
- **Fastest check:** `nltest /dsgetdc:finbridge.local` and `echo %LOGONSERVER%` on each affected device.

### 4. Client-Side Group Policy Service / CSE Failure or Corrupted Local Policy Cache
- **Why it fits:** Would explain persistent failure to apply policy regardless of DC state; the fact that a reboot did not fix it is consistent with a corrupted cache rather than a transient service hang.
- **Consistency with DC01-fine clue:** Weaker fit — this failure mode isn't caused by or dependent on the DC01 push, so its alignment with "overnight DC01 update" is coincidental rather than causal.
- **Fastest check:** `gpresult /h report.html` on each device, and check `Microsoft-Windows-GroupPolicy/Operational` for Event ID 1006/1096.

### 5. Computer Objects Moved to a Different OU or Subject to Different Security Filtering/WMI Filter Scope
- **Why it fits:** Would isolate exactly these 3 devices from the policy while leaving the rest of the OU untouched.
- **Consistency with DC01-fine clue:** Weakest tie to the timing clue — an OU/filtering change is independent of the DC01 GPO push event, so it would need its own separate unexplained trigger at the same time, which is less parsimonious than the replication-based explanations.
- **Fastest check:** `Get-ADComputer <name> -Properties DistinguishedName` for each affected device, compared against a working machine in the same OU.

---

## Surviving Hypothesis

### Floor 3 DHCP scope still hands out the decommissioned DNS server, breaking DC/SYSVOL resolution for affected clients

## Detailed Resolution Steps

1. Update the Floor 3 DHCP scope so option 006 points to the current DNS server **10.10.0.10** instead of **10.10.3.250**.
2. Confirm the change on the DHCP server by reviewing the affected scope configuration and verifying no residual superseded DNS options remain.
3. Renew the leases on the affected Floor 3 clients so they pick up the corrected DNS setting.
4. Flush stale DNS state on each affected host and force a fresh GPO refresh.
5. Re-test SYSVOL reachability to `\\FINBRIDGE-DC01\\sysvol\\finbridge.local\\Policies\\...\\gpt.ini` from an affected machine.
6. Confirm Group Policy succeeds by checking for a successful refresh event after connectivity is restored.
7. Document the scope correction and audit other Floor 3 network scopes for the same stale DNS reference to prevent recurrence.


## Status
**Root cause: DHCP scope DNS misconfiguration on Floor 3** — the affected clients were handed the decommissioned DNS server, which prevented DC/SYSVOL name resolution and blocked Group Policy processing.

**Recommended first action:** Correct the DHCP scope DNS option, then renew the affected leases and verify GPO refresh success on one Floor 3 workstation before rolling the fix across the subnet.

---

## Addendum: Event Details, Surviving Hypothesis, and Resolution

### Event Details That Drove the Elimination
- **07:40:08, Netlogon 5719:** secure channel setup failed because no domain controller was available and DNS for `FINBRIDGE-DC01.finbridge.local` returned no response.
- **07:40:09, GroupPolicy 1058:** Group Policy could not access `\\FINBRIDGE-DC01\\sysvol\\finbridge.local\\Policies\\{3A1B2C4D-E5F6-7890-ABCD-EF1234567890}\\gpt.ini`.
- **07:40:10, GroupPolicy 1030:** the client could not query the list of Group Policy objects.
- **07:40:12, GroupPolicy 1129:** Group Policy failed because there was no network connectivity to a domain controller.
- **07:41:05, DNS Client 1014:** name resolution for `FINBRIDGE-DC01.finbridge.local` timed out and none of the configured DNS servers responded.
- **07:42:18, DHCP Client 50036:** the client received DNS server `10.10.3.250`, which was the old decommissioned DNS server instead of `10.10.0.10`.
- **07:44:01, GroupPolicy 1129:** Group Policy failed again, confirming the problem persisted after the initial startup attempt.

### Surviving Hypothesis
The surviving hypothesis is that **Floor 3 DHCP still advertised the decommissioned DNS server**, causing affected clients to lose DNS-based access to the domain controller and SYSVOL, which in turn prevented Group Policy from applying.

### Resolution Steps
1. Correct the Floor 3 DHCP scope so option 006 advertises `10.10.0.10` only.
2. Verify the DHCP scope no longer references the decommissioned DNS server.
3. Renew the DHCP lease on an affected workstation so it receives the updated DNS configuration.
4. Flush DNS cache and force a Group Policy refresh on the affected client.
5. Confirm `\\FINBRIDGE-DC01\\sysvol\\finbridge.local\\Policies\\...\\gpt.ini` is reachable from the workstation.
6. Validate that Group Policy completes successfully after connectivity is restored.
7. Check other Floor 3 scopes for the same stale DNS setting and remediate any matches.
