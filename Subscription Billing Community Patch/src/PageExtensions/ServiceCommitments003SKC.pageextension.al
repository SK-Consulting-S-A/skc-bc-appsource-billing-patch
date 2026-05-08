namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631091 ServiceCommitments003SKC extends "Service Commitments"
{
    layout
    {
        modify("Next Billing Date")
        {
            Visible = false;
        }
        addafter("Next Billing Date")
        {
            field(NextBillingDateEdit003SKC; NextBillingDateEditable)
            {
                ApplicationArea = All;
                Caption = 'Next Billing Date';
                ToolTip = 'Specifies the date of the next billing possible. This field has been made editable for migration data fixes only.';
                StyleExpr = NextBillingDateStyle;

                trigger OnValidate()
                begin
                    if NextBillingDateEditable = Rec."Next Billing Date" then
                        exit;
                    if NextBillingDateEditable = 0D then
                        Error(EmptyDateErr);
                    if (Rec."Subscription Line Start Date" <> 0D) and (NextBillingDateEditable < Rec."Subscription Line Start Date") then
                        Error(BeforeStartDateErr, Rec.FieldCaption("Subscription Line Start Date"), Rec."Subscription Line Start Date");
                    if not Confirm(NextBillingDateWarningMsg, false,
                            Rec."Next Billing Date", NextBillingDateEditable,
                            Rec."Subscription Header No.", Rec."Entry No.") then begin
                        NextBillingDateEditable := Rec."Next Billing Date";
                        exit;
                    end;
                    Rec."Next Billing Date" := NextBillingDateEditable;
                    Rec.Modify(false);
                    CurrPage.Update(false);
                end;
            }
        }
        addafter("Service Amount")
        {
            field(NextInvoiceAmount003SKC; NextInvoiceAmount)
            {
                ApplicationArea = All;
                Caption = 'Next Invoice Amount';
                ToolTip = 'Projected amount for the next regular invoice, based on Billing Base Period, Billing Rhythm, and the current line amount.';
                Editable = false;
                BlankZero = true;
                DecimalPlaces = 2 : 2;
            }
        }
        addafter("Initial Term")
        {
            field(AutoRenewal003SKC; Rec.AutoRenewal003SKC)
            {
                ApplicationArea = All;
                Caption = 'Auto-Renewal';
                ToolTip = 'When enabled, the subscription automatically renews using the Subsequent Term Backup. When disabled, the Extension Term is cleared and the subscription ends at Term Until.';
            }
            field(ExtensionTermBackup003SKC; Rec.ExtensionTermBackup003SKC)
            {
                ApplicationArea = All;
                Caption = 'Subsequent Term Backup';
                ToolTip = 'Backs up the Extension Term value while Auto-Renewal is disabled. Restored as Extension Term when Auto-Renewal is re-enabled.';
            }
        }
        modify("Service End Date")
        {
            Editable = false;
        }
        modify("Extension Term")
        {
            Editable = false;
        }
        modify("Notice Period")
        {
            Visible = true;
        }
        movebefore("Cancellation Possible Until"; "Notice Period")
    }

    actions
    {
        addlast(processing)
        {
            action(SetEndDate003SKC)
            {
                ApplicationArea = All;
                Caption = 'Set End Date';
                Image = CalcWorkCenterCalendar;
                ToolTip = 'Sets the Subscription Line End Date to one day before the Next Billing Date, which is the correct date for automatic closing.';

                trigger OnAction()
                begin
                    SetEndDateAligned();
                end;
            }
            action(CancelSubLine003SKC)
            {
                ApplicationArea = All;
                Caption = 'Cancel Subscription Line';
                Image = Cancel;
                ToolTip = 'Cancels the selected subscription line by setting the end date to Term Until and disabling auto-renewal.';

                trigger OnAction()
                begin
                    CancelSubscriptionLine();
                end;
            }
            action(ReopenSubLine003SKC)
            {
                ApplicationArea = All;
                Caption = 'Reopen Subscription Line';
                Image = ReOpen;
                ToolTip = 'Reopens a closed subscription line by clearing the end date and restoring Term Until. Also clears the end date on non-closed lines.';

                trigger OnAction()
                begin
                    ReopenOrClearEndDate();
                end;
            }
            action(ShowBillingStatus003SKC)
            {
                ApplicationArea = All;
                Caption = 'Show Billing Status';
                Image = ViewDetails;
                ToolTip = 'Shows detailed billing status, invoicing information, and billing history for the selected subscription line.';

                trigger OnAction()
                var
                    SubLine: Record "Subscription Line";
                begin
                    SubLine.Get(Rec."Entry No.");
                    Page.RunModal(Page::SubBillingStatus003SKC, SubLine);
                end;
            }
            action(OpenContract003SKC)
            {
                ApplicationArea = All;
                Caption = 'Open Contract';
                Image = Document;
                ToolTip = 'Opens the linked customer subscription contract for the selected subscription line.';

                trigger OnAction()
                var
                    CustSubContract: Record "Customer Subscription Contract";
                begin
                    if Rec."Subscription Contract No." = '' then
                        Error(NoContractLinkedErr);
                    CustSubContract.Get(Rec."Subscription Contract No.");
                    Page.Run(Page::"Customer Contract", CustSubContract);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        NextBillingDateEditable := Rec."Next Billing Date";
        NextBillingDateStyle := '';
        NextInvoiceAmount := CalcPreviewCalc.CalcNextInvoiceAmount(
            Rec."Billing Base Period",
            Rec."Billing Rhythm",
            Rec.Amount);
    end;

    local procedure SetEndDateAligned()
    var
        EndDate: Date;
    begin
        if Rec.Closed then
            Error(AlreadyClosedErr);
        if Rec."Next Billing Date" = 0D then
            Error(NoNextBillingDateErr);

        EndDate := CalcDate('<-1D>', Rec."Next Billing Date");
        if Rec."Subscription Line End Date" = EndDate then begin
            Message(EndDateAlreadyCorrectMsg, EndDate);
            exit;
        end;

        if not Confirm(ConfirmSetEndDateMsg, false, Rec."Entry No.", Rec.Description, EndDate) then
            exit;

        Rec.Validate("Subscription Line End Date", EndDate);
        Rec.Modify(true);
        CurrPage.Update(false);
        Message(EndDateSetMsg, Rec."Entry No.", EndDate);
    end;

    local procedure CancelSubscriptionLine()
    begin
        if Rec.Closed then
            Error(AlreadyClosedErr);
        if Rec."Subscription Line End Date" <> 0D then
            Error(AlreadyCancelledErr);
        if Rec."Term Until" = 0D then
            Error(NoTermUntilErr);
        if (Rec."Cancellation Possible Until" <> 0D) and (Today > Rec."Cancellation Possible Until") then
            Error(CancellationDeadlinePassedErr, Rec."Cancellation Possible Until");

        if not Confirm(ConfirmCancelMsg, false,
                Rec."Entry No.", Rec.Description, Rec."Term Until") then
            exit;

        if Rec.AutoRenewal003SKC then
            Rec.Validate(AutoRenewal003SKC, false)
        else
            Rec.Validate("Subscription Line End Date", Rec."Term Until");
        Rec.Modify(true);
        CurrPage.Update(false);
        Message(CancelCompletedMsg, Rec."Entry No.", Rec."Term Until");
    end;

    local procedure ReopenOrClearEndDate()
    var
        SubAutoReopen: Codeunit SubAutoReopen003SKC;
    begin
        if Rec.Closed then begin
            if not Confirm(ConfirmReopenMsg, false, Rec."Entry No.", Rec.Description) then
                exit;

            SubAutoReopen.ReopenSubscriptionLine(Rec, Rec.TermUntilBackup003SKC);
            SubAutoReopen.ReopenContractLinesForSubscription(Rec);
            CurrPage.Update(false);
            Message(ReopenCompletedMsg, Rec."Entry No.");
        end else begin
            if Rec."Subscription Line End Date" = 0D then
                Error(NoEndDateToClearErr);

            if not Confirm(ConfirmClearEndDateMsg, false, Rec."Entry No.", Rec.Description) then
                exit;

            Rec.Validate("Subscription Line End Date", 0D);
            Rec.Modify(true);
            CurrPage.Update(false);
            Message(EndDateClearedMsg, Rec."Entry No.");
        end;
    end;

    var
        CalcPreviewCalc: Codeunit SubInvoicePreviewCalc003SKC;
        NextInvoiceAmount: Decimal;
        NextBillingDateEditable: Date;
        NextBillingDateStyle: Text;
        NextBillingDateWarningMsg: Label 'You are about to manually change the Next Billing Date from %1 to %2 on Subscription %3, Line %4.\\This can cause billing inconsistencies and should only be used to fix migration data issues.\\Do you want to continue?', Comment = '%1 = Old Date, %2 = New Date, %3 = Subscription No., %4 = Entry No.';
        EmptyDateErr: Label 'The Next Billing Date cannot be empty.', Comment = 'Error when user clears the date';
        BeforeStartDateErr: Label 'The Next Billing Date cannot be before the %1 (%2).', Comment = '%1 = Field Caption, %2 = Date Value';
        AlreadyClosedErr: Label 'This subscription line is already closed.', Comment = 'Error when cancelling a closed line';
        AlreadyCancelledErr: Label 'This subscription line already has an end date set.', Comment = 'Error when cancelling a line with end date';
        NoTermUntilErr: Label 'Cannot cancel: no Term Until date is set on this subscription line.', Comment = 'Error when Term Until is missing';
        CancellationDeadlinePassedErr: Label 'Cancellation is no longer possible. The cancellation deadline was %1.', Comment = '%1 = Cancellation Possible Until date';
        ConfirmCancelMsg: Label 'This will end subscription line %1 (%2) at %3 and disable auto-renewal.\\Do you want to continue?', Comment = '%1 = Entry No., %2 = Description, %3 = Term Until';
        CancelCompletedMsg: Label 'Subscription line %1 scheduled for cancellation at %2.', Comment = '%1 = Entry No., %2 = End Date';
        NoNextBillingDateErr: Label 'Cannot set end date: no Next Billing Date is set on this subscription line.', Comment = 'Error when Next Billing Date is missing';
        EndDateAlreadyCorrectMsg: Label 'The end date is already set to %1.', Comment = '%1 = End Date';
        ConfirmSetEndDateMsg: Label 'This will set the end date of subscription line %1 (%2) to %3 (one day before the Next Billing Date).\\Do you want to continue?', Comment = '%1 = Entry No., %2 = Description, %3 = End Date';
        EndDateSetMsg: Label 'End date for subscription line %1 set to %2.', Comment = '%1 = Entry No., %2 = End Date';
        ConfirmReopenMsg: Label 'This will reopen subscription line %1 (%2) and clear the end date.\\Do you want to continue?', Comment = '%1 = Entry No., %2 = Description';
        ReopenCompletedMsg: Label 'Subscription line %1 has been reopened.', Comment = '%1 = Entry No.';
        NoEndDateToClearErr: Label 'This subscription line has no end date to clear.', Comment = 'Error when clearing a non-existent end date';
        ConfirmClearEndDateMsg: Label 'This will clear the end date on subscription line %1 (%2), making it bill indefinitely.\\Do you want to continue?', Comment = '%1 = Entry No., %2 = Description';
        EndDateClearedMsg: Label 'End date cleared for subscription line %1.', Comment = '%1 = Entry No.';
        NoContractLinkedErr: Label 'No customer contract is linked to this subscription line.', Comment = 'Error when no contract is linked';
}
