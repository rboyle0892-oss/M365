# Acceptance Tests (Given/When/Then)

## Activation and Task Creation
1. **Activation creates readiness task**
- Given a BudgetLine exists with valid owner and pillar rule
- When Procurement activates the line
- Then one SMEReadiness task is created in Open status and linked to the BudgetLine

2. **Activation logs event**
- Given activation is triggered from Canvas app
- When flow F3 completes
- Then EventLog contains `Activated` and `SMERequested` for that budget line

3. **Activation sends SME notification**
- Given SME is assigned on activation
- When readiness task is created
- Then SME receives Outlook/Teams notification with deep link

4. **No duplicate open readiness task on repeated activation click**
- Given an Open SMEReadiness task already exists for the BudgetLine
- When activation is triggered again
- Then no duplicate Open SMEReadiness task is created

## SME Completion and Validation
5. **SME can save in-progress task**
- Given SME opens assigned task
- When SME saves partial fields
- Then status remains InProgress and entered values persist

6. **Submission blocked when required fields missing**
- Given SME checklist is incomplete
- When SME submits task
- Then flow reverts status to InProgress and writes rejectionreason with missing fields

7. **Valid submission advances to AwaitingPillarValidation**
- Given required fields/checklist are complete
- When SME submits task
- Then task status becomes AwaitingPillarValidation and EventLog records `SMESubmitted` + `AwaitingPillarValidation`

8. **Mandatory approval starts on submission**
- Given task entered AwaitingPillarValidation
- When F8 executes
- Then an approval request is sent to the configured Pillar Lead

## Pillar Lead Gate
9. **Approval marks commercial ready**
- Given Pillar Lead approves
- When approval outcome is processed
- Then ApprovalHistory is written and BudgetLine stage becomes CommercialDiscussionReady with commercialreadyat set

10. **Rejection returns to SME with comments**
- Given Pillar Lead rejects with comments
- When outcome is processed
- Then task returns to InProgress with rejectionreason populated and EventLog contains `PillarRejected`

11. **Rejected line stays not-ready**
- Given latest approval outcome is rejected
- When viewing BudgetLine
- Then stage is not CommercialDiscussionReady

12. **Approval fallback uses Rules mapping if pillarlead missing on task**
- Given task pillarlead is blank and Rules has pillar lead
- When F8 runs
- Then approval is assigned to Rules.pillarlead

## Reminder, Chase, Escalation
13. **Reminder cadence increments chase count**
- Given task is open and due date condition is met
- When reminder flow runs on cadence day
- Then reminder is sent and chasecount increments by 1 with lastchasedat updated

14. **Chasing stops at max**
- Given task chasecount equals rules max_chase_count
- When reminder flow runs
- Then no further chase notification is sent and chasecount does not increment

15. **Escalation triggers after threshold**
- Given overdue days >= escalation_after_days_overdue
- When escalation flow runs
- Then escalation recipients are notified and EventLog records `Escalated`

## Renewal and Data Quality
16. **Renewal task generated at 90/60/30**
- Given BudgetLine renewaldate is exactly 60 days away
- When renewal flow runs
- Then a Renewal task is created and owner/SME are notified

17. **Renewal generator avoids duplicates**
- Given open Renewal task already exists for the same window
- When renewal flow runs again
- Then no duplicate Renewal task is created

18. **Data quality watchdog raises task for missing fields**
- Given a BudgetLine missing owner and currency
- When watchdog flow executes
- Then one DataQuality task is created with missing-field details

## Commercial Outcomes, Overrides, and Error Logging
19. **Multiple POs per budget line and stage update**
- Given BudgetLine estimated value is 100000
- When first PO of 40000 is recorded and second PO of 60000 is recorded
- Then line transitions from PartiallyOrdered to Ordered and each PO writes a `PORecorded` event

20. **Manual override governance and integration error logging**
- Given admin sets manualstageoverride
- When manualoverridejustification is blank
- Then save is blocked by rule; and if any flow action fails during processing, IntegrationError row is created with source, code, message, payload excerpt, severity, occurredat
