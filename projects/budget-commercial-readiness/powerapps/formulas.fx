// ---------- App OnStart ----------
Set(varCurrentUser, User());
Set(varToday, Today());
Set(varErrorText, Blank());

// ---------- BudgetLine Search (Activate screen) ----------
// txtSearchBudgetLine.Text used for query
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

// ---------- Activate selected BudgetLine ----------
// Button OnSelect (Procurement action)
Set(varErrorText, Blank());
If(
    IsBlank(galBudgetLines.Selected),
    Notify("Select a budget line first.", NotificationType.Error),
    Set(
        varActivationResult,
        flowActivateBudgetLine.Run(
            galBudgetLines.Selected.bcr_budgetlineid,
            Coalesce(ddAssignSME.Selected.'Primary Email', ""),
            txtActivationReason.Text
        )
    );
    Notify("Activation submitted. Readiness task created.", NotificationType.Success);
    Refresh(bcr_readinesstasks);
    Refresh(bcr_eventlogs)
);

// ---------- EventLog helper pattern ----------
// Reusable inline patch when direct app logging is needed
Patch(
    bcr_eventlogs,
    Defaults(bcr_eventlogs),
    {
        bcr_eventname: "SMEInProgress - " & varBudgetLine.bcr_budgetlinekey & " - " & Text(Now(), "[$-en-US]yyyy-mm-dd hh:mm:ss"),
        bcr_budgetline: varBudgetLine,
        bcr_readinesstask: varTask,
        bcr_eventtype: 'Event Type (bcr_eventtype)'.SMEInProgress,
        bcr_eventat: Now(),
        bcr_notes: "Task marked in progress by " & varCurrentUser.FullName
    }
);

// ---------- My Tasks gallery filter/sort ----------
SortByColumns(
    Filter(
        bcr_readinesstasks,
        bcr_assignedto.'Primary Email' = varCurrentUser.Email &&
        (
            ddTaskStatusFilter.Selected.Value = "All" ||
            Text(bcr_status) = ddTaskStatusFilter.Selected.Value
        )
    ),
    "bcr_duedate",
    SortOrder.Ascending
)

// ---------- Task Detail save draft ----------
// btnSaveDraft.OnSelect
Set(varErrorText, Blank());
Patch(
    bcr_readinesstasks,
    varTask,
    {
        bcr_status: 'Status (bcr_status)'.InProgress,
        bcr_requiredfieldschecklist: cmbChecklist.SelectedItems,
        bcr_readinesssummary: txtReadinessSummary.Text,
        bcr_submissionnotes: txtSubmissionNotes.Text,
        bcr_targetcommercialstart: dpTargetStart.SelectedDate
    }
);
Notify("Task saved.", NotificationType.Success);

// ---------- Validation function pattern before submit ----------
Set(
    varMissing,
    Concat(
        Filter(
            Table(
                {Field: "Readiness summary", Missing: IsBlank(Trim(txtReadinessSummary.Text))},
                {Field: "Checklist", Missing: CountRows(cmbChecklist.SelectedItems) < 4},
                {Field: "Target commercial start", Missing: IsBlank(dpTargetStart.SelectedDate)}
            ),
            Missing
        ),
        Field,
        ", "
    )
);

If(
    !IsBlank(varMissing),
    Set(varErrorText, "Please complete: " & varMissing);
    Notify(varErrorText, NotificationType.Error),
    Patch(
        bcr_readinesstasks,
        varTask,
        {
            bcr_status: 'Status (bcr_status)'.Submitted,
            bcr_requiredfieldschecklist: cmbChecklist.SelectedItems,
            bcr_readinesssummary: txtReadinessSummary.Text,
            bcr_submissionnotes: txtSubmissionNotes.Text,
            bcr_submittedat: Now(),
            bcr_rejectionreason: Blank()
        }
    );
    Notify("Task submitted for Pillar Lead validation.", NotificationType.Success)
);

// ---------- Submit button display mode ----------
If(
    IsBlank(Trim(txtReadinessSummary.Text)) || CountRows(cmbChecklist.SelectedItems) < 4,
    DisplayMode.Disabled,
    DisplayMode.Edit
)

// ---------- Add Purchase Order ----------
// btnAddPO.OnSelect
Set(varErrorText, Blank());
If(
    IsBlank(ddSupplier.Selected) || IsBlank(txtPONumber.Text) || IsBlank(Value(txtPOAmount.Text)),
    Notify("Supplier, PO Number and Amount are required.", NotificationType.Error),
    Set(
        varNewPO,
        Patch(
            bcr_purchaseorders,
            Defaults(bcr_purchaseorders),
            {
                bcr_budgetline: varBudgetLine,
                bcr_supplier: ddSupplier.Selected,
                bcr_ponumber: Upper(Trim(txtPONumber.Text)),
                bcr_podate: dpPODate.SelectedDate,
                bcr_amount: Value(txtPOAmount.Text),
                transactioncurrencyid: varBudgetLine.transactioncurrencyid,
                bcr_notes: txtPONotes.Text
            }
        )
    );
    Patch(
        bcr_budgetlines,
        varBudgetLine,
        {
            bcr_last_event_type: 'Last Event Type (bcr_last_event_type)'.PORecorded,
            bcr_last_event_at: Now()
        }
    );
    Patch(
        bcr_eventlogs,
        Defaults(bcr_eventlogs),
        {
            bcr_eventname: "PORecorded - " & varBudgetLine.bcr_budgetlinekey & " - " & Text(Now(), "[$-en-US]yyyy-mm-dd hh:mm:ss"),
            bcr_budgetline: varBudgetLine,
            bcr_eventtype: 'Event Type (bcr_eventtype)'.PORecorded,
            bcr_eventat: Now(),
            bcr_notes: "PO " & Upper(Trim(txtPONumber.Text)) & " added in app"
        }
    );
    Notify("Purchase Order recorded.", NotificationType.Success);
    Reset(txtPONumber); Reset(txtPOAmount); Reset(txtPONotes); Refresh(bcr_purchaseorders)
);

// ---------- Derived stage display with manual override ----------
With(
    {
        stageText: Coalesce(
            Text(varBudgetLine.bcr_manualstageoverride),
            Text(varBudgetLine.bcr_derivedstage)
        )
    },
    If(
        !IsBlank(varBudgetLine.bcr_manualstageoverride),
        stageText & " (Manual Override)",
        stageText
    )
)
