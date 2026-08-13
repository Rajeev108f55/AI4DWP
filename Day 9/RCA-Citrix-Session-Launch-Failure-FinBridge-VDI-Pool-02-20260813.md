# RCA - Citrix Session Launch Failure (FinBridge-VDI-Pool-02)

Date: 2026-08-13  
Incident Type: VDI session launch failure  
Impacted Service: Citrix desktop launch on FinBridge-VDI-Pool-02

## 1. Executive Summary
A significant launch failure occurred for users on FinBridge-VDI-Pool-02. Evidence shows widespread VDA unregistration in Pool-02 and failed communication to dc-vdi-02 controller endpoint, while dc-vdi-02 Broker Service was stopped and pending reboot remained after updates. Pool-01 stayed largely healthy with dc-vdi-01 Broker Service running.

## 2. Impact Summary
- Affected users: 22 of 30 (Pool-02)
- Unaffected pool: FinBridge-VDI-Pool-01
- Symptom: Session launch failure with broker timeout and no available machines

## 3. Supporting Evidence

### 3.1 Broker Log Evidence
- Timeout waiting for machine registration response (30000ms exceeded)
- Session launch FAILED: error 1030
- Error text: "No machines available in the desktop group"

### 3.2 Catalog Registration Evidence
- Pool-02 catalog:
  - Provisioned: 25
  - Registered: 3
  - Unregistered: 22
  - Maintenance mode: 0
- Pool-01 catalog:
  - Provisioned: 20
  - Registered: 19
  - Unregistered: 1

### 3.3 Unregistered Machine Detail (Pool-02 sample)
- VDI-P02-014 and VDI-P02-017 registration attempts failed
- Error: Unable to contact Delivery Controller
- Endpoint: dc-vdi-02.finbridge.local:80 - connection refused

### 3.4 Controller Health Evidence
- dc-vdi-02:
  - Citrix Broker Service: STOPPED
  - Last known running: yesterday 23:40
  - Update installed: today 00:15
  - Reboot required flag: set
  - Host rebooted: no
- dc-vdi-01:
  - Citrix Broker Service: RUNNING
  - Uptime: 14 days

## 4. Timeline (from supplied data)
- 00:15 (today): Windows Update installed on dc-vdi-02; reboot required flag set.
- 23:40 (yesterday): Last known running time for Citrix Broker Service on dc-vdi-02.
- 06:15:22 / 06:16:01: Sample Pool-02 VDA registration attempts fail to dc-vdi-02:80 (connection refused).
- 08:58:03: Session launch requested for Pool-02 user.
- 08:58:04: Broker queries available machines in Pool-02.
- 08:58:34: Broker timeout waiting for machine registration (30000ms exceeded).
- 08:58:34: Session launch fails with error 1030 and no machines available in desktop group.

## 5. 5-Why Analysis
1. Why did user sessions fail in Pool-02?
- Because broker could not find available machines for launch.

2. Why were no machines available?
- Because most Pool-02 machines were unregistered (22/25).

3. Why were machines unregistered?
- Because VDA registration attempts to controller endpoint failed (connection refused to dc-vdi-02:80).

4. Why was controller endpoint refusing connections?
- Because Citrix Broker Service on dc-vdi-02 was stopped.

5. Why was Broker Service stopped and not recovered?
- Controller had update activity with reboot-required state not completed, and no enforced post-update reboot/service validation guardrail was evident.

## 6. Final Hypothesis (Chosen)
**Primary cause hypothesis:** Citrix Broker Service outage on dc-vdi-02, with pending post-update reboot state contributing to sustained controller-side registration failure for Pool-02 VDAs.

## 7. Remediation Steps (Exact)
1. Notify stakeholders and open change window for controller remediation.
2. On dc-vdi-02, capture pre-change diagnostics:
   - Broker service status
   - Listener/port reachability
   - Relevant service and system event logs
3. Start Citrix Broker Service on dc-vdi-02.
4. Validate immediate VDA registration recovery trend from Pool-02.
5. Reboot dc-vdi-02 in controlled window to complete update lifecycle.
6. After reboot, verify:
   - Broker Service running and automatic
   - Controller endpoint reachable by Pool-02 VDAs
7. Validate Pool-02 session launch functionality with impacted test users.
8. Maintain enhanced monitoring window and confirm no recurrence.

## 8. Correct Order of Operations
1. Immediate restore action: start Broker Service.
2. Short validation: check registration and launch recovery.
3. Durable stabilization: reboot controller for pending update completion.
4. Post-reboot validation: service + registration + launch tests.
5. Closeout: evidence capture and preventive actions rollout.

## 9. Verification After Fix
- Technical checks:
  - dc-vdi-02 Broker Service status = RUNNING
  - dc-vdi-02 endpoint reachable from Pool-02 VDAs
- Platform checks:
  - Pool-02 registered machine count returns to expected healthy level
  - No fresh registration-timeout broker events for validation window
  - No new launch failures with error 1030 for Pool-02 during validation
- User checks:
  - Representative affected users can launch sessions successfully

## 10. Preventive Actions
1. Enforce controller patch runbook with mandatory reboot completion.
2. Add automated post-patch health gate:
   - Broker Service status
   - Controller endpoint reachability
   - Registration ratio threshold
3. Add proactive alerting:
   - Broker Service stopped
   - abrupt pool registration drop
4. Stagger controller maintenance schedules.
5. Run periodic failover/registration drills across pools/controllers.

## 11. Error Code Handling Statement
- Incident log directly states `error 1030` with message `No machines available in the desktop group`.
- No additional global interpretation has been assumed beyond supplied evidence.
