namespace SKC.Subscription;

using Microsoft.Finance.Currency;
using Microsoft.Finance.Deferral;
using Microsoft.Inventory.Item;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Builds standard Business Central deferral schedules whose periods follow the
/// subscription billing period exactly.
///
/// Contract deferrals hold the deferred amount on a balance sheet account and
/// only reach profit and loss when the Contract Deferrals Release report is
/// run, month after month. A standard deferral schedule instead writes every
/// future-dated G/L entry inside the invoice transaction, so a twelve month
/// subscription is fully recognised the moment it is posted and no recurring
/// manual step can be forgotten.
///
/// The reason this cannot simply use a standard deferral template is period
/// geometry: a template fixes the number of periods, while a subscription line
/// carries its own Billing from/to on every single invoice. The schedule is
/// therefore always rebuilt from those two dates. The template supplies only
/// the deferral account and the description.
///
/// The amount split reproduces the contract-deferral algorithm so that the
/// output can be reconciled against the other engine line for line: a partial
/// first or last month is prorated by day, whole months in between are equal,
/// and the final period absorbs the rounding difference so the schedule always
/// totals the line amount.
/// </summary>
codeunit 70631109 DynSubDeferralMgmt085SKC
{
    Access = Public;
    Permissions = tabledata "Deferral Header" = RIMD,
                  tabledata "Deferral Line" = RIMD,
                  tabledata "Deferral Template" = R,
                  tabledata Item = R,
                  tabledata "Purchase Line" = RM,
                  tabledata "Sales Line" = RM,
                  tabledata "Subscription Contract Setup" = R,
                  tabledata "Subscription Line" = R;

    #region Method resolution

    /// <summary>
    /// The method actually used for a subscription line. An explicit choice on
    /// the line always wins, which is what makes it possible to pilot the
    /// dynamic engine on a few lines before switching a company over.
    /// </summary>
    procedure GetEffectiveMethod(SubscriptionLine: Record "Subscription Line"): Enum SubDeferralMethod085SKC
    begin
        if SubscriptionLine.DeferralMethod085SKC <> SubscriptionLine.DeferralMethod085SKC::"Setup Default" then
            exit(SubscriptionLine.DeferralMethod085SKC);

        exit(GetSetupDefaultMethod());
    end;

    procedure GetSetupDefaultMethod(): Enum SubDeferralMethod085SKC
    var
        ContractSetup: Record "Subscription Contract Setup";
        Method: Enum SubDeferralMethod085SKC;
    begin
        if not ContractSetup.Get() then
            exit(Method::"Subscription Deferral");
        if ContractSetup.DefaultDeferralMethod085SKC = Method::"Setup Default" then
            exit(Method::"Subscription Deferral");
        exit(ContractSetup.DefaultDeferralMethod085SKC);
    end;

    /// <summary>
    /// The template that supplies the deferral account. Priority is the line
    /// override, then the invoicing item (which is frequently not the same item
    /// as the one on the subscription header), then the partner-specific
    /// fallback in setup.
    /// </summary>
    procedure ResolveTemplateCode(SubscriptionLine: Record "Subscription Line"): Code[10]
    var
        ContractSetup: Record "Subscription Contract Setup";
        Item: Record Item;
    begin
        if IsDynamicTemplate(SubscriptionLine.DynDeferralTemplate085SKC) then
            exit(SubscriptionLine.DynDeferralTemplate085SKC);

        if SubscriptionLine."Invoicing Item No." <> '' then
            if Item.Get(SubscriptionLine."Invoicing Item No.") then
                if IsDynamicTemplate(Item."Default Deferral Template Code") then
                    exit(Item."Default Deferral Template Code");

        if not ContractSetup.Get() then
            exit('');

        if SubscriptionLine.Partner = SubscriptionLine.Partner::Customer then
            exit(ContractSetup.CustDynDeferralTemplate085SKC);

        exit(ContractSetup.VendDynDeferralTemplate085SKC);
    end;

    procedure ResolveForSubscriptionLine(SubscriptionLineEntryNo: Integer; var Method: Enum SubDeferralMethod085SKC; var TemplateCode: Code[10]): Boolean
    var
        SubscriptionLine: Record "Subscription Line";
    begin
        Clear(TemplateCode);
        if not SubscriptionLine.Get(SubscriptionLineEntryNo) then begin
            Method := Method::"Setup Default";
            exit(false);
        end;

        Method := GetEffectiveMethod(SubscriptionLine);
        if Method = Method::"Standard Dynamic" then
            TemplateCode := ResolveTemplateCode(SubscriptionLine);
        exit(true);
    end;

    procedure IsDynamicTemplate(DeferralCode: Code[10]): Boolean
    var
        DeferralTemplate: Record "Deferral Template";
    begin
        if DeferralCode = '' then
            exit(false);
        if not DeferralTemplate.Get(DeferralCode) then
            exit(false);
        exit(DeferralTemplate.DynamicSubSchedule085SKC);
    end;

    #endregion

    #region Schedule calculation

    /// <summary>
    /// Splits an amount across the calendar months a billing period touches.
    ///
    /// The buffer is the analysis table used as a temporary record, so a
    /// simulation can persist exactly what was calculated without a second
    /// structure that could drift from the real one.
    /// </summary>
    procedure CalculateSchedule(BillingFrom: Date; BillingTo: Date; TotalAmount: Decimal; CurrencyCode: Code[10]; var TempPeriod: Record DynDeferralAnalysis085SKC temporary)
    var
        Currency: Record Currency;
        MonthStart: Date;
        PeriodEnd: Date;
        PeriodStart: Date;
        Allocated: Decimal;
        FullMonthAmount: Decimal;
        PartialFirstAmount: Decimal;
        PartialLastAmount: Decimal;
        PeriodAmount: Decimal;
        AmountPerDay: Decimal;
        RoundingPrecision: Decimal;
        FullMonthCount: Integer;
        Index: Integer;
        PeriodCount: Integer;
        TotalDays: Integer;
        FirstMonthIsPartial: Boolean;
        LastMonthIsPartial: Boolean;
    begin
        TempPeriod.Reset();
        TempPeriod.DeleteAll(false);
        Allocated := 0;

        if (BillingFrom = 0D) or (BillingTo = 0D) or (BillingTo < BillingFrom) then
            exit;

        if CurrencyCode = '' then begin
            Currency.Init();
            Currency.InitRoundingPrecision();
        end else
            Currency.Get(CurrencyCode);
        RoundingPrecision := Currency."Amount Rounding Precision";

        PeriodCount := GetNumberOfPeriods(BillingFrom, BillingTo);
        TotalDays := BillingTo - BillingFrom + 1;
        AmountPerDay := TotalAmount / TotalDays;

        FirstMonthIsPartial := BillingFrom <> CalcDate('<-CM>', BillingFrom);
        LastMonthIsPartial := BillingTo <> CalcDate('<CM>', BillingTo);

        if FirstMonthIsPartial then
            PartialFirstAmount := Round((CalcDate('<CM>', BillingFrom) - BillingFrom + 1) * AmountPerDay, RoundingPrecision);
        if LastMonthIsPartial then
            PartialLastAmount := Round(Date2DMY(BillingTo, 1) * AmountPerDay, RoundingPrecision);

        FullMonthCount := PeriodCount;
        if FirstMonthIsPartial then
            FullMonthCount -= 1;
        if LastMonthIsPartial and (PeriodCount > 1) then
            FullMonthCount -= 1;
        if FullMonthCount > 0 then
            FullMonthAmount := Round((TotalAmount - PartialFirstAmount - PartialLastAmount) / FullMonthCount, RoundingPrecision);

        MonthStart := CalcDate('<-CM>', BillingFrom);
        for Index := 1 to PeriodCount do begin
            PeriodStart := Index = 1 ? BillingFrom : MonthStart;
            PeriodEnd := CalcDate('<CM>', MonthStart);
            if PeriodEnd > BillingTo then
                PeriodEnd := BillingTo;

            case true of
                Index = PeriodCount:
                    // The final period absorbs rounding so that the schedule
                    // always adds up to the document line amount exactly.
                    PeriodAmount := TotalAmount - Allocated;
                (Index = 1) and FirstMonthIsPartial:
                    PeriodAmount := PartialFirstAmount;
                else
                    PeriodAmount := FullMonthAmount;
            end;
            Allocated += PeriodAmount;

            TempPeriod.Init();
            TempPeriod.LineNo085SKC := Index;
            TempPeriod.PostingDate085SKC := PeriodStart;
            TempPeriod.PeriodStart085SKC := PeriodStart;
            TempPeriod.PeriodEnd085SKC := PeriodEnd;
            TempPeriod.Days085SKC := PeriodEnd - PeriodStart + 1;
            TempPeriod.Amount085SKC := PeriodAmount;
            TempPeriod.Insert(false);

            MonthStart := CalcDate('<CM+1D>', MonthStart);
        end;
    end;

    /// <summary>
    /// Number of calendar months the billing period touches, which is also the
    /// number of deferral periods. A period from 15 March to 14 April touches
    /// two months and therefore produces two entries.
    /// </summary>
    procedure GetNumberOfPeriods(BillingFrom: Date; BillingTo: Date): Integer
    var
        LoopDate: Date;
        PeriodCount: Integer;
    begin
        if (BillingFrom = 0D) or (BillingTo = 0D) or (BillingTo < BillingFrom) then
            exit(0);

        LoopDate := CalcDate('<-CM>', BillingFrom);
        while LoopDate <= BillingTo do begin
            PeriodCount += 1;
            LoopDate := CalcDate('<CM+1D>', LoopDate);
        end;
        exit(PeriodCount);
    end;

    #endregion

    #region Schedule application

    procedure ApplySalesLineDeferral(var SalesLine: Record "Sales Line"; ThrowErrors: Boolean): Boolean
    var
        SalesHeader: Record "Sales Header";
        Reason: Text;
    begin
        if SalesLine.DeferralMethod085SKC <> SalesLine.DeferralMethod085SKC::"Standard Dynamic" then
            exit(false);
        if not SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.") then
            exit(false);

        if not SalesLineIsSchedulable(SalesLine, Reason) then begin
            if ThrowErrors then
                Error(NotSchedulableErr, SalesLine."Document No.", SalesLine."Line No.", Reason);
            RemoveSalesLineSchedule(SalesLine);
            exit(false);
        end;

        SalesLine."Deferral Code" := SalesLine.DynDeferralTemplate085SKC;
        SalesLine.Modify(false);

        BuildSchedule(
            Enum::"Deferral Document Type"::Sales.AsInteger(),
            SalesLine."Document Type".AsInteger(), SalesLine."Document No.", SalesLine."Line No.",
            SalesLine.DynDeferralTemplate085SKC, SalesLine.GetDeferralAmount(), SalesHeader."Currency Code",
            SalesLine."Recurring Billing from", SalesLine."Recurring Billing to", SalesLine.Description);
        exit(true);
    end;

    procedure ApplyPurchaseLineDeferral(var PurchaseLine: Record "Purchase Line"; ThrowErrors: Boolean): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
        Reason: Text;
    begin
        if PurchaseLine.DeferralMethod085SKC <> PurchaseLine.DeferralMethod085SKC::"Standard Dynamic" then
            exit(false);
        if not PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.") then
            exit(false);

        if not PurchaseLineIsSchedulable(PurchaseLine, Reason) then begin
            if ThrowErrors then
                Error(NotSchedulableErr, PurchaseLine."Document No.", PurchaseLine."Line No.", Reason);
            RemovePurchaseLineSchedule(PurchaseLine);
            exit(false);
        end;

        PurchaseLine."Deferral Code" := PurchaseLine.DynDeferralTemplate085SKC;
        PurchaseLine.Modify(false);

        BuildSchedule(
            Enum::"Deferral Document Type"::Purchase.AsInteger(),
            PurchaseLine."Document Type".AsInteger(), PurchaseLine."Document No.", PurchaseLine."Line No.",
            PurchaseLine.DynDeferralTemplate085SKC, PurchaseLine.GetDeferralAmount(), PurchaseHeader."Currency Code",
            PurchaseLine."Recurring Billing from", PurchaseLine."Recurring Billing to", PurchaseLine.Description);
        exit(true);
    end;

    /// <summary>
    /// Rebuilds every dynamic schedule on a sales document. Called immediately
    /// before posting because the amount, the discount, or the billing period
    /// may all have been edited after the document was created.
    /// </summary>
    procedure RebuildSalesDocument(SalesHeader: Record "Sales Header"; ThrowErrors: Boolean): Integer
    var
        SalesLine: Record "Sales Line";
        Rebuilt: Integer;
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(DeferralMethod085SKC, SalesLine.DeferralMethod085SKC::"Standard Dynamic");
        if not SalesLine.FindSet() then
            exit(0);

        repeat
            if ApplySalesLineDeferral(SalesLine, ThrowErrors) then
                Rebuilt += 1;
        until SalesLine.Next() = 0;
        exit(Rebuilt);
    end;

    procedure RebuildPurchaseDocument(PurchaseHeader: Record "Purchase Header"; ThrowErrors: Boolean): Integer
    var
        PurchaseLine: Record "Purchase Line";
        Rebuilt: Integer;
    begin
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange(DeferralMethod085SKC, PurchaseLine.DeferralMethod085SKC::"Standard Dynamic");
        if not PurchaseLine.FindSet() then
            exit(0);

        repeat
            if ApplyPurchaseLineDeferral(PurchaseLine, ThrowErrors) then
                Rebuilt += 1;
        until PurchaseLine.Next() = 0;
        exit(Rebuilt);
    end;

    /// <summary>
    /// Creates the header through the platform's own routine so that currency
    /// conversion, rounding, and template validation stay standard, then
    /// replaces the generated lines with the exact billing period geometry.
    /// </summary>
    local procedure BuildSchedule(DeferralDocType: Integer; DocumentType: Integer; DocumentNo: Code[20]; LineNo: Integer; DeferralCode: Code[10]; Amount: Decimal; CurrencyCode: Code[10]; BillingFrom: Date; BillingTo: Date; Description: Text[100])
    var
        DeferralHeader: Record "Deferral Header";
        DeferralLine: Record "Deferral Line";
        TempPeriod: Record DynDeferralAnalysis085SKC temporary;
        DeferralUtilities: Codeunit "Deferral Utilities";
        AmountLCY: Decimal;
        AllocatedLCY: Decimal;
        PeriodCount: Integer;
    begin
        PeriodCount := GetNumberOfPeriods(BillingFrom, BillingTo);
        CalculateSchedule(BillingFrom, BillingTo, Amount, CurrencyCode, TempPeriod);

        DeferralUtilities.CreateDeferralSchedule(
            DeferralCode, DeferralDocType, '', '', DocumentType, DocumentNo, LineNo,
            Amount, Enum::"Deferral Calculation Method"::"User-Defined", BillingFrom,
            PeriodCount, false, Description, false, CurrencyCode);

        DeferralHeader.Get(DeferralDocType, '', '', DocumentType, DocumentNo, LineNo);
        AmountLCY := DeferralHeader."Amount to Defer (LCY)";
        AllocatedLCY := 0;

        DeferralLine.SetRange("Deferral Doc. Type", DeferralDocType);
        DeferralLine.SetRange("Gen. Jnl. Template Name", '');
        DeferralLine.SetRange("Gen. Jnl. Batch Name", '');
        DeferralLine.SetRange("Document Type", DocumentType);
        DeferralLine.SetRange("Document No.", DocumentNo);
        DeferralLine.SetRange("Line No.", LineNo);
        DeferralLine.DeleteAll(false);

        TempPeriod.Reset();
        if TempPeriod.FindSet() then
            repeat
                DeferralLine.Init();
                DeferralLine."Deferral Doc. Type" := DeferralHeader."Deferral Doc. Type";
                DeferralLine."Gen. Jnl. Template Name" := '';
                DeferralLine."Gen. Jnl. Batch Name" := '';
                DeferralLine."Document Type" := DocumentType;
                DeferralLine."Document No." := DocumentNo;
                DeferralLine."Line No." := LineNo;
                DeferralLine."Posting Date" := TempPeriod.PostingDate085SKC;
                DeferralLine."Currency Code" := CurrencyCode;
                DeferralLine.Description :=
                    DeferralUtilities.CreateRecurringDescription(TempPeriod.PostingDate085SKC, Description);
                DeferralLine.Amount := TempPeriod.Amount085SKC;
                if TempPeriod.LineNo085SKC = PeriodCount then
                    DeferralLine."Amount (LCY)" := AmountLCY - AllocatedLCY
                else
                    DeferralLine."Amount (LCY)" := Round(AmountLCY * TempPeriod.Amount085SKC / Amount);
                AllocatedLCY += DeferralLine."Amount (LCY)";
                DeferralLine.Insert(false);
            until TempPeriod.Next() = 0;

        DeferralHeader."Start Date" := BillingFrom;
        DeferralHeader."No. of Periods" := PeriodCount;
        DeferralHeader."Schedule Line Total" := Amount;
        DeferralHeader.Modify(false);
    end;

    procedure RemoveSalesLineSchedule(var SalesLine: Record "Sales Line")
    var
        DeferralUtilities: Codeunit "Deferral Utilities";
    begin
        if SalesLine."Deferral Code" = '' then
            exit;

        DeferralUtilities.DeferralCodeOnDelete(
            Enum::"Deferral Document Type"::Sales.AsInteger(), '', '',
            SalesLine."Document Type".AsInteger(), SalesLine."Document No.", SalesLine."Line No.");
        SalesLine."Deferral Code" := '';
        SalesLine.Modify(false);
    end;

    procedure RemovePurchaseLineSchedule(var PurchaseLine: Record "Purchase Line")
    var
        DeferralUtilities: Codeunit "Deferral Utilities";
    begin
        if PurchaseLine."Deferral Code" = '' then
            exit;

        DeferralUtilities.DeferralCodeOnDelete(
            Enum::"Deferral Document Type"::Purchase.AsInteger(), '', '',
            PurchaseLine."Document Type".AsInteger(), PurchaseLine."Document No.", PurchaseLine."Line No.");
        PurchaseLine."Deferral Code" := '';
        PurchaseLine.Modify(false);
    end;

    #endregion

    #region Readiness

    /// <summary>
    /// Everything that has to be true before a dynamic schedule can be built.
    /// The reason is returned rather than thrown so that an analysis run can
    /// collect all of them instead of stopping at the first.
    /// </summary>
    procedure SalesLineIsSchedulable(SalesLine: Record "Sales Line"; var Reason: Text): Boolean
    begin
        Clear(Reason);

        if SalesLine.DynDeferralTemplate085SKC = '' then begin
            Reason := NoTemplateReasonLbl;
            exit(false);
        end;
        if not IsDynamicTemplate(SalesLine.DynDeferralTemplate085SKC) then begin
            Reason := StrSubstNo(TemplateNotDynamicReasonLbl, SalesLine.DynDeferralTemplate085SKC);
            exit(false);
        end;
        if SalesLine.GetDeferralAmount() = 0 then begin
            Reason := ZeroAmountReasonLbl;
            exit(false);
        end;

        exit(PeriodIsSchedulable(SalesLine."Recurring Billing from", SalesLine."Recurring Billing to", Reason));
    end;

    procedure PurchaseLineIsSchedulable(PurchaseLine: Record "Purchase Line"; var Reason: Text): Boolean
    begin
        Clear(Reason);

        if PurchaseLine.DynDeferralTemplate085SKC = '' then begin
            Reason := NoTemplateReasonLbl;
            exit(false);
        end;
        if not IsDynamicTemplate(PurchaseLine.DynDeferralTemplate085SKC) then begin
            Reason := StrSubstNo(TemplateNotDynamicReasonLbl, PurchaseLine.DynDeferralTemplate085SKC);
            exit(false);
        end;
        if PurchaseLine.GetDeferralAmount() = 0 then begin
            Reason := ZeroAmountReasonLbl;
            exit(false);
        end;

        exit(PeriodIsSchedulable(PurchaseLine."Recurring Billing from", PurchaseLine."Recurring Billing to", Reason));
    end;

    /// <summary>
    /// Detects a line where both deferral engines would run.
    ///
    /// Contract-dependent counts as a conflict even though it may resolve to no
    /// deferral: the resolution depends on the contract type, so a line left in
    /// that state could start double-deferring the day someone changes the
    /// contract type.
    /// </summary>
    procedure ContractDeferralsConflict(SubscriptionLineEntryNo: Integer; var Reason: Text): Boolean
    var
        SubscriptionLine: Record "Subscription Line";
    begin
        Clear(Reason);
        if SubscriptionLineEntryNo = 0 then
            exit(false);
        if not SubscriptionLine.Get(SubscriptionLineEntryNo) then
            exit(false);
        if SubscriptionLine."Create Contract Deferrals" = SubscriptionLine."Create Contract Deferrals"::No then
            exit(false);

        Reason := StrSubstNo(
            BothEnginesReasonLbl, SubscriptionLineEntryNo, SubscriptionLine."Create Contract Deferrals");
        exit(true);
    end;

    local procedure PeriodIsSchedulable(BillingFrom: Date; BillingTo: Date; var Reason: Text): Boolean
    var
        DeferralUtilities: Codeunit "Deferral Utilities";
    begin
        if (BillingFrom = 0D) or (BillingTo = 0D) then begin
            Reason := NoPeriodReasonLbl;
            exit(false);
        end;
        if BillingTo < BillingFrom then begin
            Reason := StrSubstNo(InvertedPeriodReasonLbl, BillingFrom, BillingTo);
            exit(false);
        end;
        if DeferralUtilities.IsDateNotAllowed(BillingFrom) then begin
            Reason := StrSubstNo(DateNotAllowedReasonLbl, BillingFrom);
            exit(false);
        end;
        exit(true);
    end;

    #endregion

    var
        NotSchedulableErr: Label 'A dynamic deferral schedule cannot be built for document %1 line %2. %3', Comment = '%1 = document number, %2 = line number, %3 = reason';
        BothEnginesReasonLbl: Label 'Subscription line %1 still has Create Contract Deferrals set to %2. Set it to No before using the dynamic engine, otherwise the same amount would be deferred twice.', Comment = '%1 = subscription line entry number, %2 = current Create Contract Deferrals value';
        DateNotAllowedReasonLbl: Label 'The schedule would start on %1, which is outside the allowed posting date range.', Comment = '%1 = billing period start date';
        InvertedPeriodReasonLbl: Label 'The billing period runs from %1 to %2, which ends before it starts.', Comment = '%1 = billing period start date, %2 = billing period end date';
        NoPeriodReasonLbl: Label 'The line has no recurring billing period.';
        NoTemplateReasonLbl: Label 'No dynamic deferral template could be resolved for the line.';
        TemplateNotDynamicReasonLbl: Label 'Deferral template %1 is not marked as a dynamic subscription schedule.', Comment = '%1 = deferral template code';
        ZeroAmountReasonLbl: Label 'The line amount is zero, so there is nothing to defer.';
}
