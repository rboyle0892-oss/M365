# Import + Test Checklist (Readiness Request Generator)

## Import
1. Import the unmanaged solution into target environment.
2. Open connection references and rebind:
   - Dataverse
   - Office 365 Outlook
3. Open flow **BCR Readiness Request Generator** and confirm:
   - table names: `bcr_budgetlines`, `bcr_readinessrequests`
   - duplicate-check filter compares lookup GUID using `_bcr_budget_value`
4. Set `varOrgUrl` in flow to your environment URL (or replace with environment variable action).
5. Turn flow ON.

## Test data setup
1. Create 1–2 Budget rows with:
   - `statecode = Active`
   - `statuscode = Active`
   - `bcr_enddate` within next 30 days
   - `bcr_smeemail` populated
2. Ensure there are no open readiness requests for those budgets.

## Run test
1. Trigger flow manually (or wait recurrence).
2. Validate each qualifying budget creates exactly one Readiness Request row.
3. Validate email received by SME with working record link.
4. Click link and confirm it opens the created `bcr_readinessrequest` record directly.

## Duplicate protection test
1. Run flow a second time with unchanged source budget rows.
2. Confirm no additional readiness request is created for budgets already having active request rows.
