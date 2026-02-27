# Bootstrap Runbook: MVP Deployment (Fresh Power Platform Dev Environment)

This is a click-by-click guide to stand up the **minimum working MVP** in a fresh Power Platform developer environment using **Dataverse as system of record**.

MVP scope in this runbook is intentionally limited to the core loop:
1. Activate budget line
2. SME completes/submits readiness task
3. Pillar Lead approves/rejects
4. Approved line becomes Commercial Discussion Ready

Included tables for MVP only:
- BudgetLine
- ReadinessTask
- ApprovalHistory
- EventLog
- Rules

---

## 0) Prerequisites

1. Sign in to [https://make.powerapps.com](https://make.powerapps.com).
2. Switch to your fresh **Developer** environment (top-right environment picker).
3. Confirm Dataverse is available (Data -> Tables should open).
4. Confirm connectors are available:
   - Microsoft Dataverse
   - Approvals
   - Office 365 Outlook (or Teams)
   - Office 365 Users
5. Create one mailbox/security group for procurement notifications (optional MVP shortcut).

---

## 1) Create a Solution First (Recommended)

1. In left nav, go to **Solutions**.
2. Click **+ New solution**.
3. Display name: `Budget Commercial Readiness MVP`.
4. Name: `bcr_mvp`.
5. Publisher: create/select one with prefix `bcr`.
6. Version: `1.0.0.0`.
7. Click **Create**.
8. Open the solution and keep all assets inside it.

---

## 2) Dataverse Table Build Order and Exact Definitions

Create tables in this order to avoid relationship issues:
1. Rules
2. BudgetLine
3. ReadinessTask
4. ApprovalHistory
5. EventLog

> In each table creation dialog: **Data -> Tables -> + New table** (inside solution preferred).

## 2.1 Rules table
- **Display name**: Rules
- **Plural**: Rules
- **Primary name column**: Rule Name (`bcr_rulename`), Text, Required
- **Ownership**: Organization

### Columns
1. `bcr_pillar` (Pillar) - Choice - Required
2. `bcr_pillarlead` (Pillar Lead) - Lookup -> User - Required
3. `bcr_sme_default_due_days` (SME Default Due Days) - Whole number - Required - Default `10`
4. `bcr_approval_due_days` (Approval Due Days) - Whole number - Required - Default `3`
5. `bcr_reminder_cadence_days` (Reminder Cadence Days) - Whole number - Required - Default `2`
6. `bcr_max_chase_count` (Max Chase Count) - Whole number - Required - Default `5`
7. `bcr_escalation_to` (Escalation To) - Lookup -> User - Optional (MVP optional)
8. `bcr_escalation_after_days_overdue` (Escalation After Days Overdue) - Whole number - Optional - Default `3`

### Pillar choice values (global or local choice)
- 100000000 = Security
- 100000001 = Infrastructure
- 100000002 = Workplace
- 100000003 = Data
- 100000004 = BusinessApps
- 100000005 = Other

### Keys
- Alternate key: `bcr_pillar`

---

## 2.2 BudgetLine table
- **Display name**: Budget Line
- **Plural**: Budget Lines
- **Primary name column**: Budget Line Key (`bcr_budgetlinekey`) Text Required
- **Ownership**: User/Team

### Columns (MVP exact)
1. `bcr_budgetlinekey` - Text - Required (Unique stable key from Excel)
2. `bcr_fiscalyear` - Whole number - Required
3. `bcr_costcenter` - Text - Required
4. `bcr_budgetcode` - Text - Required
5. `bcr_pillar` - Choice - Required (same option set as Rules)
6. `bcr_owner` - Lookup -> User - Required
7. `bcr_estimatedvalue` - Currency - Required
8. `transactioncurrencyid` - Currency lookup - Required
9. `bcr_derivedstage` - Choice - Required - Default `Loaded`
10. `bcr_last_event_type` - Choice - Optional
11. `bcr_last_event_at` - Date and time - Optional
12. `bcr_commercialreadyat` - Date and time - Optional

### Derived Stage choice values
- 100000000 = Loaded
- 100000001 = ReadinessRequested
- 100000002 = ReadinessInProgress
- 100000003 = AwaitingPillarValidation
- 100000004 = ReadinessReworkRequired
- 100000005 = CommercialDiscussionReady

### Last Event Type choice values
- 100000000 = Activated
- 100000001 = SMERequested
- 100000002 = SMEInProgress
- 100000003 = SMESubmitted
- 100000004 = AwaitingPillarValidation
- 100000005 = PillarValidated
- 100000006 = PillarRejected

### Keys
- Alternate key: `bcr_budgetlinekey`

---

## 2.3 ReadinessTask table
- **Display name**: Readiness Task
- **Plural**: Readiness Tasks
- **Primary name column**: Task Title (`bcr_tasktitle`) Text Required
- **Ownership**: User/Team

### Columns (MVP exact)
1. `bcr_tasktitle` - Text - Required
2. `bcr_budgetline` - Lookup -> Budget Line - Required
3. `bcr_assignedto` - Lookup -> User - Required
4. `bcr_pillarlead` - Lookup -> User - Required
5. `bcr_duedate` - Date only - Required
6. `bcr_status` - Choice - Required - Default `Draft`
7. `bcr_submissionnotes` - Multiline text - Optional
8. `bcr_submittedat` - Date and time - Optional
9. `bcr_validatedat` - Date and time - Optional
10. `bcr_chasecount` - Whole number - Required - Default `0`
11. `bcr_lastchasedat` - Date and time - Optional
12. `bcr_rejectionreason` - Multiline text - Optional

### Robust required-field validation columns (avoid multiselect formatted-value issue)
Use booleans for deterministic validation:
13. `bcr_req_scope_defined` - Two options (Yes/No) - Required - Default No
14. `bcr_req_commercial_approach` - Two options - Required - Default No
15. `bcr_req_risk_assessed` - Two options - Required - Default No
16. `bcr_req_timeline_defined` - Two options - Required - Default No
17. `bcr_readinesssummary` - Multiline text - Required for submit (enforced in flow)

### Task Status choice values
- 100000000 = Draft
- 100000001 = Open
- 100000002 = InProgress
- 100000003 = Submitted
- 100000004 = AwaitingPillarValidation
- 100000005 = Approved
- 100000006 = Rejected
- 100000007 = Closed
- 100000008 = Overdue

### Relationship
- BudgetLine (1) : (N) ReadinessTask via `bcr_budgetline`

---

## 2.4 ApprovalHistory table
- **Display name**: Approval History
- **Plural**: Approval Histories
- **Primary name column**: Approval Name (`bcr_approvalname`) Text Required
- **Ownership**: User/Team

### Columns
1. `bcr_approvalname` - Text - Required
2. `bcr_readinesstask` - Lookup -> Readiness Task - Required
3. `bcr_approver` - Lookup -> User - Required
4. `bcr_decision` - Choice - Required
5. `bcr_decisionat` - Date and time - Required
6. `bcr_comments` - Multiline text - Optional

### Decision choice values
- 100000000 = Approved
- 100000001 = Rejected

### Relationship
- ReadinessTask (1) : (N) ApprovalHistory via `bcr_readinesstask`

---

## 2.5 EventLog table
- **Display name**: Event Log
- **Plural**: Event Logs
- **Primary name column**: Event Name (`bcr_eventname`) Text Required
- **Ownership**: User/Team

### Columns
1. `bcr_eventname` - Text - Required
2. `bcr_budgetline` - Lookup -> Budget Line - Required
3. `bcr_readinesstask` - Lookup -> Readiness Task - Optional
4. `bcr_eventtype` - Choice - Required
5. `bcr_eventat` - Date and time - Required
6. `bcr_triggeredby` - Lookup -> User - Optional
7. `bcr_notes` - Multiline text - Optional

### Event Type choice values
- 100000000 = Activated
- 100000001 = SMERequested
- 100000002 = SMEInProgress
- 100000003 = SMESubmitted
- 100000004 = AwaitingPillarValidation
- 100000005 = PillarValidated
- 100000006 = PillarRejected

### Relationships
- BudgetLine (1) : (N) EventLog via `bcr_budgetline`
- ReadinessTask (1) : (N) EventLog via `bcr_readinesstask` (optional)

---

## 3) Relationship Checklist (After tables exist)

Open each table -> **Relationships** and confirm:
1. Budget Line 1:N Readiness Task
2. Budget Line 1:N Event Log
3. Readiness Task 1:N Approval History
4. Readiness Task 1:N Event Log (optional but recommended)

---

## 4) Seed Minimum Data

1. Create one `Rules` row per active pillar.
2. For each Rules row set:
   - Pillar
   - Pillar Lead user
   - SME default due days (10)
   - Approval due days (3)
   - Reminder cadence (2)
3. Create 2–3 Budget Lines manually for smoke testing.
4. Set each Budget Line with valid owner, pillar, cost center, budget code, estimated value.

---

## 5) Security Roles and Table Privileges

Create five security roles in **Settings -> Users + permissions -> Security roles**:
- BCR SME
- BCR Pillar Lead
- BCR Procurement
- BCR Admin
- BCR Viewer

Privilege legend: C=Create, R=Read, W=Write, D=Delete, A=Append, AT=Append To.

## 5.1 BCR SME
- BudgetLine: R (Business Unit), AT
- ReadinessTask: R/W/A (User), AT
- EventLog: R (BU)
- ApprovalHistory: R (BU)
- Rules: R (Org)

## 5.2 BCR Pillar Lead
- BudgetLine: R (BU)
- ReadinessTask: R/W (BU) for approval-related updates
- ApprovalHistory: C/R (BU), A, AT
- EventLog: C/R (BU)
- Rules: R (Org)

## 5.3 BCR Procurement
- BudgetLine: C/R/W (Org), A, AT
- ReadinessTask: C/R/W (Org), A, AT
- EventLog: C/R (Org)
- ApprovalHistory: R (Org)
- Rules: R (Org)

## 5.4 BCR Admin
- Full privileges (Org) on all five tables.
- Environment maker permissions for flows/apps.

## 5.5 BCR Viewer
- Read-only (Org) on all five tables.

Assign roles to test users (one user can hold multiple roles for MVP testing).

---

## 6) Build Flows First: F3, F7, F8

Create flows in solution: **+ New -> Automation -> Cloud flow**.

## 6.1 F3 - Activate Budget Line

### Purpose
Creates readiness task and initial events when procurement activates a line.

### Trigger (recommended)
- **Power Apps (V2)** trigger.
- Inputs:
  1. `budgetLineId` (Text)
  2. `assignedSmeEmail` (Text, optional)
  3. `activationReason` (Text, optional)

### Actions (exact sequence)
1. **Initialize variable** `varNow` (String) = `utcNow()`.
2. **Get a row by ID** (Dataverse, BudgetLine) using `budgetLineId`.
3. **List rows** (Rules) filter by same pillar as budget line.
4. **Compose** `pillarLeadEmail` from Rules row (expand lookup email if available).
5. **Compose** `finalSmeEmail`:
   - if input email is not empty, use it
   - else use BudgetLine owner email
6. **Get user profile (V2)** Office365Users using `finalSmeEmail`.
7. **Get user profile (V2)** for `pillarLeadEmail`.
8. **Add a new row** ReadinessTask:
   - task title = `SME Readiness - {budgetlinekey}`
   - budgetline lookup = BudgetLine
   - assignedto = SME user
   - pillarlead = Pillar Lead user
   - due date = addDays(varNow, Rules.sme_default_due_days)
   - status = Open (100000001)
9. **Add a new row** EventLog (Activated).
10. **Add a new row** EventLog (SMERequested linked to task).
11. **Update row** BudgetLine:
    - derivedstage = ReadinessRequested
    - last_event_type = SMERequested
    - last_event_at = varNow
12. **Send an email (V2)** to SME with deep link to app/task.
13. **Respond to a PowerApp or flow** with task ID.

### Pitfall fix: duplicate EventLog between F3 and F4
- In MVP, do **not** build F4.
- Let F3 be sole writer of `SMERequested`.
- If you later add F4, enforce idempotency check: query EventLog for same task + `SMERequested` created in last 5 minutes before insert.

### Concurrency and idempotency
- Trigger concurrency = On, Degree 1.
- Before creating task, **List rows** ReadinessTask filter:
  - same budget line
  - status in Open/InProgress/AwaitingPillarValidation
- If found, return existing task instead of creating new.

---

## 6.2 F7 - SME Submit Task

### Trigger
- Dataverse: **When a row is added, modified or deleted**
- Change type: Modified
- Table: ReadinessTask
- Filter attributes: `bcr_status`

### Trigger condition (Settings -> Trigger conditions)
```text
@equals(triggerBody()?['bcr_status'], 100000003)
```
(Submitted)

### Actions
1. **Get row by ID** ReadinessTask.
2. **Get row by ID** BudgetLine from lookup.
3. **Condition** robust required fields pass:
   - `bcr_req_scope_defined = true`
   - `bcr_req_commercial_approach = true`
   - `bcr_req_risk_assessed = true`
   - `bcr_req_timeline_defined = true`
   - `bcr_readinesssummary` not empty
4. If **No** (validation fail):
   - Update task status to InProgress (100000002)
   - Set rejection reason with deterministic list of missing items
   - Notify SME
5. If **Yes**:
   - Update task status to AwaitingPillarValidation (100000004)
   - Set submittedat = utcNow()
   - Add EventLog `SMESubmitted`
   - Add EventLog `AwaitingPillarValidation`

### Pitfall fix: avoid formatted-value validation for multiselect
- Do not parse `@OData.Community.Display.V1.FormattedValue`.
- Use boolean columns (above) and simple true/false checks.

---

## 6.3 F8 - Mandatory Pillar Lead Validation

### Trigger
- Dataverse row modified on ReadinessTask
- Filter attributes: `bcr_status`

### Trigger condition
```text
@equals(triggerBody()?['bcr_status'], 100000004)
```
(AwaitingPillarValidation)

### Actions
1. **Get row by ID** ReadinessTask.
2. Resolve approver UPN/email reliably:
   - Use `bcr_pillarlead` lookup -> retrieve system user row -> `internalemailaddress`.
   - If blank, query Rules by pillar and resolve fallback user email.
3. **Start and wait for an approval**:
   - Approval type: Approve/Reject - First to respond
   - Assigned to: resolved approver email
   - Title: `Readiness Validation - {Task Title}`
4. **Condition** outcome = Approve?

#### Approved branch
5. Add ApprovalHistory row (decision Approved).
6. Update ReadinessTask status Approved (100000005), validatedat utcNow().
7. Add EventLog `PillarValidated`.
8. Update BudgetLine:
   - derivedstage = CommercialDiscussionReady (100000005)
   - commercialreadyat = utcNow()
   - last_event_type = PillarValidated
   - last_event_at = utcNow()
9. Notify SME + Procurement.

#### Rejected branch
5. Add ApprovalHistory row (decision Rejected + comments).
6. Update task status InProgress (100000002), rejectionreason = approval comments.
7. Add EventLog `PillarRejected`.
8. Update BudgetLine:
   - derivedstage = ReadinessReworkRequired (100000004)
   - last_event_type = PillarRejected
   - last_event_at = utcNow()
9. Notify SME with gaps.

### Approver resolution reliability rule
- Always feed Approvals action with a valid UPN/email string.
- Never pass display name.
- Validate email with condition: contains `@`; if false, terminate with clear failure and admin notification.

---

## 7) Known Pitfall Fix (Recurrence Flow Bug)

If you add reminder/escalation recurrence later, avoid using `triggerOutputs()?['body/...']` inside Apply to each over rows.

### Wrong pattern
- `triggerOutputs()?['body/bcr_duedate']` in recurrence flow (no per-row context)

### Correct pattern
- Use `items('Apply_to_each')?['bcr_duedate']`

### Example expression
```text
sub(ticks(utcNow()), ticks(items('Apply_to_each')?['bcr_duedate']))
```

---

## 8) Minimal Canvas App Bootstrap (3 Screens)

Create app in solution:
1. **Create -> Canvas app from blank**
2. Name: `BCR MVP App`
3. Tablet layout
4. Add Dataverse data sources:
   - BudgetLine, ReadinessTask, EventLog
5. Add flow connection for F3.

## 8.1 Screen A: Budget Lines + Activate
Controls:
- Text input `txtSearchBudgetLine`
- Gallery `galBudgetLines`
- Optional text input `txtActivationReason`
- Button `btnActivate`

Paste formula in gallery `Items`:
```powerfx
SortByColumns(
    Filter(
        bcr_budgetlines,
        StartsWith(bcr_budgetlinekey, txtSearchBudgetLine.Text) ||
        StartsWith(bcr_costcenter, txtSearchBudgetLine.Text) ||
        StartsWith(bcr_budgetcode, txtSearchBudgetLine.Text)
    ),
    "modifiedon",
    SortOrder.Descending
)
```

Paste formula in `btnActivate.OnSelect`:
```powerfx
If(
    IsBlank(galBudgetLines.Selected),
    Notify("Select a budget line first.", NotificationType.Error),
    flowActivateBudgetLine.Run(
        galBudgetLines.Selected.bcr_budgetlineid,
        User().Email,
        txtActivationReason.Text
    );
    Notify("Activation submitted.", NotificationType.Success);
    Refresh(bcr_readinesstasks);
    Refresh(bcr_eventlogs)
)
```

## 8.2 Screen B: My Tasks
Controls:
- Gallery `galMyTasks`

`galMyTasks.Items`:
```powerfx
SortByColumns(
    Filter(
        bcr_readinesstasks,
        bcr_assignedto.'Primary Email' = User().Email
    ),
    "bcr_duedate",
    SortOrder.Ascending
)
```

OnSelect of gallery row:
```powerfx
Set(varTask, ThisItem);
Navigate(scrTaskDetail, ScreenTransition.Fade)
```

## 8.3 Screen C: Task Detail / Submit
Controls:
- Four toggles bound to required boolean fields
- Text input for summary
- Text input for notes
- Save button
- Submit button

`btnSave.OnSelect`:
```powerfx
Patch(
    bcr_readinesstasks,
    varTask,
    {
        bcr_status: 'Status (bcr_status)'.InProgress,
        bcr_req_scope_defined: tglScope.Value,
        bcr_req_commercial_approach: tglCommercial.Value,
        bcr_req_risk_assessed: tglRisk.Value,
        bcr_req_timeline_defined: tglTimeline.Value,
        bcr_readinesssummary: txtSummary.Text,
        bcr_submissionnotes: txtNotes.Text
    }
);
Notify("Saved", NotificationType.Success)
```

`btnSubmit.DisplayMode`:
```powerfx
If(
    tglScope.Value && tglCommercial.Value && tglRisk.Value && tglTimeline.Value && !IsBlank(Trim(txtSummary.Text)),
    DisplayMode.Edit,
    DisplayMode.Disabled
)
```

`btnSubmit.OnSelect`:
```powerfx
Patch(
    bcr_readinesstasks,
    varTask,
    {
        bcr_req_scope_defined: tglScope.Value,
        bcr_req_commercial_approach: tglCommercial.Value,
        bcr_req_risk_assessed: tglRisk.Value,
        bcr_req_timeline_defined: tglTimeline.Value,
        bcr_readinesssummary: txtSummary.Text,
        bcr_submissionnotes: txtNotes.Text,
        bcr_status: 'Status (bcr_status)'.Submitted
    }
);
Notify("Submitted for Pillar Lead validation", NotificationType.Success)
```

---

## 9) Publish and Wire Up

1. Save and publish all three flows (F3, F7, F8).
2. Turn on flows.
3. Save and publish Canvas app.
4. Share app with security roles/users.
5. Assign app users the correct Dataverse roles.

---

## 10) Smoke Test Checklist (End-to-End)

## Test A: Activation
1. Open app as Procurement user.
2. Select BudgetLine and click Activate.
3. Expected Dataverse changes:
   - **ReadinessTask**: one new row, status Open, assigned SME, pillar lead set.
   - **EventLog**: two rows (`Activated`, `SMERequested`).
   - **BudgetLine**: `derivedstage=ReadinessRequested`, `last_event_type=SMERequested`, `last_event_at` set.

## Test B: SME submit validation fail
1. Open task as SME, leave one required toggle off.
2. Submit.
3. Expected:
   - F7 reverts task to InProgress.
   - `rejectionreason` contains missing item(s).
   - No AwaitingPillarValidation event created.

## Test C: SME submit valid
1. Complete all toggles and summary.
2. Submit.
3. Expected:
   - Task status becomes AwaitingPillarValidation.
   - EventLog contains `SMESubmitted` and `AwaitingPillarValidation`.

## Test D: Pillar approval approve
1. Pillar Lead receives approval and clicks Approve.
2. Expected:
   - ApprovalHistory row decision Approved.
   - ReadinessTask status Approved + validatedat.
   - EventLog row `PillarValidated`.
   - BudgetLine `derivedstage=CommercialDiscussionReady`, `commercialreadyat` set, last_event fields updated.

## Test E: Pillar approval reject
1. Repeat on new task; Pillar Lead rejects with comments.
2. Expected:
   - ApprovalHistory row decision Rejected with comments.
   - ReadinessTask moved to InProgress with `rejectionreason`.
   - EventLog row `PillarRejected`.
   - BudgetLine `derivedstage=ReadinessReworkRequired`.

## Test F: Duplicate protection
1. Click Activate twice quickly for same budget line.
2. Expected:
   - Only one open/in-progress readiness task exists.
   - No duplicated `SMERequested` event from secondary notifier flow (because F4 is not used in MVP).

---

## 11) MVP Go-Live Guardrails

- Keep all stage changes event-driven through flows.
- Do not allow manual edits of BudgetLine stage in app.
- Use booleans for required readiness checks in MVP.
- Keep Approvals assigned to UPN/email only.
- Keep F3 as sole source for activation and SMERequested event logging.
