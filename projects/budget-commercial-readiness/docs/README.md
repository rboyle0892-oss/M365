# Budget Commercial Readiness Platform

## Overview
The Budget Commercial Readiness Platform is an activation-driven operating model implemented with Dataverse, Power Apps, and Power Automate. Budget lines already exist in Excel and are synchronized into Dataverse. The platform does **not** collect new procurement requests; instead, it deliberately progresses existing budget lines through commercial readiness milestones.

The core principle is controlled progression: each status move is caused by a recorded event, rule, or approval decision.

## What “Activation” means
Activation is an intentional action by Procurement/Budget Operations to start progression for an existing Budget Line. It is effectively “requesting a request”: creating a structured Readiness Activation Task that asks the SME to provide required readiness information before supplier engagement can begin.

Activation always does the following:
1. Records an `Activated` event.
2. Creates a Readiness Task for the SME.
3. Applies due dates and assignment logic from Rules.
4. Starts reminders/escalation timers automatically.

## What “Commercial Discussion Ready” means
A Budget Line is **Commercial Discussion Ready** only after:
1. SME has completed required readiness data.
2. Task has been formally submitted.
3. Pillar Lead has completed mandatory validation with an approval decision.

Checklist concept:
- Required metadata complete (owner, pillar, cost center, budget code, value, currency).
- Commercial framing complete (scope summary, assumptions, expected procurement route, timing).
- Risk/constraint fields complete.
- Validation outcome = Approved.

Commercial Discussion Ready is not a passive state; it is set only by event and approval outcome.

## Roles
- **SME**: completes assigned readiness tasks and submits for validation.
- **Pillar Lead**: mandatory approver; validates readiness quality and can reject with gaps.
- **Procurement/Commercial**: activates budget lines, tracks discussion milestones, records PO outcomes.
- **Admin**: maintains rules (pillar mapping, SLAs), monitors integration/health logs.
- **Viewer**: read-only access for reporting and oversight.

## MVP scope
- Excel-to-Dataverse load and incremental sync for Budget Lines.
- Activation flow to create structured readiness tasks.
- SME task completion and submission workflow.
- Mandatory Pillar Lead approval gate.
- Event-driven stage derivation from EventLog.
- Commercial start/complete milestones.
- Purchase Order recording with multi-PO support per budget line.
- Reminder/chase/escalation automation.
- Renewal and data-quality task generation.

## Explicit non-goals
- No procurement request intake portal.
- No supplier onboarding workflow.
- No custom connectors, HTTP actions, or external APIs.
- No contract authoring, negotiation tracking, or legal workflow automation in MVP.
- No advanced forecasting or BI model design beyond operational data capture.

## End-to-end process (activation-driven)
1. Budget lines are loaded/synced from Excel into Dataverse by alternate key (`budgetlinekey`).
2. Procurement reviews a line and intentionally triggers Activation.
3. System logs `Activated` event and creates SME Readiness Task with SLA dates.
4. SME receives notification with deep link and begins task completion.
5. Reminders and chases run automatically based on Rules and due dates.
6. SME submits task; system validates required fields.
7. If validation fails, task returns to SME with explicit correction reason.
8. If validation passes, task moves to `AwaitingPillarValidation` and approval is sent.
9. Pillar Lead approves or rejects with comments.
10. Approval sets Budget Line to Commercial Discussion Ready; rejection routes back to SME.
11. Procurement marks commercial discussion start/complete milestones.
12. Procurement records one or more POs; events/stages update and line can be closed.


## Repository implementation index
- Solution source (Dataverse solution artifacts): `projects/budget-commercial-readiness/src/solution/`
- Flow assets: `projects/budget-commercial-readiness/src/solution/Workflows/`
- App blueprint and formulas: `projects/budget-commercial-readiness/powerapps/`
- Dataverse target schema documentation: `projects/budget-commercial-readiness/dataverse/schema.md`
- Validation checks: `projects/budget-commercial-readiness/tests/validate-solution-structure.sh`
