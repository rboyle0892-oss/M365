# Canvas App Blueprint

## Objective
Deliver a minimal but complete operational Canvas app for activation-driven commercial readiness using Dataverse as the sole operational backend.

## Data sources
- `bcr_budgetlines`
- `bcr_readinesstasks`
- `bcr_eventlogs`
- `bcr_purchaseorders`
- `bcr_suppliers`
- `bcr_rules`
- `bcr_approvalhistories`
- `Users` (Office365Users connector)

## Screens

### 1) Home / Dashboard
Purpose: portfolio view.
- KPI cards: count by `derivedstage`.
- Overdue tasks count (`duedate < Today() && status in Open/InProgress/AwaitingPillarValidation`).
- Quick links: Activate, My Tasks, Approvals, Admin Rules.

### 2) Activate Budget Line
Purpose: controlled activation by Procurement.
- Search bar (budget line key, cost center, budget code, owner).
- Gallery of eligible lines (not closed/parked unless reactivation allowed).
- Activation panel:
  - Optional activation reason.
  - SME override assignment (if not owner).
  - Activate button -> flow call.

### 3) My Tasks (SME)
Purpose: focused personal queue.
- Tabs/filters: Open, In Progress, Returned, Awaiting Validation, Overdue.
- Sort by due date ascending.
- Badge for chase count.

### 4) Task Detail
Purpose: structured completion and submit.
- Header: BudgetLine key, due date, pillar lead.
- Required checklist controls (multi-select/checkbox set).
- Structured fields (summary, strategy, target date, dependencies/risk flags).
- Save Draft, Mark In Progress, Submit actions.
- Inline validation messages.

### 5) Pillar Lead Approvals
Purpose: queue and context navigation.
- Gallery of tasks `AwaitingPillarValidation` where `pillarlead = current user`.
- Deep link button to approval record/history.
- Open task context for review (read-only readiness content).
- Status chips: pending/approved/rejected.

### 6) Budget Line Detail
Purpose: end-to-end line visibility.
- Core fields (owner, pillar, value, renewal, stage).
- Manual override indicators.
- Timeline (EventLog by eventat desc).
- Related tasks and approval outcomes.
- Commercial timestamps section.

### 7) Add Purchase Order
Purpose: fast multi-PO capture.
- Form fields: supplier, PO number, date, amount, currency, notes.
- Submit resets form and refreshes related PO gallery.
- Supports multiple PO entries per budget line.

### 8) Admin Rules
Purpose: self-managed behavior tuning.
- Edit Rules table by pillar:
  - pillar lead
  - due days
  - reminder cadence
  - max chase
  - escalation user and threshold
  - checklist definition text
- Data quality + integration error quick links.

## Navigation map
- Home -> Activate / My Tasks / Approvals / Rules / BudgetLine Detail.
- Activate -> BudgetLine Detail or Task Detail after activation.
- My Tasks -> Task Detail -> BudgetLine Detail.
- Approvals -> Task Detail (read-only review) -> BudgetLine Detail.
- BudgetLine Detail -> Add Purchase Order.
- Rules -> Home.

## Delegation-safe approach
- Use Dataverse delegable operators: `Filter`, `SortByColumns`, `StartsWith`, `LookUp` with simple predicates.
- Avoid non-delegable `in` over large tables where possible; use normalized search helper fields if needed.
- Use server-side filtered views for heavy admin/reporting queries.
- Keep galleries paged and filtered by user, status, and date windows.

## Minimal input design
- Favor controlled choices and booleans over long narrative text.
- Keep free-text to `submissionnotes`, `rejectionreason`, `notes` only.
- Checklist and structured fields drive readiness quality and validation.

## Commercial Discussion Ready checklist representation
Implementation approach:
1. Rules table stores editable checklist definition text per pillar (JSON-light list).
2. Task Detail screen displays fixed required controls + optional pillar-specific prompts from rules text.
3. Computed Ready flag:
   - all mandatory controls complete,
   - no data quality blockers,
   - submit validation passed,
   - Pillar approval outcome = Approved.

Ready flag displayed as:
- `Ready for Validation` before submit,
- `Commercial Discussion Ready` only after approval event is logged.
