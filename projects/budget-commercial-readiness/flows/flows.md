# Power Automate Flow Design

Design standards used in all flows:
- Dataverse is system of record.
- Use **Scope: Try / Catch / Finally** pattern.
- In Catch, write `IntegrationError` row with source, related IDs, error code/message, payload excerpt.
- Turn on trigger concurrency control where race risk exists.
- Idempotency uses alternate keys (`budgetlinekey`) and pre-check queries.

## F1. Excel -> Dataverse Initial Load
**Trigger**: Manual instant flow (button from admin) or scheduled one-time run.

**Actions**:
1. `List rows present in a table` (Excel Online Business).
2. `Apply to each` row.
3. Try scope:
   - `Compose` normalized key: `toUpper(trim(items('Apply_to_each')?['BudgetLineKey']))`
   - `Upsert row` in Dataverse `BudgetLine` using alternate key `bcr_budgetlinekey`.
   - `Add a new row` EventLog with `Loaded` event type.
4. Catch scope:
   - `Add a new row` IntegrationError.
5. Finally scope:
   - `Increment variable` success/fail counters.

**Expressions**:
- Upsert key: `toUpper(trim(item()?['BudgetLineKey']))`
- Event name: `concat('Loaded - ', outputs('Compose_NormalizedKey'), ' - ', utcNow())`

**Concurrency**:
- `Apply to each` concurrency OFF for first load (data integrity priority).

**Idempotency**:
- Upsert by alternate key prevents duplicate budget lines.
- Optional dedupe EventLog by checking same key + event type + date.

---

## F2. Excel -> Dataverse Incremental Sync
**Trigger**: Recurrence (e.g., every 2 hours).

**Actions**:
1. `List rows present in a table`.
2. Filter rows changed since last watermark (`LastUpdated`).
3. `Apply to each` changed row -> upsert BudgetLine.
4. Update stored watermark in environment variable/table.

**If LastUpdated unavailable (fallback)**:
- Build checksum from key columns and compare with `bcr_sourcechecksum` optional field.

**Expressions**:
- Changed row check: `greater(item()?['LastUpdated'], variables('LastWatermark'))`
- Checksum fallback: `base64(concat(item()?['CostCenter'],'|',item()?['BudgetCode'],'|',string(item()?['EstimatedValue'])))`

**Concurrency**:
- `Apply to each` concurrency ON (degree 10) safe due to alternate-key upsert.

**Idempotency**:
- Upsert by `budgetlinekey`; no duplicates.

---

## F3. Activate Budget Line
**Trigger**: Power Apps V2 action (button) OR Dataverse row update where `bcr_activationrequested = true`.

**Actions**:
1. Read BudgetLine row.
2. Fetch Rules by pillar.
3. Try scope:
   - Create `Activation` row (who/when/why).
   - Create EventLog `Activated`.
   - Create ReadinessTask category `SMEReadiness`, status `Open`, due date from rules.
   - Create EventLog `SMERequested` linked to task.
   - Update BudgetLine last event fields + derived stage `ReadinessRequested`.
   - Send notification to SME.
4. Catch: log IntegrationError.
5. Finally: return Task ID to app.

**Expressions**:
- Due date: `addDays(utcNow(), int(first(body('List_rows_Rules')?['value'])?['bcr_sme_default_due_days']))`
- Pillar rule filter: `concat("bcr_pillar eq '", triggerBody()?['bcr_pillar'], "'")`

**Concurrency**:
- Trigger concurrency 1 per budget line to avoid double activation.

**Idempotency**:
- Pre-check open SMEReadiness task for same budget line:
  `bcr_budgetline eq @{triggerBody()?['bcr_budgetlineid']} and bcr_taskcategory eq 100000000 and (bcr_status eq 100000001 or bcr_status eq 100000002 or bcr_status eq 100000003)`

---

## F4. Notify SME on Task Creation
**Trigger**: Dataverse when ReadinessTask added and category = SMEReadiness.

**Actions**:
1. Get related BudgetLine.
2. Compose deep link to Canvas app.
3. Send Outlook email or Teams message.
4. Write EventLog `SMERequested` (if not already in F3).

**Expressions**:
- Link: `concat('https://apps.powerapps.com/play/appId=<APPID>&tenantId=<TENANT>&source=task&taskId=', triggerBody()?['bcr_readinesstaskid'])`

**Idempotency**:
- Check EventLog for same task + event type before insert.

---

## F5. Reminder Chase (Business-day aware)
**Trigger**: Recurrence daily at 08:00.

