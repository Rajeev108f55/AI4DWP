# Azure Virtual Desktop Provisioning Runbook (POOL-FIN-01)

Date: 2026-08-13  
Engineer workflow: Azure CLI + PowerShell (executed from local terminal)

## Scope
This runbook documents the end-to-end Azure Virtual Desktop provisioning that was executed for the Windows 11 workplace migration project.

Environment:
- Subscription: `8d8da22c-cbf0-4314-bc16-246725646a4f`
- Resource group: `dwp-lab-rg`
- Region: `centralus`
- Tenant domain: `zippyops.in`
- Target AVD user: `p17@zippyops.in`

## What Was Provisioned
1. Pooled host pool: `POOL-FIN-01`
   - Load balancing: `BreadthFirst`
   - Max sessions per host: `5`
2. Desktop application group: `DAG-POOL-FIN-01`
3. Workspace: `FinBridge-Workspace`
4. Session host VM: `vm-fin-avd-01`
   - Image: Windows 11 multi-session AVD-optimized
   - SKU: `Standard_B2ms`
   - Security: `TrustedLaunch`, `Secure Boot`, `vTPM`
   - Join mode: Microsoft Entra ID joined only
5. Access roles for `p17@zippyops.in`
   - `Virtual Machine User Login` on the VM scope
   - `Desktop Virtualization User` on the desktop app group scope

## Scripts Added In Day 9
- `01-Provision-AVD-Core.ps1`
- `02-Register-SessionHost.ps1`
- `03-Assign-User-Access.ps1`
- `04-Verify-AVD-Deployment.ps1`

Run in order from the Day 9 folder.

## Important Troubleshooting Notes Captured From Execution
- Legacy package URL attempts returned `404` for one bootloader endpoint, so the registration step used current Microsoft fwlink endpoints:
  - Agent: `https://go.microsoft.com/fwlink/?linkid=2310011`
  - Bootloader: `https://go.microsoft.com/fwlink/?linkid=2311028`
- Session host status was validated via ARM REST endpoint to confirm actual host status:
  - `.../hostPools/POOL-FIN-01/sessionHosts?api-version=2024-04-03`

## No File Move Needed
No prior step files existed outside Day 9 in this workspace for this provisioning flow, so no move operation was required.

## Quick Execution
```powershell
# From TRAINING\Day 9
.\01-Provision-AVD-Core.ps1
.\02-Register-SessionHost.ps1
.\03-Assign-User-Access.ps1
.\04-Verify-AVD-Deployment.ps1
```

## Expected Final State
- `POOL-FIN-01/vm-fin-avd-01` appears in session hosts
- Session host status is `Available`
- `AzureAdJoined : YES`, `DomainJoined : NO`
- `p17@zippyops.in` can sign in through AVD client and has direct VM login permission
