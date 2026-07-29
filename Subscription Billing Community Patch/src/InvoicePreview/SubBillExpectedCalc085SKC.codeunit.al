namespace SKC.Subscription;

using Microsoft.Finance.Currency;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Reimplements the standard module's per-period price arithmetic so partner code can
/// derive what a subscription line should cost for an arbitrary window.
///
/// The standard equivalents on table "Subscription Line" (UnitPriceForPeriod,
/// UnitPriceAndCostForPeriod, CalculatePeriodCountAndDaysCount, GetBillingPeriodRatio,
/// CalculateNextToDate) are all marked internal and therefore cannot be called from a
/// dependent extension. The logic is mirrored here rather than approximated, because
/// naive day-weighting produces different results: the standard module counts whole
/// base periods and day-prorates only the remainder.
///
/// Reading "Calculation Base Amount" directly is not a substitute. That field is the
/// price for a single Billing Base Period, so using it for a window spanning several
/// base periods under-charges by the number of periods involved.
/// </summary>
codeunit 70631069 SubBillExpectedCalc085SKC
{
    Access = Internal;
    Permissions =
        tabledata "Subscription Line" = R,
        tabledata "Subscription Header" = R,
        tabledata "Billing Line" = R,
        tabledata "Billing Line Archive" = R,
        tabledata Currency = R;

    /// <summary>
    /// Expected unit price, quantity and amount for a billing period, following the
    /// standard module's convention. Returns false for usage-based lines, whose amounts
    /// come from usage data rather than contract terms, and for incomplete terms.
    /// </summary>
    procedure ExpectedForPeriod(SubLine: Record "Subscription Line"; PeriodFrom: Date; PeriodTo: Date; var ExpectedUnitPrice: Decimal; var ExpectedQuantity: Decimal; var ExpectedAmount: Decimal): Boolean
    var
        Currency: Record Currency;
        PeriodFormula: DateFormula;
        PeriodPrice: Decimal;
        BillingPeriodRatio: Decimal;
        PeriodCount: Integer;
        FollowUpDays: Integer;
        FollowUpPeriodDays: Integer;
    begin
        Clear(ExpectedUnitPrice);
        Clear(ExpectedQuantity);
        Clear(ExpectedAmount);

        if SubLine."Usage Based Billing" then
            exit(false);
        if (PeriodFrom = 0D) or (PeriodTo = 0D) or (PeriodFrom > PeriodTo) then
            exit(false);
        if (Format(SubLine."Billing Base Period") = '') or (Format(SubLine."Billing Rhythm") = '') then
            exit(false);

        SubLine.CalcFields(Quantity);
        ExpectedQuantity := SubLine.Quantity;

        // Rhythm longer than the base period: the price applies per base period, and the
        // base period is the counting unit. Otherwise the price is scaled by the ratio and
        // the rhythm becomes the counting unit.
        BillingPeriodRatio := GetBillingPeriodRatio(SubLine."Billing Rhythm", SubLine."Billing Base Period");
        if BillingPeriodRatio > 1 then begin
            PeriodPrice := SubLine.Price;
            PeriodFormula := SubLine."Billing Base Period";
        end else begin
            PeriodPrice := SubLine.Price * BillingPeriodRatio;
            PeriodFormula := SubLine."Billing Rhythm";
        end;

        CalculatePeriodCountAndDaysCount(SubLine, PeriodFormula, PeriodFrom, PeriodTo, PeriodCount, FollowUpDays, FollowUpPeriodDays);
        ExpectedUnitPrice := PeriodPrice * PeriodCount;
        if FollowUpPeriodDays <> 0 then
            ExpectedUnitPrice += PeriodPrice / FollowUpPeriodDays * FollowUpDays;

        Currency.Initialize(SubLine."Currency Code");
        ExpectedUnitPrice := Round(ExpectedUnitPrice, Currency."Unit-Amount Rounding Precision");
        ExpectedAmount := Round(
            ExpectedUnitPrice * ExpectedQuantity * (1 - SubLine."Discount %" / 100),
            Currency."Amount Rounding Precision");
        exit(true);
    end;

    /// <summary>
    /// Per-unit price for a window inside an enclosing billing period, day-weighted
    /// across that period. Used for interim charges when a quantity changes part way
    /// through a period.
    /// </summary>
    procedure ProRataUnitPriceForWindow(SubLine: Record "Subscription Line"; PeriodFrom: Date; PeriodTo: Date; WindowFrom: Date; WindowTo: Date; var ProRataUnitPrice: Decimal): Boolean
    var
        Currency: Record Currency;
        FullPeriodUnitPrice: Decimal;
        UnusedQuantity: Decimal;
        UnusedAmount: Decimal;
        PeriodDays: Integer;
        WindowDays: Integer;
    begin
        Clear(ProRataUnitPrice);

        if (PeriodFrom = 0D) or (PeriodTo = 0D) or (PeriodFrom > PeriodTo) then
            exit(false);
        if (WindowFrom = 0D) or (WindowTo = 0D) or (WindowFrom > WindowTo) then
            exit(false);
        if (WindowFrom < PeriodFrom) or (WindowTo > PeriodTo) then
            exit(false);

        if not ExpectedForPeriod(SubLine, PeriodFrom, PeriodTo, FullPeriodUnitPrice, UnusedQuantity, UnusedAmount) then
            exit(false);
        if FullPeriodUnitPrice = 0 then
            exit(false);

        PeriodDays := PeriodTo - PeriodFrom + 1;
        WindowDays := WindowTo - WindowFrom + 1;
        if PeriodDays <= 0 then
            exit(false);

        Currency.Initialize(SubLine."Currency Code");
        ProRataUnitPrice := Round(FullPeriodUnitPrice * WindowDays / PeriodDays, Currency."Unit-Amount Rounding Precision");
        exit(ProRataUnitPrice <> 0);
    end;

    /// <summary>
    /// Period end date honouring the line's Period Calculation setting.
    /// </summary>
    procedure CalculatePeriodEnd(SubLine: Record "Subscription Line"; PeriodFormula: DateFormula; PeriodStart: Date): Date
    var
        ReferenceDate: Date;
        LastDateInLastMonth: Date;
        DistanceToEndOfMonth: Integer;
    begin
        case SubLine."Period Calculation" of
            SubLine."Period Calculation"::"Align to Start of Month":
                exit(CalcDate(PeriodFormula, PeriodStart) - 1);
            SubLine."Period Calculation"::"Align to End of Month":
                begin
                    ReferenceDate := GetBillingReferenceDate(SubLine);
                    DistanceToEndOfMonth := CalcDate('<CM>', ReferenceDate) - ReferenceDate;
                    if DistanceToEndOfMonth > 2 then
                        exit(CalcDate(PeriodFormula, PeriodStart) - 1);
                    LastDateInLastMonth := CalcDate('<CM>', CalcDate(PeriodFormula, PeriodStart));
                    exit(LastDateInLastMonth - DistanceToEndOfMonth - 1);
                end;
        end;
    end;

    local procedure CalculatePeriodCountAndDaysCount(SubLine: Record "Subscription Line"; PeriodFormula: DateFormula; StartDate: Date; EndDate: Date; var PeriodCount: Integer; var FollowUpDays: Integer; var FollowUpPeriodDays: Integer)
    var
        DateFormulaManagement: Codeunit "Date Formula Management";
        LastDayInPreviousPeriod: Date;
        LastDayInNextPeriod: Date;
        CumulativeFormula: DateFormula;
        FormulaInteger: Integer;
        Letter: Char;
    begin
        Clear(PeriodCount);
        Clear(FollowUpDays);
        Clear(FollowUpPeriodDays);
        LastDayInNextPeriod := StartDate - 1;
        DateFormulaManagement.FindDateFormulaType(PeriodFormula, FormulaInteger, Letter);

        // The formula is rebuilt cumulatively from StartDate on each pass rather than
        // stepped period by period, which matters for month-end alignment.
        repeat
            Evaluate(CumulativeFormula, '<' + Format((PeriodCount + 1) * FormulaInteger) + Letter + '>');
            LastDayInPreviousPeriod := LastDayInNextPeriod;
            LastDayInNextPeriod := CalculatePeriodEnd(SubLine, CumulativeFormula, StartDate);
            if LastDayInNextPeriod <= EndDate then
                PeriodCount += 1;
        until LastDayInNextPeriod >= EndDate;

        if LastDayInNextPeriod <> EndDate then begin
            FollowUpDays := EndDate - LastDayInPreviousPeriod;
            if IsSingleMonthPeriod(StartDate, EndDate, PeriodFormula) then
                FollowUpPeriodDays := Date2DMY(CalcDate('<CM>', EndDate), 1)
            else
                FollowUpPeriodDays := LastDayInNextPeriod - LastDayInPreviousPeriod;
        end;
    end;

    local procedure GetBillingPeriodRatio(BillingRhythm: DateFormula; BillingBasePeriod: DateFormula): Decimal
    var
        DateFormulaManagement: Codeunit "Date Formula Management";
        BillingPeriodCount: Integer;
        BillingBasePeriodCount: Integer;
    begin
        DateFormulaManagement.FindDateFormulaTypeForComparison(BillingRhythm, BillingPeriodCount);
        DateFormulaManagement.FindDateFormulaTypeForComparison(BillingBasePeriod, BillingBasePeriodCount);
        exit(BillingPeriodCount / BillingBasePeriodCount);
    end;

    /// <summary>
    /// The reference date is the line start date unless an earlier billing line or archive
    /// recorded a shifted reference, which makes the calculation history dependent.
    /// </summary>
    local procedure GetBillingReferenceDate(SubLine: Record "Subscription Line"): Date
    var
        BillingLine: Record "Billing Line";
        BillingLineArchive: Record "Billing Line Archive";
    begin
        BillingLine.SetRange("Subscription Header No.", SubLine."Subscription Header No.");
        BillingLine.SetRange("Subscription Line Entry No.", SubLine."Entry No.");
        BillingLine.SetRange("Billing Reference Date Changed", true);
        if BillingLine.FindLast() then
            exit(BillingLine."Billing to" + 1);

        BillingLineArchive.SetRange("Subscription Header No.", SubLine."Subscription Header No.");
        BillingLineArchive.SetRange("Subscription Line Entry No.", SubLine."Entry No.");
        BillingLineArchive.SetRange("Billing Reference Date Changed", true);
        if BillingLineArchive.FindLast() then
            exit(BillingLineArchive."Billing to" + 1);

        exit(SubLine."Subscription Line Start Date");
    end;

    local procedure IsSingleMonthPeriod(StartDate: Date; EndDate: Date; PeriodFormula: DateFormula): Boolean
    begin
        exit((Date2DMY(StartDate, 2) = Date2DMY(EndDate, 2)) and
             (Date2DMY(StartDate, 3) = Date2DMY(EndDate, 3)) and
             (Format(PeriodFormula) = '1M'));
    end;
}