**Actions**:
1. Query open tasks with statuses Open/InProgress/Submitted/AwaitingPillarValidation.
2. For each task, load Rules by pillar.
3. Compute days overdue (or days to due).
4. If due soon/overdue and chasecount < max, send reminder.
5. Increment `chasecount`; set `lastchasedat`.
6. If threshold reached, flag escalation candidate.

**Business-day assumption**:
- Weekends excluded; holidays not modeled in MVP.

**Expressions**:
- Weekend skip: `or(equals(dayOfWeek(utcNow()),0),equals(dayOfWeek(utcNow()),6))`
- Due/overdue: `sub(ticks(utcNow()), ticks(triggerOutputs()?['body/bcr_duedate']))`
- Chase check: `less(int(items('Apply_to_each')?['bcr_chasecount']), int(variables('maxChase')))`

**Concurrency**:
- For each concurrency degree 5.

**Idempotency**:
- One chase/day guard: `not(equals(formatDateTime(item()?['bcr_lastchasedat'],'yyyy-MM-dd'), formatDateTime(utcNow(),'yyyy-MM-dd')))`

---

## F6. Escalation Flow
**Trigger**: Called from F5 child flow or standalone daily recurrence.

**Actions**:
1. Get overdue tasks where overdue days >= rules threshold.
2. Notify `escalation_to`, pillar lead, procurement mailbox.
3. Add EventLog `Escalated`.
4. Optionally set task status `Overdue`.

**Expressions**:
- Overdue threshold: `greaterOrEquals(variables('daysOverdue'), int(variables('escalationAfter')))`

**Idempotency**:
- Do not escalate same task more than once in 48h using EventLog check.

---

## F7. SME Submit Task
**Trigger**: Dataverse ReadinessTask updated where status = Submitted.

**Actions**:
1. Get task + linked budget line + rules.
2. Validate required fields/checklist.
3. If validation fails:
   - Update status `InProgress`.
   - Populate `rejectionreason` with missing fields.
   - Notify SME.
4. If validation passes:
   - Set status `AwaitingPillarValidation`, `submittedat = utcNow()`.
   - Log Event `SMESubmitted` then `AwaitingPillarValidation`.
   - Invoke F8 (or rely on F8 trigger).

**Expressions**:
- Missing checklist count example:
  `length(filter(createArray('ScopeDefined','CommercialApproach','RiskAssessment','Timeline'), not(contains(triggerBody()?['bcr_requiredfieldschecklist@OData.Community.Display.V1.FormattedValue'], item()))))`
- Validation pass: `equals(outputs('Compose_MissingCount'),0)`

**Idempotency**:
- Guard using `submittedat` not null and status transition tracking in EventLog.

---

## F8. Mandatory Pillar Lead Validation (Approvals)
**Trigger**: Dataverse ReadinessTask status changes to `AwaitingPillarValidation`.

**Actions**:
1. Determine approver = `task.pillarlead` else rules fallback.
2. `Start and wait for an approval` (Approve/Reject - First to respond).
3. Branch outcome.

**Approved branch**:
- Insert ApprovalHistory.
- Update ReadinessTask -> Approved + validatedat.
- Write EventLog `PillarValidated`.
- Update BudgetLine -> `derivedstage = CommercialDiscussionReady`, `commercialreadyat`, `last_event_type`, `last_event_at`.
- Notify Procurement + SME.

**Rejected branch**:
- Insert ApprovalHistory decision rejected + comments.
- Update ReadinessTask -> `InProgress` (chosen policy: reopen same task for continuity), set `rejectionreason`.
- Write EventLog `PillarRejected`.
- Notify SME with explicit gaps.

**Expressions**:
- Approval outcome check: `equals(outputs('Start_and_wait_for_an_approval')?['body/outcome'],'Approve')`
- Approver fallback: `coalesce(triggerBody()?['bcr_pillarlead@odata.bind'], first(body('List_rows_Rules')?['value'])?['bcr_pillarlead@odata.bind'])`

**Concurrency**:
- Trigger concurrency 1 to avoid duplicate approvals for same task.

**Idempotency**:
- Before starting approval, check no pending approval exists for task.

---

## F9. Mark Commercial Discussion Started/Complete
**Trigger**: BudgetLine updated by Procurement with milestone flag/field.

**Actions**:
1. Condition on changed field values.
2. If started:
   - set timestamp if empty.
   - EventLog `CommercialDiscussionStarted`.
   - Update derived stage.
