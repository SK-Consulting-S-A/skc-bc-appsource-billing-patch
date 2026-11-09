namespace SKC.Subscription;

using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Sales.Posting;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Keeps Next Billing Date on the periods other invoices still cover when a posted contract
/// invoice is cancelled or corrected.
///
/// Subscription Billing sets Next Billing Date back to the credited period's Billing from as
/// soon as the corrective credit memo is created. Cancelling an interim seat charge inside a
/// three-year invoice moved the line from the end of the three years back to the interim
/// window start, and the next billing run would have invoiced every seat for a new term.
///
/// Once the credit memo is posted, every subscription line on it is measured against the
/// remaining billing archive (net-billed periods only, the cancelled invoice and the credit
/// memos that correct it left out, interim seat charges not counted as period coverage):
/// - other invoices still bill past the reset date: Next Billing Date becomes the day after
///   that billed-through date (never later than before the cancel), without a question;
/// - nothing else covers the cancelled period: the client asks whether to bill it again (Yes
///   keeps the standard reset, No restores the date read before the cancel). API and
///   background sessions keep the standard reset unless the caller decided explicitly
///   (apiContractInvCancel085SKC cancelWithRebill).
///
/// Single instance so the dates read before the credit memo is created are still there when
/// it is posted. Nothing else outlives its operation:
/// - a cancel runs from StartCancel (API) or OnBeforeCreateCorrectiveSalesCrMemo (client
///   Cancel / Correct) to FinishCancel or ReapplyAfterCancel; only inside it are the dates
///   decided at posting kept for re-applying, a credit memo posted outside one drops them as
///   soon as it is processed;
/// - a processed credit memo drops the saved date of every subscription line it covered;
/// - every credit memo being built is a capture operation of its own, so a date saved for an
///   earlier, deleted or abandoned draft is read again instead of being reused, and a date read
///   for another credit memo is not used when this one is posted.
/// </summary>
codeunit 70631072 SubCancelNbdGuard085SKC
{
    Access = Internal;
    SingleInstance = true;
    Permissions =
        tabledata "Billing Line" = R,
        tabledata "Billing Line Archive" = R,
        tabledata "Sales Cr.Memo Line" = R,
        tabledata SubQuantityHistory085SKC = R,
        tabledata "Subscription Line" = RM;

    var
        OperationCreditMemos: Dictionary of [Integer, Code[20]];
        ResetNextBillingDates: Dictionary of [Integer, Date];
        SavedCaptureOperations: Dictionary of [Integer, Integer];
        SavedNextBillingDates: Dictionary of [Integer, Date];
        TargetNextBillingDates: Dictionary of [Integer, Date];
        Results: List of [Text];
        CaptureCreditMemoNo: Code[20];
        ExplicitInvoiceNo: Code[20];
        CaptureOperationNo: Integer;
        ApiCancelActive: Boolean;
        CancelInProgress: Boolean;
        CaptureCreditMemoPending: Boolean;
        ExplicitRebill: Boolean;
        KeptCoverageInfoMsg: Label 'Other invoices still cover the cancelled period, so Next Billing Date was not moved back:\%1', Comment = '%1 = one sentence per subscription line';
        KeptCoverageMsg: Label 'Line %1: Next Billing Date kept at %2 (billed through %3 by other invoices).', Comment = '%1 = subscription line entry number, %2 = Next Billing Date, %3 = date the other invoices bill through';
        NbdChangedTelemetryTxt: Label 'Next Billing Date of subscription line %1 changed from %2 to %3 after invoice %4 was cancelled.', Locked = true;
        OpenBillingLinesMsg: Label 'Line %1: Next Billing Date left at %2 because the line has open billing lines.', Comment = '%1 = subscription line entry number, %2 = Next Billing Date';
        RebillMsg: Label 'Line %1: Next Billing Date stays at %2, so %3..%4 is billed again.', Comment = '%1 = subscription line entry number, %2 = Next Billing Date, %3 = start of the cancelled period, %4 = end of the cancelled period';
        RebillQst: Label 'Subscription line %1: no other invoice covers %2..%3 once %4 is cancelled.\\Should the next billing run invoice this period again?\Yes: Next Billing Date stays at %5.\No: Next Billing Date goes back to %6.', Comment = '%1 = subscription line entry number, %2 = start of the cancelled period, %3 = end of the cancelled period, %4 = cancelled invoice number, %5 = Next Billing Date after the cancel, %6 = Next Billing Date before the cancel';
        ResetStandsMsg: Label 'Line %1: Next Billing Date stays at %2.', Comment = '%1 = subscription line entry number, %2 = Next Billing Date';
        RestoredMsg: Label 'Line %1: Next Billing Date restored to %2, so %3..%4 is not billed again.', Comment = '%1 = subscription line entry number, %2 = Next Billing Date, %3 = start of the cancelled period, %4 = end of the cancelled period';

    #region API

    /// <summary>
    /// Called by the API before it cancels PostedInvoiceNo. With ChoiceGiven, Rebill answers
    /// the question the client asks when nothing else covers the cancelled period (true keeps
    /// the standard reset, false restores the earlier date). Without it the standard reset is
    /// kept, as the API always did.
    /// </summary>
    procedure StartCancel(PostedInvoiceNo: Code[20]; ChoiceGiven: Boolean; Rebill: Boolean)
    begin
        ResetState();
        Clear(SavedNextBillingDates);
        Clear(SavedCaptureOperations);
        Clear(OperationCreditMemos);
        BeginCancelOperation();
        ApiCancelActive := true;
        if ChoiceGiven then begin
            ExplicitInvoiceNo := PostedInvoiceNo;
            ExplicitRebill := Rebill;
        end;
    end;

    /// <summary>
    /// Re-applies the dates decided while the credit memo was posted, should anything have
    /// moved them back since, returns one sentence per subscription line, clears the state and
    /// ends the cancel operation.
    /// </summary>
    procedure FinishCancel() Summary: Text
    var
        ResultText: Text;
    begin
        ReapplyTargets();
        foreach ResultText in Results do
            if Summary = '' then
                Summary := ResultText
            else
                Summary += ' ' + ResultText;
        ResetState();
        EndCancelOperation();
    end;

    #endregion

    #region Event subscribers

    /// <summary>
    /// Start of a Cancel or Correct run, from the client or any other caller: raised by the run
    /// itself once the user has confirmed, before the credit memo is created (after StartCancel
    /// it only repeats what that did). OnAfterTestCorrectInvoiceIsAllowed comes earlier but also
    /// fires for the check the client makes before asking, which the user may decline, and
    /// would leave the operation open.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Correct Posted Sales Invoice", OnBeforeCreateCorrectiveSalesCrMemo, '', false, false)]
    local procedure StartCancelOperation()
    begin
        BeginCancelOperation();
    end;

    /// <summary>
    /// Start of Cancel, Correct and Create Corrective Credit Memo: nothing has been copied yet,
    /// so this is the Next Billing Date before Subscription Billing moves it back. It starts a
    /// capture operation that the first line copied into the new credit memo binds to.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Correct Posted Sales Invoice", OnBeforeSalesHeaderInsert, '', false, false)]
    local procedure CaptureBeforeCorrectiveCreditMemo(var SalesHeader: Record "Sales Header"; var SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        BillingLineArchive: Record "Billing Line Archive";
        SubscriptionLine: Record "Subscription Line";
    begin
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::"Credit Memo" then
            exit;
        if not SalesInvoiceHeader."Recurring Billing" then
            exit;
        if not (BillingLineArchive.ReadPermission() and SubscriptionLine.ReadPermission()) then
            exit;

        NewCaptureOperation();
        CaptureCreditMemoPending := true;
        BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
        BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::Invoice);
        BillingLineArchive.SetRange("Document No.", SalesInvoiceHeader."No.");
        BillingLineArchive.SetLoadFields("Subscription Line Entry No.");
        if BillingLineArchive.FindSet() then
            repeat
                SubscriptionLine.SetLoadFields("Next Billing Date");
                if SubscriptionLine.Get(BillingLineArchive."Subscription Line Entry No.") then
                    SaveNextBillingDate(BillingLineArchive."Subscription Line Entry No.", SubscriptionLine."Next Billing Date");
            until BillingLineArchive.Next() = 0;
    end;

    /// <summary>
    /// A posted invoice line is about to be copied into a document with its billing lines,
    /// before any of its dates is reset. Each credit memo being built is a capture operation of
    /// its own: the first line binds the operation the start of Cancel, Correct or Create
    /// Corrective Credit Memo opened to that credit memo, and a line of any other credit memo
    /// starts a new operation. The binding tells, when a credit memo is posted, which saved
    /// dates were read for it.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Billing Correction", OnBeforeCreateBillingLineFromBillingLineArchiveAfterInsertToSalesLine, '', false, false)]
    local procedure TrackCreditMemoBeingBuilt(var ToSalesLine: Record "Sales Line")
    begin
        if ToSalesLine.IsTemporary() then
            exit;
        if ToSalesLine."Document Type" <> ToSalesLine."Document Type"::"Credit Memo" then
            exit;
        if CaptureCreditMemoPending then begin
            CaptureCreditMemoPending := false;
            CaptureCreditMemoNo := ToSalesLine."Document No.";
            OperationCreditMemos.Set(CaptureOperationNo, CaptureCreditMemoNo);
            exit;
        end;
        if ToSalesLine."Document No." <> CaptureCreditMemoNo then begin
            NewCaptureOperation();
            CaptureCreditMemoNo := ToSalesLine."Document No.";
            OperationCreditMemos.Set(CaptureOperationNo, CaptureCreditMemoNo);
        end;
    end;

    /// <summary>
    /// Fallback for any other route into Subscription Billing's correction: read the date
    /// straight before the standard reset, unless the current operation already did (the start
    /// of Cancel, Correct or Create Corrective Credit Memo, or an earlier archive row of the same
    /// credit memo). A date saved in an earlier operation, e.g. for a draft that was deleted or
    /// abandoned, is read again.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Billing Correction", OnBeforeUpdateNextBillingDateInCreateBillingLineFromBillingLineArchive, '', false, false)]
    local procedure CaptureBeforeStandardReset(var SubscriptionLine: Record "Subscription Line")
    var
        StoredSubscriptionLine: Record "Subscription Line";
    begin
        if SubscriptionLine.IsTemporary() then
            exit;
        if SavedInCurrentOperation(SubscriptionLine."Entry No.") then
            exit;
        StoredSubscriptionLine.SetLoadFields("Next Billing Date");
        if StoredSubscriptionLine.Get(SubscriptionLine."Entry No.") then
            SaveNextBillingDate(SubscriptionLine."Entry No.", StoredSubscriptionLine."Next Billing Date");
    end;

    /// <summary>
    /// The credit memo is posted: decide the Next Billing Date of every subscription line it
    /// credits. Covers Cancel, Correct and a corrective credit memo posted later by hand. Outside
    /// a cancel operation nothing will re-apply the decided dates, so they are dropped here.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", OnAfterPostSalesDoc, '', false, false)]
    local procedure KeepCoverageAfterCreditMemo(var SalesHeader: Record "Sales Header"; SalesCrMemoHdrNo: Code[20]; PreviewMode: Boolean)
    begin
        if PreviewMode then
            exit;
        if SalesCrMemoHdrNo = '' then
            exit;
        if SalesHeader.IsTemporary() then
            exit;
        if not SalesHeader."Recurring Billing" then
            if SavedNextBillingDates.Count() = 0 then
                if not CreditMemoHasContractLines(SalesCrMemoHdrNo) then begin
                    DropTargetsOutsideCancel();
                    exit;
                end;

        ProcessCreditMemo(SalesHeader."No.", SalesCrMemoHdrNo);
        DropTargetsOutsideCancel();
    end;

    /// <summary>
    /// The cancel has finished, Sales-Post included. Puts back any date that something after
    /// the credit memo posting moved to the reset value again, and ends the cancel operation.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Correct Posted Sales Invoice", OnOnRunOnAfterUpdateSalesOrderLinesFromCancelledInvoice, '', false, false)]
    local procedure ReapplyAfterCancel()
    begin
        ReapplyTargets();
        EndCancelOperation();
    end;

    #endregion

    #region Decision

    local procedure ProcessCreditMemo(UnpostedCrMemoNo: Code[20]; PostedCrMemoNo: Code[20])
    var
        TempCreditedRow: Record "Billing Line Archive" temporary;
        CoveredEntryNos: List of [Integer];
        EntryNos: List of [Integer];
        KeptResults: List of [Text];
        SubLineEntryNo: Integer;
    begin
        Clear(TargetNextBillingDates);
        Clear(ResetNextBillingDates);

        CollectCreditedRows(UnpostedCrMemoNo, PostedCrMemoNo, TempCreditedRow, EntryNos);
        foreach SubLineEntryNo in EntryNos do
            ProcessSubscriptionLine(SubLineEntryNo, UnpostedCrMemoNo, TempCreditedRow, KeptResults);

        // Posted: no date read for one of its lines is needed any more, decided above or not.
        CollectCoveredLines(UnpostedCrMemoNo, PostedCrMemoNo, CoveredEntryNos);
        foreach SubLineEntryNo in CoveredEntryNos do
            ForgetSavedDate(SubLineEntryNo);

        ShowKeptCoverage(KeptResults);
    end;

    /// <summary>
    /// The credit memo rows that correct an invoice: from the archive under the posted number
    /// and, in case the archive move has not happened yet, from the credit memo's billing lines.
    /// </summary>
    local procedure CollectCreditedRows(UnpostedCrMemoNo: Code[20]; PostedCrMemoNo: Code[20]; var TempCreditedRow: Record "Billing Line Archive" temporary; var EntryNos: List of [Integer])
    var
        BillingLine: Record "Billing Line";
        BillingLineArchive: Record "Billing Line Archive";
        NextEntryNo: Integer;
    begin
        if BillingLineArchive.ReadPermission() then begin
            BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
            BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::"Credit Memo");
            BillingLineArchive.SetRange("Document No.", PostedCrMemoNo);
            BillingLineArchive.SetRange("Correction Document Type", BillingLineArchive."Correction Document Type"::Invoice);
            BillingLineArchive.SetFilter("Correction Document No.", '<>%1', '');
            BillingLineArchive.SetLoadFields("Subscription Line Entry No.", "Billing from", "Billing to", "Correction Document No.");
            if BillingLineArchive.FindSet() then
                repeat
                    AddCreditedRow(
                        TempCreditedRow, NextEntryNo, EntryNos, BillingLineArchive."Subscription Line Entry No.",
                        BillingLineArchive."Billing from", BillingLineArchive."Billing to", BillingLineArchive."Correction Document No.");
                until BillingLineArchive.Next() = 0;
        end;

        if UnpostedCrMemoNo = '' then
            exit;
        if not BillingLine.ReadPermission() then
            exit;
        BillingLine.SetRange(Partner, BillingLine.Partner::Customer);
        BillingLine.SetRange("Document Type", BillingLine."Document Type"::"Credit Memo");
        BillingLine.SetRange("Document No.", UnpostedCrMemoNo);
        BillingLine.SetRange("Correction Document Type", BillingLine."Correction Document Type"::Invoice);
        BillingLine.SetFilter("Correction Document No.", '<>%1', '');
        BillingLine.SetLoadFields("Subscription Line Entry No.", "Billing from", "Billing to", "Correction Document No.");
        if BillingLine.FindSet() then
            repeat
                AddCreditedRow(
                    TempCreditedRow, NextEntryNo, EntryNos, BillingLine."Subscription Line Entry No.",
                    BillingLine."Billing from", BillingLine."Billing to", BillingLine."Correction Document No.");
            until BillingLine.Next() = 0;
    end;

    local procedure AddCreditedRow(var TempCreditedRow: Record "Billing Line Archive" temporary; var NextEntryNo: Integer; var EntryNos: List of [Integer]; SubLineEntryNo: Integer; BillingFrom: Date; BillingTo: Date; InvoiceNo: Code[20])
    begin
        if SubLineEntryNo = 0 then
            exit;
        NextEntryNo += 1;
        TempCreditedRow.Init();
        TempCreditedRow."Entry No." := NextEntryNo;
        TempCreditedRow."Subscription Line Entry No." := SubLineEntryNo;
        TempCreditedRow."Billing from" := BillingFrom;
        TempCreditedRow."Billing to" := BillingTo;
        TempCreditedRow."Correction Document No." := InvoiceNo;
        TempCreditedRow.Insert(false);
        if not EntryNos.Contains(SubLineEntryNo) then
            EntryNos.Add(SubLineEntryNo);
    end;

    /// <summary>
    /// Every subscription line the credit memo covers, with or without correction reference:
    /// its customer archive rows under the posted number and, in case the archive move has not
    /// happened yet, its billing lines.
    /// </summary>
    local procedure CollectCoveredLines(UnpostedCrMemoNo: Code[20]; PostedCrMemoNo: Code[20]; var EntryNos: List of [Integer])
    var
        BillingLine: Record "Billing Line";
        BillingLineArchive: Record "Billing Line Archive";
    begin
        if BillingLineArchive.ReadPermission() then begin
            BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
            BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::"Credit Memo");
            BillingLineArchive.SetRange("Document No.", PostedCrMemoNo);
            BillingLineArchive.SetLoadFields("Subscription Line Entry No.");
            if BillingLineArchive.FindSet() then
                repeat
                    if not EntryNos.Contains(BillingLineArchive."Subscription Line Entry No.") then
                        EntryNos.Add(BillingLineArchive."Subscription Line Entry No.");
                until BillingLineArchive.Next() = 0;
        end;

        if UnpostedCrMemoNo = '' then
            exit;
        if not BillingLine.ReadPermission() then
            exit;
        BillingLine.SetRange(Partner, BillingLine.Partner::Customer);
        BillingLine.SetRange("Document Type", BillingLine."Document Type"::"Credit Memo");
        BillingLine.SetRange("Document No.", UnpostedCrMemoNo);
        BillingLine.SetLoadFields("Subscription Line Entry No.");
        if BillingLine.FindSet() then
            repeat
                if not EntryNos.Contains(BillingLine."Subscription Line Entry No.") then
                    EntryNos.Add(BillingLine."Subscription Line Entry No.");
            until BillingLine.Next() = 0;
    end;

    local procedure ProcessSubscriptionLine(SubLineEntryNo: Integer; UnpostedCrMemoNo: Code[20]; var TempCreditedRow: Record "Billing Line Archive" temporary; var KeptResults: List of [Text])
    var
        SubscriptionLine: Record "Subscription Line";
        InvoiceNo: Code[20];
        BilledThrough: Date;
        CancelledFrom: Date;
        CancelledTo: Date;
        ResetDate: Date;
        RestoreDate: Date;
        SavedDate: Date;
        TargetDate: Date;
        HasSavedDate: Boolean;
        ResultText: Text;
    begin
        // A date read for another credit memo (an abandoned draft) says nothing about this one.
        HasSavedDate := SavedNextBillingDates.Get(SubLineEntryNo, SavedDate);
        if HasSavedDate then begin
            if SavedForOtherCreditMemo(SubLineEntryNo, UnpostedCrMemoNo) then
                HasSavedDate := false;
            ForgetSavedDate(SubLineEntryNo);
        end;

        if not GetCancelledPeriod(SubLineEntryNo, TempCreditedRow, InvoiceNo, CancelledFrom, CancelledTo) then
            exit;
        if not SubscriptionLine.Get(SubLineEntryNo) then
            exit;
        if SubscriptionLine.Closed or (SubscriptionLine.Partner <> SubscriptionLine.Partner::Customer) then
            exit;
        ResetDate := SubscriptionLine."Next Billing Date";
        if ResetDate = 0D then
            exit;
        if not SubscriptionLine.WritePermission() then
            exit;
        if HasOtherOpenBillingLines(SubLineEntryNo) then begin
            AddResult(StrSubstNo(OpenBillingLinesMsg, SubLineEntryNo, ResetDate));
            exit;
        end;

        // Other invoices still bill past the reset date: keep that coverage, no question.
        // Never further than the line stood before the cancel, though: a date that was already
        // behind the archive (set back on purpose) is not pushed forward as a side effect.
        BilledThrough := GetBilledThroughByOtherInvoices(SubscriptionLine, InvoiceNo);
        if (BilledThrough <> 0D) and (BilledThrough >= ResetDate) then begin
            TargetDate := BilledThrough + 1;
            if HasSavedDate and (SavedDate < TargetDate) then
                if SavedDate > ResetDate then
                    TargetDate := SavedDate
                else
                    TargetDate := ResetDate;
            if TargetDate <= ResetDate then begin
                AddResult(StrSubstNo(ResetStandsMsg, SubLineEntryNo, ResetDate));
                exit;
            end;
            SetNextBillingDate(SubscriptionLine, TargetDate, ResetDate, InvoiceNo);
            ResultText := StrSubstNo(KeptCoverageMsg, SubLineEntryNo, TargetDate, BilledThrough);
            AddResult(ResultText);
            KeptResults.Add(ResultText);
            exit;
        end;

        // Nothing else covers the cancelled period: bill it again or put the earlier date back.
        RestoreDate := CancelledTo + 1;
        if HasSavedDate then
            RestoreDate := SavedDate;
        if RestoreDate <= ResetDate then begin
            AddResult(StrSubstNo(ResetStandsMsg, SubLineEntryNo, ResetDate));
            exit;
        end;

        if DecideRebill(InvoiceNo, SubLineEntryNo, CancelledFrom, CancelledTo, ResetDate, RestoreDate) then
            AddResult(StrSubstNo(RebillMsg, SubLineEntryNo, ResetDate, CancelledFrom, CancelledTo))
        else begin
            SetNextBillingDate(SubscriptionLine, RestoreDate, ResetDate, InvoiceNo);
            AddResult(StrSubstNo(RestoredMsg, SubLineEntryNo, RestoreDate, CancelledFrom, CancelledTo));
        end;
    end;

    /// <summary>
    /// The date the remaining invoices bill the line through: the latest Billing to of an
    /// invoice period that still nets to a charge once the cancelled invoice and the credit
    /// memos correcting it are left out (SubArchiveCloseCheck085SKC.IsPeriodNetBilledExcluding),
    /// so the answer does not depend on whether the new credit memo already reached the
    /// archive. Interim seat charges do not count: they bill a quantity delta inside a period,
    /// never the period itself, so they must not keep a cancelled base period covered.
    /// </summary>
    local procedure GetBilledThroughByOtherInvoices(SubscriptionLine: Record "Subscription Line"; CancelledInvoiceNo: Code[20]) BilledThrough: Date
    var
        BillingLineArchive: Record "Billing Line Archive";
        ArchiveCheck: Codeunit SubArchiveCloseCheck085SKC;
        InterimInvoices: List of [Code[20]];
    begin
        CollectInterimInvoices(SubscriptionLine."Subscription Header No.", InterimInvoices);

        BillingLineArchive.SetRange("Subscription Line Entry No.", SubscriptionLine."Entry No.");
        BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::Invoice);
        BillingLineArchive.SetFilter("Document No.", '<>%1', CancelledInvoiceNo);
        BillingLineArchive.SetLoadFields("Document No.", "Billing from", "Billing to");
        if BillingLineArchive.FindSet() then
            repeat
                if BillingLineArchive."Billing to" > BilledThrough then
                    if not InterimInvoices.Contains(BillingLineArchive."Document No.") then
                        if ArchiveCheck.IsPeriodNetBilledExcluding(
                            SubscriptionLine."Entry No.", BillingLineArchive."Billing from", BillingLineArchive."Billing to",
                            CancelledInvoiceNo)
                        then
                            BilledThrough := BillingLineArchive."Billing to";
            until BillingLineArchive.Next() = 0;
    end;

    /// <summary>
    /// The invoices interim billing raised for the subscription, from its quantity history.
    /// </summary>
    local procedure CollectInterimInvoices(SubscriptionNo: Code[20]; var InterimInvoices: List of [Code[20]])
    var
        QtyHistory: Record SubQuantityHistory085SKC;
    begin
        Clear(InterimInvoices);
        if not QtyHistory.ReadPermission() then
            exit;
        QtyHistory.SetCurrentKey(SubscriptionHeaderNo085SKC, InterimBilled085SKC);
        QtyHistory.SetRange(SubscriptionHeaderNo085SKC, SubscriptionNo);
        QtyHistory.SetRange(InterimBilled085SKC, true);
        QtyHistory.SetFilter(InterimDocNo085SKC, '<>%1', '');
        QtyHistory.SetLoadFields(InterimDocNo085SKC);
        if QtyHistory.FindSet() then
            repeat
                if not InterimInvoices.Contains(QtyHistory.InterimDocNo085SKC) then
                    InterimInvoices.Add(QtyHistory.InterimDocNo085SKC);
            until QtyHistory.Next() = 0;
    end;

    local procedure GetCancelledPeriod(SubLineEntryNo: Integer; var TempCreditedRow: Record "Billing Line Archive" temporary; var InvoiceNo: Code[20]; var CancelledFrom: Date; var CancelledTo: Date): Boolean
    begin
        InvoiceNo := '';
        CancelledFrom := 0D;
        CancelledTo := 0D;
        TempCreditedRow.Reset();
        TempCreditedRow.SetRange("Subscription Line Entry No.", SubLineEntryNo);
        if TempCreditedRow.FindSet() then
            repeat
                if InvoiceNo = '' then
                    InvoiceNo := TempCreditedRow."Correction Document No.";
                if (CancelledFrom = 0D) or (TempCreditedRow."Billing from" < CancelledFrom) then
                    CancelledFrom := TempCreditedRow."Billing from";
                if TempCreditedRow."Billing to" > CancelledTo then
                    CancelledTo := TempCreditedRow."Billing to";
            until TempCreditedRow.Next() = 0;
        TempCreditedRow.Reset();
        exit((InvoiceNo <> '') and (CancelledTo <> 0D));
    end;

    /// <summary>
    /// Explicit API choice for this invoice first, then the user in the client. Anything
    /// else keeps the standard reset, which is what the API and background posting always did.
    /// </summary>
    local procedure DecideRebill(InvoiceNo: Code[20]; SubLineEntryNo: Integer; CancelledFrom: Date; CancelledTo: Date; ResetDate: Date; RestoreDate: Date): Boolean
    begin
        if (ExplicitInvoiceNo <> '') and (ExplicitInvoiceNo = InvoiceNo) then
            exit(ExplicitRebill);
        if GuiAllowed() and not ApiCancelActive then
            exit(Confirm(RebillQst, true, SubLineEntryNo, CancelledFrom, CancelledTo, InvoiceNo, ResetDate, RestoreDate));
        exit(true);
    end;

    /// <summary>
    /// Open billing lines carry their own periods and would conflict with a moved date. The
    /// credit memo's own lines do not count: they are about to move to the archive.
    /// </summary>
    local procedure HasOtherOpenBillingLines(SubLineEntryNo: Integer): Boolean
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.SetRange("Subscription Line Entry No.", SubLineEntryNo);
        BillingLine.SetFilter("Document Type", '<>%1', BillingLine."Document Type"::"Credit Memo");
        exit(not BillingLine.IsEmpty());
    end;

    local procedure CreditMemoHasContractLines(PostedCrMemoNo: Code[20]): Boolean
    var
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
    begin
        if not SalesCrMemoLine.ReadPermission() then
            exit(false);
        SalesCrMemoLine.SetRange("Document No.", PostedCrMemoNo);
        SalesCrMemoLine.SetFilter("Subscription Contract No.", '<>%1', '');
        exit(not SalesCrMemoLine.IsEmpty());
    end;

    #endregion

    #region Helpers

    local procedure SetNextBillingDate(var SubscriptionLine: Record "Subscription Line"; NewDate: Date; ResetDate: Date; InvoiceNo: Code[20])
    var
        OldDate: Date;
    begin
        TargetNextBillingDates.Set(SubscriptionLine."Entry No.", NewDate);
        ResetNextBillingDates.Set(SubscriptionLine."Entry No.", ResetDate);
        if SubscriptionLine."Next Billing Date" = NewDate then
            exit;

        OldDate := SubscriptionLine."Next Billing Date";
        SubscriptionLine."Next Billing Date" := NewDate;
        SubscriptionLine.Modify(false);

        Session.LogMessage('SKC-0075',
            StrSubstNo(NbdChangedTelemetryTxt, SubscriptionLine."Entry No.", OldDate, NewDate, InvoiceNo),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            'EntryNo', Format(SubscriptionLine."Entry No."), 'InvoiceNo', InvoiceNo);
    end;

    /// <summary>
    /// Only a line that sits on exactly the reset value again is put back, so a date that was
    /// changed for another reason in the meantime is never overwritten.
    /// </summary>
    local procedure ReapplyTargets()
    var
        SubscriptionLine: Record "Subscription Line";
        ResetDate: Date;
        TargetDate: Date;
        SubLineEntryNo: Integer;
    begin
        foreach SubLineEntryNo in TargetNextBillingDates.Keys() do
            if ResetNextBillingDates.Get(SubLineEntryNo, ResetDate) then begin
                TargetDate := TargetNextBillingDates.Get(SubLineEntryNo);
                if TargetDate <> ResetDate then
                    if SubscriptionLine.Get(SubLineEntryNo) then
                        if SubscriptionLine."Next Billing Date" = ResetDate then begin
                            SubscriptionLine."Next Billing Date" := TargetDate;
                            SubscriptionLine.Modify(false);
                        end;
            end;
        Clear(TargetNextBillingDates);
        Clear(ResetNextBillingDates);
    end;

    local procedure AddResult(ResultText: Text)
    begin
        if ApiCancelActive then
            Results.Add(ResultText);
    end;

    local procedure ShowKeptCoverage(var KeptResults: List of [Text])
    var
        Lines: Text;
        ResultText: Text;
    begin
        if KeptResults.Count() = 0 then
            exit;
        if ApiCancelActive or not GuiAllowed() then
            exit;
        foreach ResultText in KeptResults do
            if Lines = '' then
                Lines := ResultText
            else
                Lines += '\' + ResultText;
        Message(KeptCoverageInfoMsg, Lines);
    end;

    local procedure ResetState()
    begin
        Clear(Results);
        Clear(TargetNextBillingDates);
        Clear(ResetNextBillingDates);
        ExplicitInvoiceNo := '';
        ExplicitRebill := false;
        ApiCancelActive := false;
    end;

    /// <summary>
    /// A cancel starts: dates decided for an earlier credit memo are no longer to be re-applied.
    /// </summary>
    local procedure BeginCancelOperation()
    begin
        CancelInProgress := true;
        Clear(TargetNextBillingDates);
        Clear(ResetNextBillingDates);
        NewCaptureOperation();
    end;

    local procedure EndCancelOperation()
    begin
        CancelInProgress := false;
        NewCaptureOperation();
    end;

    local procedure NewCaptureOperation()
    begin
        CaptureOperationNo += 1;
        CaptureCreditMemoNo := '';
        CaptureCreditMemoPending := false;
    end;

    /// <summary>
    /// Only a cancel operation re-applies the dates decided at posting (ReapplyAfterCancel,
    /// FinishCancel). Anywhere else they would be re-applied by the next unrelated cancel.
    /// </summary>
    local procedure DropTargetsOutsideCancel()
    begin
        if CancelInProgress then
            exit;
        Clear(TargetNextBillingDates);
        Clear(ResetNextBillingDates);
    end;

    local procedure SaveNextBillingDate(SubLineEntryNo: Integer; NextBillingDate: Date)
    begin
        SavedNextBillingDates.Set(SubLineEntryNo, NextBillingDate);
        SavedCaptureOperations.Set(SubLineEntryNo, CaptureOperationNo);
    end;

    local procedure SavedInCurrentOperation(SubLineEntryNo: Integer): Boolean
    var
        OperationNo: Integer;
    begin
        if not SavedNextBillingDates.ContainsKey(SubLineEntryNo) then
            exit(false);
        if not SavedCaptureOperations.Get(SubLineEntryNo, OperationNo) then
            exit(false);
        exit(OperationNo = CaptureOperationNo);
    end;

    local procedure ForgetSavedDate(SubLineEntryNo: Integer)
    begin
        if SavedNextBillingDates.Remove(SubLineEntryNo) then;
        if SavedCaptureOperations.Remove(SubLineEntryNo) then;
    end;

    /// <summary>
    /// The saved date was read in an operation bound to a credit memo other than the one being
    /// posted. A date whose operation was never bound to a credit memo still counts, so a
    /// corrective credit memo posted later by hand keeps the date read when it was created.
    /// </summary>
    local procedure SavedForOtherCreditMemo(SubLineEntryNo: Integer; CrMemoNo: Code[20]): Boolean
    var
        BoundCrMemoNo: Code[20];
        OperationNo: Integer;
    begin
        if CrMemoNo = '' then
            exit(false);
        if not SavedCaptureOperations.Get(SubLineEntryNo, OperationNo) then
            exit(false);
        if not OperationCreditMemos.Get(OperationNo, BoundCrMemoNo) then
            exit(false);
        exit((BoundCrMemoNo <> '') and (BoundCrMemoNo <> CrMemoNo));
    end;

    #endregion
}
