namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;
using Microsoft.Sales.History;

page 70631071 SubBillingStatus003SKC
{
    PageType = Card;
    SourceTable = "Subscription Line";
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    Caption = 'Billing Status';
    DataCaptionExpression = Rec.Description;

    layout
    {
        area(Content)
        {
            group(SubscriptionInfo)
            {
                Caption = 'Subscription Line';

                field(EntryNo; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    Caption = 'Entry No.';
                    ToolTip = 'The unique entry number of the subscription line.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Description';
                    ToolTip = 'Description of the subscription line.';
                }
                field(Status; StatusText)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    ToolTip = 'Current status of the subscription line.';
                    StyleExpr = StatusStyle;
                }
                field(AutoRenewal; Rec.AutoRenewal003SKC)
                {
                    ApplicationArea = All;
                    Caption = 'Auto-Renewal';
                    ToolTip = 'Whether the subscription auto-renews.';
                }
            }
            group(InvoicingStatus)
            {
                Caption = 'Invoicing Status';

                field(FullyInvoiced; FullyInvoicedText)
                {
                    ApplicationArea = All;
                    Caption = 'Fully Invoiced';
                    ToolTip = 'Indicates whether all billing through the end date has been invoiced. This must be true for auto-close to trigger.';
                    StyleExpr = FullyInvoicedStyle;
                }
                field(ReasonNotInvoiced; ReasonText)
                {
                    ApplicationArea = All;
                    Caption = 'Reason';
                    ToolTip = 'Explains why the line is not yet fully invoiced.';
                    Visible = ShowReasonField;
                }
                field(OpenBillingLines; OpenBillingLinesText)
                {
                    ApplicationArea = All;
                    Caption = 'Open Billing Lines';
                    ToolTip = 'Whether open billing lines (billing proposal or unposted document) exist for this subscription line.';
                }
                field(ExpectedEndDate; ExpectedEndDateValue)
                {
                    ApplicationArea = All;
                    Caption = 'Expected End Date for Close';
                    ToolTip = 'The end date that aligns with Next Billing Date for auto-close (= Next Billing Date - 1 day).';
                }
            }
            group(BillingSchedule)
            {
                Caption = 'Billing Schedule';

                field(EndDate; Rec."Subscription Line End Date")
                {
                    ApplicationArea = All;
                    Caption = 'End Date';
                    ToolTip = 'The subscription line end date. Must match Expected End Date for the line to be considered fully invoiced.';
                }
                field(DaysUntilAutoClose; DaysUntilCloseText)
                {
                    ApplicationArea = All;
                    Caption = 'Days Until Auto-Close';
                    ToolTip = 'How many days until this line will be automatically closed by the Update Subscription Line Dates batch.';
                    StyleExpr = DaysUntilCloseStyle;
                }
                field(NextBillingDate; Rec."Next Billing Date")
                {
                    ApplicationArea = All;
                    Caption = 'Next Billing Date';
                    ToolTip = 'The date of the next billing.';
                }
                field(NextBillingAmount; NextBillingAmountValue)
                {
                    ApplicationArea = All;
                    Caption = 'Next Invoice Amount';
                    ToolTip = 'Projected invoice amount for the next billing period.';
                    BlankZero = true;
                    DecimalPlaces = 2 : 2;
                }
                field(BillingCoveredThrough; BillingCoveredThroughDate)
                {
                    ApplicationArea = All;
                    Caption = 'Billed Through';
                    ToolTip = 'The latest billing period end date covered by posted invoices.';
                }
            }
            group(LastInvoiceInfo)
            {
                Caption = 'Last Invoice';

                field(LastDocumentNo; LastDocNo)
                {
                    ApplicationArea = All;
                    Caption = 'Document No.';
                    ToolTip = 'The document number of the last posted invoice.';

                    trigger OnDrillDown()
                    begin
                        DrillDownLastDocument();
                    end;
                }
                field(LastPostingDate; LastPostDate)
                {
                    ApplicationArea = All;
                    Caption = 'Posting Date';
                    ToolTip = 'The posting date of the last invoice.';
                }
                field(LastAmount; LastBilledAmount)
                {
                    ApplicationArea = All;
                    Caption = 'Amount';
                    ToolTip = 'The amount of the last invoice for this subscription line.';
                    BlankZero = true;
                    DecimalPlaces = 2 : 2;
                }
                field(LastBillingPeriod; LastBillingPeriodText)
                {
                    ApplicationArea = All;
                    Caption = 'Billing Period';
                    ToolTip = 'The billing period covered by the last invoice.';
                }
            }
            group(BillingTotals)
            {
                Caption = 'Totals';

                field(TotalBilled; TotalBilledAmount)
                {
                    ApplicationArea = All;
                    Caption = 'Total Billed (Net)';
                    ToolTip = 'Net total billed for this subscription line (invoices minus credit memos).';
                    DecimalPlaces = 2 : 2;
                }
                field(InvoiceCount; InvoiceCountValue)
                {
                    ApplicationArea = All;
                    Caption = 'No. of Invoices';
                    ToolTip = 'Number of posted invoices for this subscription line.';
                }
                field(CreditMemoCount; CreditMemoCountValue)
                {
                    ApplicationArea = All;
                    Caption = 'No. of Credit Memos';
                    ToolTip = 'Number of posted credit memos for this subscription line.';
                    Visible = ShowCreditMemos;
                }
            }
            part(BillingHistoryPart; SubBillingHistory003SKC)
            {
                ApplicationArea = All;
                Caption = 'Billing History';
                SubPageLink = "Subscription Line Entry No." = field("Entry No.");
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        ComputeStatus();
        ComputeInvoicingStatus();
        ComputeNextBillingAmount();
        ComputeBillingHistory();
        ComputeDaysUntilClose();
    end;

    local procedure ComputeStatus()
    begin
        if Rec.Closed then begin
            StatusText := ClosedLbl;
            StatusStyle := 'Unfavorable';
        end else
            if Rec."Subscription Line End Date" <> 0D then begin
                StatusText := ScheduledForCloseLbl;
                StatusStyle := 'Ambiguous';
            end else begin
                StatusText := ActiveLbl;
                StatusStyle := 'Favorable';
            end;
    end;

    local procedure ComputeInvoicingStatus()
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.SetRange("Subscription Line Entry No.", Rec."Entry No.");
        OpenBillingLinesExist := not BillingLine.IsEmpty();

        if Rec."Next Billing Date" <> 0D then
            ExpectedEndDateValue := CalcDate('<-1D>', Rec."Next Billing Date")
        else
            ExpectedEndDateValue := 0D;

        IsFullyInvoiced := not OpenBillingLinesExist
            and (Rec."Next Billing Date" <> 0D)
            and (Rec."Subscription Line End Date" <> 0D)
            and (Rec."Subscription Line End Date" = ExpectedEndDateValue);

        if IsFullyInvoiced then begin
            FullyInvoicedText := YesLbl;
            FullyInvoicedStyle := 'Favorable';
            ReasonText := '';
            ShowReasonField := false;
        end else begin
            FullyInvoicedText := NoLbl;
            FullyInvoicedStyle := 'Unfavorable';
            ReasonText := GetNotFullyInvoicedReason();
            ShowReasonField := true;
        end;

        if OpenBillingLinesExist then
            OpenBillingLinesText := YesOpenBillingLbl
        else
            OpenBillingLinesText := NoOpenBillingLbl;
    end;

    local procedure GetNotFullyInvoicedReason(): Text
    begin
        if OpenBillingLinesExist then
            exit(ReasonOpenBillingLinesLbl);
        if Rec."Next Billing Date" = 0D then
            exit(ReasonNoNextBillingDateLbl);
        if Rec."Subscription Line End Date" = 0D then
            exit(ReasonNoEndDateLbl);
        if Rec."Subscription Line End Date" <> ExpectedEndDateValue then
            exit(StrSubstNo(ReasonEndDateMismatchLbl, Rec."Subscription Line End Date", ExpectedEndDateValue));
    end;

    local procedure ComputeNextBillingAmount()
    var
        CalcPreview: Codeunit SubInvoicePreviewCalc003SKC;
    begin
        NextBillingAmountValue := CalcPreview.CalcNextInvoiceAmount(
            Rec."Billing Base Period", Rec."Billing Rhythm", Rec.Amount);
    end;

    local procedure ComputeBillingHistory()
    var
        BillingArchive: Record "Billing Line Archive";
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        TotalBilledAmount := 0;
        InvoiceCountValue := 0;
        CreditMemoCountValue := 0;
        BillingCoveredThroughDate := 0D;
        LastDocNo := '';
        LastPostDate := 0D;
        LastBilledAmount := 0;
        LastBillingPeriodText := '';

        BillingArchive.SetRange("Subscription Line Entry No.", Rec."Entry No.");
        BillingArchive.SetLoadFields("Document Type", "Document No.", Amount, "Billing from", "Billing to");
        if not BillingArchive.FindSet() then begin
            ShowCreditMemos := false;
            exit;
        end;

        repeat
            case BillingArchive."Document Type" of
                BillingArchive."Document Type"::Invoice:
                    begin
                        TotalBilledAmount += BillingArchive.Amount;
                        InvoiceCountValue += 1;
                        if BillingArchive."Billing to" > BillingCoveredThroughDate then
                            BillingCoveredThroughDate := BillingArchive."Billing to";
                    end;
                BillingArchive."Document Type"::"Credit Memo":
                    begin
                        TotalBilledAmount -= BillingArchive.Amount;
                        CreditMemoCountValue += 1;
                    end;
            end;
        until BillingArchive.Next() = 0;

        ShowCreditMemos := CreditMemoCountValue > 0;

        BillingArchive.SetRange("Document Type", BillingArchive."Document Type"::Invoice);
        if BillingArchive.FindLast() then begin
            LastDocNo := BillingArchive."Document No.";
            LastBilledAmount := BillingArchive.Amount;
            LastBillingPeriodText := StrSubstNo(BillingPeriodFormatLbl, BillingArchive."Billing from", BillingArchive."Billing to");
            if BillingArchive."Document No." <> '' then begin
                SalesInvHeader.SetLoadFields("Posting Date");
                if SalesInvHeader.Get(BillingArchive."Document No.") then
                    LastPostDate := SalesInvHeader."Posting Date";
            end;
        end;
    end;

    local procedure ComputeDaysUntilClose()
    var
        DaysRemaining: Integer;
    begin
        if Rec.Closed then begin
            DaysUntilCloseText := AlreadyClosedLbl;
            DaysUntilCloseStyle := 'Unfavorable';
            exit;
        end;

        if Rec."Subscription Line End Date" = 0D then begin
            DaysUntilCloseText := NoEndDateSetLbl;
            DaysUntilCloseStyle := 'Standard';
            exit;
        end;

        DaysRemaining := Rec."Subscription Line End Date" - Today;
        if DaysRemaining < 0 then begin
            if IsFullyInvoiced then begin
                DaysUntilCloseText := ReadyToCloseLbl;
                DaysUntilCloseStyle := 'Attention';
            end else begin
                DaysUntilCloseText := EndDatePassedPendingLbl;
                DaysUntilCloseStyle := 'Ambiguous';
            end;
        end else
            if DaysRemaining = 0 then begin
                DaysUntilCloseText := ClosesTodayLbl;
                DaysUntilCloseStyle := 'Attention';
            end else begin
                DaysUntilCloseText := StrSubstNo(DaysRemainingLbl, DaysRemaining);
                if DaysRemaining <= 30 then
                    DaysUntilCloseStyle := 'Ambiguous'
                else
                    DaysUntilCloseStyle := 'Favorable';
            end;
    end;

    local procedure DrillDownLastDocument()
    var
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        if LastDocNo = '' then
            exit;

        if SalesInvHeader.Get(LastDocNo) then
            Page.Run(Page::"Posted Sales Invoice", SalesInvHeader);
    end;

    var
        StatusText: Text;
        StatusStyle: Text;
        FullyInvoicedText: Text;
        FullyInvoicedStyle: Text;
        ReasonText: Text;
        OpenBillingLinesText: Text;
        OpenBillingLinesExist: Boolean;
        IsFullyInvoiced: Boolean;
        ShowReasonField: Boolean;
        ShowCreditMemos: Boolean;
        ExpectedEndDateValue: Date;
        NextBillingAmountValue: Decimal;
        BillingCoveredThroughDate: Date;
        DaysUntilCloseText: Text;
        DaysUntilCloseStyle: Text;
        LastDocNo: Code[20];
        LastPostDate: Date;
        LastBilledAmount: Decimal;
        LastBillingPeriodText: Text;
        TotalBilledAmount: Decimal;
        InvoiceCountValue: Integer;
        CreditMemoCountValue: Integer;
        ActiveLbl: Label 'Active', Comment = 'Subscription status: active';
        ClosedLbl: Label 'Closed', Comment = 'Subscription status: closed';
        ScheduledForCloseLbl: Label 'Scheduled for Close', Comment = 'Subscription status: scheduled for closure';
        YesLbl: Label 'Yes', Comment = 'Boolean display value';
        NoLbl: Label 'No', Comment = 'Boolean display value';
        YesOpenBillingLbl: Label 'Yes (billing proposal or unposted document)', Comment = 'Indicates open billing lines exist';
        NoOpenBillingLbl: Label 'No', Comment = 'Indicates no open billing lines';
        ReasonOpenBillingLinesLbl: Label 'Open billing lines exist (billing proposal or unposted document)', Comment = 'Reason subscription is not fully invoiced';
        ReasonNoNextBillingDateLbl: Label 'No Next Billing Date is set', Comment = 'Reason subscription is not fully invoiced';
        ReasonNoEndDateLbl: Label 'No end date is set', Comment = 'Reason subscription is not fully invoiced';
        ReasonEndDateMismatchLbl: Label 'End date (%1) does not match expected (%2 = Next Billing Date - 1 day)', Comment = '%1 = Actual End Date, %2 = Expected End Date';
        NoEndDateSetLbl: Label 'No end date set', Comment = 'Days until close display value';
        AlreadyClosedLbl: Label 'Already closed', Comment = 'Days until close display value';
        ReadyToCloseLbl: Label 'Ready to close (next batch run)', Comment = 'Days until close display value';
        EndDatePassedPendingLbl: Label 'End date passed, pending invoicing', Comment = 'Days until close display value';
        ClosesTodayLbl: Label 'End date is today', Comment = 'Days until close display value';
        DaysRemainingLbl: Label '%1 day(s)', Comment = '%1 = Number of days remaining';
        BillingPeriodFormatLbl: Label '%1 .. %2', Comment = '%1 = Start Date, %2 = End Date', Locked = true;
}