3. If complete:
   - set `commercialcompleteat`.
   - EventLog `CommercialDiscussionComplete`.
   - Update derived stage.

**Expressions**:
- Started condition: `and(equals(triggerBody()?['bcr_markcommercialstarted'], true), empty(triggerBody()?['bcr_commercialstartat']))`

**Idempotency**:
- Do not rewrite same milestone if timestamp already set.

---

## F10. Record Purchase Order
**Trigger**: Dataverse row added in PurchaseOrder.

**Actions**:
1. Get related BudgetLine.
2. Create EventLog `PORecorded`.
3. Aggregate PO totals for budget line (`List rows` PurchaseOrder filtered by budgetline).
4. Stage rule assumptions:
   - Sum PO = 0 -> no change
   - 0 < Sum PO < EstimatedValue -> `PartiallyOrdered`
   - Sum PO >= EstimatedValue -> `Ordered`
   - Procurement may then mark `Closed` manually when complete
5. Update budget line stage + last event fields.
6. Notify budget owner + procurement.

**Expressions**:
- Aggregation ratio check uses `float()` comparisons.

**Concurrency**:
- Trigger concurrency 1 (prevents race during aggregation).

**Idempotency**:
- Unique PO key by `ponumber + budgetline`.

---

## F11. Renewal Task Generator (90/60/30)
**Trigger**: Recurrence daily.

**Actions**:
1. Query BudgetLine with renewal date in next 90 days.
2. Determine window bucket (90/60/30) based on date diff.
3. Check if open Renewal task exists for line + bucket.
4. If not exists, create Renewal ReadinessTask and notify owner/SME.
5. Log Event `SMERequested` or `RenewalTriggered` (if extra enum added).

**Expressions**:
- Days to renewal: `div(sub(ticks(items('Apply_to_each')?['bcr_renewaldate']),ticks(utcNow())),864000000000)`
- Bucket check: `or(equals(variables('daysToRenewal'),90),equals(variables('daysToRenewal'),60),equals(variables('daysToRenewal'),30))`

**Idempotency**:
- Check existing open task where category Renewal and title contains bucket token.

---

## F12. Data Quality Watchdog
**Trigger**: Recurrence daily or weekly.

**Actions**:
1. Query BudgetLines with missing critical fields.
2. For each defective line, check open DataQuality task existence.
3. Create DataQuality task with clear missing-field notes.
4. Notify owner and admin queue.
5. Log Event `SMERequested` or `DataQualityRaised`.

**Missing fields set**:
- owner, pillar, category, cost center, budget code, currency, estimated value.

**Expression example**:
`or(empty(item()?['bcr_owner']), empty(item()?['bcr_pillar']), empty(item()?['bcr_category']), empty(item()?['bcr_costcenter']), empty(item()?['bcr_budgetcode']), empty(item()?['_transactioncurrencyid_value']), equals(float(item()?['bcr_estimatedvalue']),0))`

**Idempotency**:
- One open DataQuality task per budget line.

---

## Expressions Library

### Business-day helper (simple)
- Is weekend:
`or(equals(dayOfWeek(utcNow()),0),equals(dayOfWeek(utcNow()),6))`
- Next business day (simplified):
`if(equals(dayOfWeek(utcNow()),5), addDays(utcNow(),3), if(equals(dayOfWeek(utcNow()),6), addDays(utcNow(),2), addDays(utcNow(),1)))`

### Alternate-key upsert pattern
- Use Dataverse `Upsert a row` with key column `bcr_budgetlinekey`.
- Normalized key:
`toUpper(trim(<sourceBudgetLineKey>))`

### Idempotency checks
- Existing open task for category and line:
`@and(equals(item()?['_bcr_budgetline_value'], variables('budgetlineid')), equals(item()?['bcr_taskcategory'], variables('taskCategory')), or(equals(item()?['bcr_status'],100000001),equals(item()?['bcr_status'],100000002),equals(item()?['bcr_status'],100000004)))`

- Existing event in last 1 day:
`@and(equals(item()?['_bcr_budgetline_value'], variables('budgetlineid')), equals(item()?['bcr_eventtype'], variables('eventType')), greater(item()?['createdon'], addDays(utcNow(),-1)))`

## Common Try/Catch/Finally Pattern (template)
1. **Scope - Try**: main logic.
2. **Scope - Catch** (run after Try has failed/timed out):
   - Compose error:
   `result('Scope_-_Try')`
   - Insert `IntegrationError` row with source + payload excerpt.
3. **Scope - Finally** (always runs):
   - telemetry counters, optional summary notification.
