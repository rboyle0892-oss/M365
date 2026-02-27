# ALM Deployment Guide - Budget Commercial Readiness MVP

## Target operating model
The deployment target is a repeatable ALM process:
1. Build and validate the MVP solution in **Dev** once.
2. Export the solution from Dev.
3. Commit the unpacked solution + pipeline assets to source control.
4. Use `pac` + Azure DevOps pipeline to import into downstream environments with minimal manual work.

This approach keeps Dataverse schema, flows, app artifacts, environment variables, and connection references deployment-safe and reproducible.

---

## Repository ALM assets
- `alm/azure-pipelines.yml` - CI/CD pipeline for validation + deployment.
- `alm/scripts/whoami.ps1` - validates CLI auth and environment context.
- `alm/scripts/export-solution.ps1` - exports unmanaged solution from source environment.
- `alm/scripts/import-solution.ps1` - imports unmanaged solution into target environment.
- `alm/scripts/set-env-vars.ps1` - updates Dataverse environment variable values post-import.
- `alm/solution/README.md` - unpacked solution layout and first-time setup instructions.

---

## Prerequisites

## 1) Workstation / agent prerequisites
1. Install Power Platform CLI (`pac`) on your build agents.
   - Windows (winget):
     ```powershell
     winget install Microsoft.PowerPlatformCLI
     ```
   - Verify:
     ```powershell
     pac --version
     ```
2. Install PowerShell 7+ on self-hosted agents if not already installed.
3. Confirm agent can reach `make.powerapps.com` and Dataverse URLs.

## 2) Azure DevOps service connection
1. In Azure DevOps project, create a service principal (or use existing) with access to target tenant.
2. Grant app user permissions in each Dataverse environment:
   - Environment Maker (minimum for solution import + environment variable updates)
   - System Administrator if your org policy requires full privilege during bootstrap
3. Create Azure DevOps service connection (recommended: Workload Identity Federation or service principal secret/cert).
4. Store credentials as secret variables in variable group if using non-federated auth:
   - `PP_TENANT_ID`
   - `PP_CLIENT_ID`
   - `PP_CLIENT_SECRET` (secret)

## 3) Environment variables and connection references
1. In Dev solution, convert configurable values to Dataverse Environment Variables, e.g.:
   - `bcr_AppBaseUrl`
   - `bcr_ProcurementNotificationMailbox`
   - `bcr_DefaultReminderCadenceDays`
2. Ensure each flow uses environment variables (not hardcoded endpoints/emails).
3. Ensure all flows use connection references within solution.
4. Capture environment-specific overrides in Azure DevOps variables:
   - `TARGET_ENV_URL` (e.g., `https://org-test.crm.dynamics.com`)
   - `BCR_APP_BASE_URL`
   - `BCR_PROCUREMENT_MAILBOX`
   - `BCR_REMINDER_CADENCE`

---

## First-time bootstrap (Dev)
1. Build tables/flows/app in Dev under a single solution (e.g., `bcr_mvp`).
2. Publish all customizations.
3. Run manual smoke tests for activation -> submit -> approval loop.
4. Export unmanaged solution using:
   ```powershell
   pwsh ./alm/scripts/export-solution.ps1 \
     -EnvironmentUrl "https://org-dev.crm.dynamics.com" \
     -SolutionName "bcr_mvp" \
     -OutputZip "./alm/solution/bcr_mvp_unmanaged.zip" \
     -TenantId $env:PP_TENANT_ID \
     -ClientId $env:PP_CLIENT_ID \
     -ClientSecret $env:PP_CLIENT_SECRET
   ```
5. Unpack and commit (see `alm/solution/README.md`).

---

## Repeatable deployment flow
1. Trigger pipeline with solution zip artifact (or from committed unpacked+repacked process).
2. Validation stage:
   - authenticate
   - verify environment context (`whoami`)
   - ensure solution artifact exists
3. Deployment stage:
   - import unmanaged solution
   - apply environment variable values
   - publish customizations
4. Optional post-deployment: run smoke-test checklist from docs.

---

## Typical commands (manual fallback)

### Validate identity and environment
```powershell
pwsh ./alm/scripts/whoami.ps1 \
  -EnvironmentUrl "https://org-test.crm.dynamics.com" \
  -TenantId $env:PP_TENANT_ID \
  -ClientId $env:PP_CLIENT_ID \
  -ClientSecret $env:PP_CLIENT_SECRET
```

### Import unmanaged solution
```powershell
pwsh ./alm/scripts/import-solution.ps1 \
  -EnvironmentUrl "https://org-test.crm.dynamics.com" \
  -SolutionZip "./drop/bcr_mvp_unmanaged.zip" \
  -PublishWorkflows \
  -TenantId $env:PP_TENANT_ID \
  -ClientId $env:PP_CLIENT_ID \
  -ClientSecret $env:PP_CLIENT_SECRET
```

### Set environment variables post import
```powershell
pwsh ./alm/scripts/set-env-vars.ps1 \
  -EnvironmentUrl "https://org-test.crm.dynamics.com" \
  -ValuesJsonPath "./alm/scripts/env-values.test.json" \
  -TenantId $env:PP_TENANT_ID \
  -ClientId $env:PP_CLIENT_ID \
  -ClientSecret $env:PP_CLIENT_SECRET
```

---

## Governance notes
- Keep solution unmanaged in Dev only.
- Use managed imports for production release train (future hardening phase).
- Store all secrets in Azure DevOps secret variables or Key Vault-backed variable groups.
- Never hardcode approver emails, URLs, or mailbox addresses in flow definitions.
