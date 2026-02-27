# Architecture - Budget Commercial Readiness Platform

## A) Architecture Overview

### Core pattern
- **System of record**: Dataverse.
- **Seed/Sync source**: Excel Online (Business) Budget Line workbook.
- **Operational UI**: Power Apps Canvas app.
- **Workflow engine**: Power Automate cloud flows.
- **Approval gate**: Approvals connector (mandatory Pillar Lead validation).

### Data and control flow
1. Excel rows are loaded into Dataverse `BudgetLine` using `budgetlinekey` alternate key (upsert-safe).
2. Users operate only on Dataverse records through Canvas app.
3. Activation creates a `ReadinessTask` and event history.
4. Submission and approval outcomes write to `ApprovalHistory` and `EventLog`.
5. `BudgetLine.derivedstage` is maintained from latest event (or explicit override).
6. Reminder/escalation and quality checks are fully automated with scheduled flows.

### Why this architecture
- Dataverse provides relational integrity for budget lines, tasks, approvals, POs, and events.
- Event-driven model avoids brittle manual status updates.
- Mandatory approval gate guarantees governance before supplier engagement.

---

## B) Dataverse Entity Model

### 1. BudgetLine
Represents an existing funding line synchronized from Excel and progressed through activation-driven stages.

### 2. Activation (optional helper, included)
Captures each intentional activation instance (who/when/why) and creates clean auditability when a line is re-activated after parking/rework.

### 3. ReadinessTask
Structured “Readiness Activation Task” assigned to SME for completion and submission.

### 4. Supplier
Reference table for suppliers tied to POs.

### 5. PurchaseOrder
Commercial outcome records associated to budget lines (supports 1:N PO relationships).

### 6. ApprovalHistory
Stores each Pillar Lead decision instance and comments for traceability.

### 7. Rules
Admin-maintained operational policy table (pillar mapping, due dates, reminder cadence, escalation behavior, checklist definition).

### 8. IntegrationError
Centralized operational error log for failed flow actions and payload excerpts.

### 9. EventLog
Immutable timeline of deliberate state transitions and significant workflow events.

### Relationships
- `BudgetLine` 1:N `ReadinessTask`
- `BudgetLine` 1:N `PurchaseOrder`
- `BudgetLine` 1:N `EventLog`
- `ReadinessTask` 1:N `ApprovalHistory`
- `Supplier` 1:N `PurchaseOrder`
- Optional helper used: `BudgetLine` 1:N `Activation`

---

## C) Event-Driven Stage Model (Activation-driven)

### Event types
- Activated
- SMERequested
- SMEInProgress
- SMESubmitted
- AwaitingPillarValidation
- PillarValidated
- PillarRejected
- CommercialDiscussionStarted
- CommercialDiscussionComplete
- PORecorded
- Closed
- Parked (optional)

### Stage derivation rule
`BudgetLine.DerivedStage` is derived from the latest `EventLog.eventtype` by `EventLog.eventat` descending, with deterministic mapping:

- `Activated` / `SMERequested` -> `ReadinessRequested`
- `SMEInProgress` -> `ReadinessInProgress`
- `SMESubmitted` / `AwaitingPillarValidation` -> `AwaitingPillarValidation`
- `PillarValidated` -> `CommercialDiscussionReady`
- `CommercialDiscussionStarted` -> `CommercialDiscussionInProgress`
- `CommercialDiscussionComplete` -> `CommercialDiscussionComplete`
- `PORecorded` -> `PartiallyOrdered` or `Ordered` (based on PO amount aggregation rule)
- `Closed` -> `Closed`
- `PillarRejected` -> `ReadinessReworkRequired`
- `Parked` -> `Parked`

### Manual override policy
Manual override is exception-only and auditable:
- `manualstageoverride` (choice)
- `manualoverridejustification` (required when override exists)
- `manualoverrideat` / `manualoverrideby`

Display logic in app:
- If override present, display override stage with “(Manual Override)” badge.
- Automation still writes event-derived stage, but reporting includes override metadata.

---

## D) Mandatory Pillar Lead Validation

1. Triggered only after SME submission passes required-field validation.
2. Task moves to `AwaitingPillarValidation`.
3. Approvals connector starts approval assigned to Pillar Lead from task/rules mapping.
4. Decision is written into `ApprovalHistory` with comments and timestamp.
5. **Rejected**:
   - Task status -> `Rejected` (or reopened to `InProgress` by policy).
   - `rejectionreason` populated with explicit gaps.
   - Event `PillarRejected` logged.
   - SME notified with correction request.
6. **Approved**:
   - Task status -> `Approved`, `validatedat` stamped.
   - Event `PillarValidated` logged.
   - Budget line set to `CommercialDiscussionReady` with `commercialreadyat`.

This gate is mandatory; no commercial-ready transition without approval.

---

## E) Governance & Security Roles (Dataverse)

- **SME**
  - Read assigned BudgetLines (scope-limited).
  - Read/write assigned ReadinessTasks.
  - Read related EventLog and ApprovalHistory.
  - Cannot approve own tasks unless explicitly allowed (default: no).

- **Pillar Lead**
  - Read linked BudgetLines and submitted tasks.
  - Create ApprovalHistory decisions.
  - Update validation-related task fields and comments.

- **Procurement**
  - Activate BudgetLines.
  - Read all readiness/approval/event data.
  - Update commercial milestone fields.
  - Create and manage PurchaseOrders.

- **Admin**
  - Full control on Rules, mappings, error logs, and event health.
  - Can apply manual stage override with mandatory justification.

- **Viewer**
  - Read-only across reporting entities.

---

## F) Scale considerations

### Why Dataverse
- Handles relational workloads natively (BudgetLine-task-approval-PO-event).
- Supports row-level security and role-based permissions.
- Provides auditing for compliance and traceability.
- Better delegation behavior in Canvas apps for large datasets.
- Supports alternate keys for reliable idempotent upsert.

### Preventing manual status rot
- Stage is computed from latest EventLog entry, not manually typed status updates.
- Flows stamp events for every meaningful transition.
- Manual override is explicit, justified, and auditable.
- Automated reminders/escalations ensure tasks continue to move without manual chase orchestration.
