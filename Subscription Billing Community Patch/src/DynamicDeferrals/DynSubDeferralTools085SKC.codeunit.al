namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Simulation, rebuild, and audit tools for the dynamic deferral engine.
///
/// Each call writes its output under a fresh Run ID so that a result can be
/// read back, compared, and kept as evidence rather than only appearing once in
/// a message box.
/// </summary>
codeunit 70631112 DynSubDeferralTools085SKC
{
    Access = Public;
    Permissions = tabledata "Cust. Sub. Contract Deferral" = R,
                  tabledata "Deferral Line" = R,
                  tabledata DynDeferralAnalysis085SKC = RIMD,
                  tabledata "Posted Deferral Header" = R,
                  tabledata "Posted Deferral Line" = R,
                  tabledata "Purch. Inv. Line" = R,
                  tabledata "Purchase Line" = RM,
                  tabledata "Sales Cr.Memo Line" = R,
                  tabledata "Sales Invoice Line" = R,
                  tabledata "Sales Line" = RM,
                  tabledata "Vend. Sub. Contract Deferral" = R;

    /// <summary>
    /// Calculates a schedule for supplied dates and an amount without touching
    /// any document, so the split can be checked before a line is converted.
    /// </summary>
    procedure SimulateSchedule(BillingFrom: Date; BillingTo: Date; TotalAmount: Decimal; CurrencyCode: Code[10]): Guid
    var
        TempPeriod: Record DynDeferralAnalysis085SKC temporary;
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
        Allocated: Decimal;
    begin
        StartRun(Enum::DynDeferralAnalysisType085SKC::Simulation);
        DeferralMgmt.CalculateSchedule(BillingFrom, BillingTo, TotalAmount, CurrencyCode, TempPeriod);

        TempPeriod.Reset();
        if TempPeriod.FindSet() then
            repeat
                Allocated += TempPeriod.Amount085SKC;
                LogPeriod(TempPeriod, CurrencyCode, '', 0);
            until TempPeriod.Next() = 0;

        if TempPeriod.IsEmpty() then
            LogProblem('', 0, StrSubstNo(NoPeriodsLbl, BillingFrom, BillingTo));
        if Allocated <> TotalAmount then
            LogProblem('', 0, StrSubstNo(TotalMismatchLbl, Allocated, TotalAmount));

        exit(CurrentRunId);
    end;

    /// <summary>
    /// Rebuilds the dynamic schedules on one unposted document and reports the
    /// resulting periods, so a document can be inspected before it is posted.
    /// </summary>
    procedure RebuildSalesDocument(SalesHeader: Record "Sales Header"): Guid
    var
        SalesLine: Record "Sales Line";
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
    begin
        StartRun(Enum::DynDeferralAnalysisType085SKC::Rebuild);
        DeferralMgmt.RebuildSalesDocument(SalesHeader, false);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(DeferralMethod085SKC, SalesLine.DeferralMethod085SKC::"Standard Dynamic");
        if SalesLine.FindSet() then
            repeat
                LogDeferralLines(
                    Enum::"Deferral Document Type"::Sales.AsInteger(), SalesLine."Document Type".AsInteger(),
                    SalesLine."Document No.", SalesLine."Line No.", SalesLine.GetDeferralAmount());
            until SalesLine.Next() = 0;

        exit(CurrentRunId);
    end;

    procedure RebuildPurchaseDocument(PurchaseHeader: Record "Purchase Header"): Guid
    var
        PurchaseLine: Record "Purchase Line";
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
    begin
        StartRun(Enum::DynDeferralAnalysisType085SKC::Rebuild);
        DeferralMgmt.RebuildPurchaseDocument(PurchaseHeader, false);

        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange(DeferralMethod085SKC, PurchaseLine.DeferralMethod085SKC::"Standard Dynamic");
        if PurchaseLine.FindSet() then
            repeat
                LogDeferralLines(
                    Enum::"Deferral Document Type"::Purchase.AsInteger(), PurchaseLine."Document Type".AsInteger(),
                    PurchaseLine."Document No.", PurchaseLine."Line No.", PurchaseLine.GetDeferralAmount());
            until PurchaseLine.Next() = 0;

        exit(CurrentRunId);
    end;

    /// <summary>
    /// Compares what was posted under each engine for a date range: dynamic
    /// schedules against their document line totals, and the contract deferrals
    /// still waiting to be released.
    /// </summary>
    procedure AuditDeferrals(FromDate: Date; ToDate: Date; DocumentNoFilter: Text): Guid
    begin
        StartRun(Enum::DynDeferralAnalysisType085SKC::Audit);
        AuditSalesInvoices(FromDate, ToDate, DocumentNoFilter);
        AuditSalesCreditMemos(FromDate, ToDate, DocumentNoFilter);
        AuditPurchaseInvoices(FromDate, ToDate, DocumentNoFilter);
        LogLegacyExposure();
        exit(CurrentRunId);
    end;

    local procedure AuditSalesInvoices(FromDate: Date; ToDate: Date; DocumentNoFilter: Text)
    var
        SalesInvoiceLine: Record "Sales Invoice Line";
    begin
        SalesInvoiceLine.SetRange(DeferralMethod085SKC, SalesInvoiceLine.DeferralMethod085SKC::"Standard Dynamic");
        SalesInvoiceLine.SetRange("Posting Date", FromDate, ToDate);
        if DocumentNoFilter <> '' then
            SalesInvoiceLine.SetFilter("Document No.", DocumentNoFilter);
        if not SalesInvoiceLine.FindSet() then
            exit;

        repeat
            AuditPostedSchedule(
                Enum::"Deferral Document Type"::Sales.AsInteger(), SalesInvoiceLine."Document No.",
                SalesInvoiceLine."Line No.", SalesInvoiceLine.Amount, SalesInvoiceLine."Posting Date");
            AuditNoContractDeferralRows(SalesInvoiceLine."Document No.", SalesInvoiceLine."Line No.");
        until SalesInvoiceLine.Next() = 0;
    end;

    local procedure AuditSalesCreditMemos(FromDate: Date; ToDate: Date; DocumentNoFilter: Text)
    var
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
    begin
        SalesCrMemoLine.SetRange(DeferralMethod085SKC, SalesCrMemoLine.DeferralMethod085SKC::"Standard Dynamic");
        SalesCrMemoLine.SetRange("Posting Date", FromDate, ToDate);
        if DocumentNoFilter <> '' then
            SalesCrMemoLine.SetFilter("Document No.", DocumentNoFilter);
        if not SalesCrMemoLine.FindSet() then
            exit;

        repeat
            AuditPostedSchedule(
                Enum::"Deferral Document Type"::Sales.AsInteger(), SalesCrMemoLine."Document No.",
                SalesCrMemoLine."Line No.", SalesCrMemoLine.Amount, SalesCrMemoLine."Posting Date");
        until SalesCrMemoLine.Next() = 0;
    end;

    local procedure AuditPurchaseInvoices(FromDate: Date; ToDate: Date; DocumentNoFilter: Text)
    var
        PurchInvLine: Record "Purch. Inv. Line";
    begin
        PurchInvLine.SetRange(DeferralMethod085SKC, PurchInvLine.DeferralMethod085SKC::"Standard Dynamic");
        PurchInvLine.SetRange("Posting Date", FromDate, ToDate);
        if DocumentNoFilter <> '' then
            PurchInvLine.SetFilter("Document No.", DocumentNoFilter);
        if not PurchInvLine.FindSet() then
            exit;

        repeat
            AuditPostedSchedule(
                Enum::"Deferral Document Type"::Purchase.AsInteger(), PurchInvLine."Document No.",
                PurchInvLine."Line No.", PurchInvLine.Amount, PurchInvLine."Posting Date");
        until PurchInvLine.Next() = 0;
    end;

    /// <summary>
    /// A dynamic line must have a posted schedule whose periods add up to the
    /// line amount. Anything else means the schedule was rebuilt after posting
    /// or the line was partially invoiced without the schedule following.
    /// </summary>
    local procedure AuditPostedSchedule(DeferralDocType: Integer; DocumentNo: Code[20]; LineNo: Integer; LineAmount: Decimal; PostingDate: Date)
    var
        PostedDeferralHeader: Record "Posted Deferral Header";
        PostedDeferralLine: Record "Posted Deferral Line";
        ScheduleTotal: Decimal;
    begin
        PostedDeferralHeader.SetRange("Deferral Doc. Type", DeferralDocType);
        PostedDeferralHeader.SetRange("Document No.", DocumentNo);
        PostedDeferralHeader.SetRange("Line No.", LineNo);
        if PostedDeferralHeader.IsEmpty() then begin
            LogProblem(DocumentNo, LineNo, NoPostedScheduleLbl);
            exit;
        end;

        PostedDeferralLine.SetRange("Deferral Doc. Type", DeferralDocType);
        PostedDeferralLine.SetRange("Document No.", DocumentNo);
        PostedDeferralLine.SetRange("Line No.", LineNo);
        if PostedDeferralLine.FindSet() then
            repeat
                ScheduleTotal += PostedDeferralLine.Amount;
            until PostedDeferralLine.Next() = 0;

        if ScheduleTotal = LineAmount then
            LogObservation(
                DocumentNo, LineNo, PostingDate, ScheduleTotal, StrSubstNo(ScheduleMatchesLbl, ScheduleTotal))
        else
            LogProblem(DocumentNo, LineNo, StrSubstNo(TotalMismatchLbl, ScheduleTotal, LineAmount));
    end;

    local procedure AuditNoContractDeferralRows(DocumentNo: Code[20]; LineNo: Integer)
    var
        CustContractDeferral: Record "Cust. Sub. Contract Deferral";
    begin
        CustContractDeferral.SetRange("Document No.", DocumentNo);
        CustContractDeferral.SetRange("Document Line No.", LineNo);
        if not CustContractDeferral.IsEmpty() then
            LogProblem(DocumentNo, LineNo, BothEnginesPostedLbl);
    end;

    local procedure LogLegacyExposure()
    var
        CustContractDeferral: Record "Cust. Sub. Contract Deferral";
        VendContractDeferral: Record "Vend. Sub. Contract Deferral";
    begin
        CustContractDeferral.SetRange(Released, false);
        VendContractDeferral.SetRange(Released, false);
        LogObservation(
            '', 0, 0D, 0,
            StrSubstNo(LegacyOpenLbl, CustContractDeferral.Count(), VendContractDeferral.Count()));
    end;

    local procedure LogDeferralLines(DeferralDocType: Integer; DocumentType: Integer; DocumentNo: Code[20]; LineNo: Integer; LineAmount: Decimal)
    var
        DeferralLine: Record "Deferral Line";
        Total: Decimal;
    begin
        DeferralLine.SetRange("Deferral Doc. Type", DeferralDocType);
        DeferralLine.SetRange("Gen. Jnl. Template Name", '');
        DeferralLine.SetRange("Gen. Jnl. Batch Name", '');
        DeferralLine.SetRange("Document Type", DocumentType);
        DeferralLine.SetRange("Document No.", DocumentNo);
        DeferralLine.SetRange("Line No.", LineNo);
        if not DeferralLine.FindSet() then begin
            LogProblem(DocumentNo, LineNo, NoScheduleBuiltLbl);
            exit;
        end;

        repeat
            Total += DeferralLine.Amount;
            LogObservation(
                DocumentNo, LineNo, DeferralLine."Posting Date", DeferralLine.Amount, DeferralLine.Description);
        until DeferralLine.Next() = 0;

        if Total <> LineAmount then
            LogProblem(DocumentNo, LineNo, StrSubstNo(TotalMismatchLbl, Total, LineAmount));
    end;

    #region Analysis output

    local procedure StartRun(AnalysisType: Enum DynDeferralAnalysisType085SKC)
    begin
        CurrentRunId := CreateGuid();
        CurrentType := AnalysisType;
        NextLineNo := 0;
    end;

    local procedure NewRow(var Analysis: Record DynDeferralAnalysis085SKC; DocumentNo: Code[20]; DocumentLineNo: Integer)
    begin
        NextLineNo += 1;
        Analysis.Init();
        Analysis.RunId085SKC := CurrentRunId;
        Analysis.LineNo085SKC := NextLineNo;
        Analysis.AnalysisType085SKC := CurrentType;
        Analysis.RunAt085SKC := CurrentDateTime();
        Analysis.DocumentNo085SKC := DocumentNo;
        Analysis.DocumentLineNo085SKC := DocumentLineNo;
    end;

    local procedure LogPeriod(TempPeriod: Record DynDeferralAnalysis085SKC temporary; CurrencyCode: Code[10]; DocumentNo: Code[20]; DocumentLineNo: Integer)
    var
        Analysis: Record DynDeferralAnalysis085SKC;
    begin
        NewRow(Analysis, DocumentNo, DocumentLineNo);
        Analysis.PostingDate085SKC := TempPeriod.PostingDate085SKC;
        Analysis.PeriodStart085SKC := TempPeriod.PeriodStart085SKC;
        Analysis.PeriodEnd085SKC := TempPeriod.PeriodEnd085SKC;
        Analysis.Days085SKC := TempPeriod.Days085SKC;
        Analysis.Amount085SKC := TempPeriod.Amount085SKC;
        Analysis.CurrencyCode085SKC := CurrencyCode;
        Analysis.Insert(false);
    end;

    local procedure LogObservation(DocumentNo: Code[20]; DocumentLineNo: Integer; PostingDate: Date; Amount: Decimal; Message: Text)
    var
        Analysis: Record DynDeferralAnalysis085SKC;
    begin
        NewRow(Analysis, DocumentNo, DocumentLineNo);
        Analysis.PostingDate085SKC := PostingDate;
        Analysis.Amount085SKC := Amount;
        Analysis.Message085SKC := CopyStr(Message, 1, MaxStrLen(Analysis.Message085SKC));
        Analysis.Insert(false);
    end;

    local procedure LogProblem(DocumentNo: Code[20]; DocumentLineNo: Integer; Message: Text)
    var
        Analysis: Record DynDeferralAnalysis085SKC;
    begin
        NewRow(Analysis, DocumentNo, DocumentLineNo);
        Analysis.Message085SKC := CopyStr(Message, 1, MaxStrLen(Analysis.Message085SKC));
        Analysis.IsProblem085SKC := true;
        Analysis.Insert(false);
    end;

    #endregion

    var
        CurrentType: Enum DynDeferralAnalysisType085SKC;
        CurrentRunId: Guid;
        NextLineNo: Integer;
        BothEnginesPostedLbl: Label 'The line has a dynamic schedule and a contract deferral row, so the amount was deferred twice.';
        LegacyOpenLbl: Label '%1 customer and %2 vendor contract deferral rows are still unreleased.', Comment = '%1 = open customer deferral count, %2 = open vendor deferral count';
        NoPeriodsLbl: Label 'No periods could be calculated for %1 to %2.', Comment = '%1 = billing period start date, %2 = billing period end date';
        NoPostedScheduleLbl: Label 'The line was posted as dynamic but has no posted deferral schedule.';
        NoScheduleBuiltLbl: Label 'No deferral schedule exists for the line after the rebuild.';
        ScheduleMatchesLbl: Label 'The posted schedule totals %1, which matches the line.', Comment = '%1 = posted schedule total';
        TotalMismatchLbl: Label 'The schedule totals %1 but the line is %2.', Comment = '%1 = schedule total, %2 = line amount';
}
