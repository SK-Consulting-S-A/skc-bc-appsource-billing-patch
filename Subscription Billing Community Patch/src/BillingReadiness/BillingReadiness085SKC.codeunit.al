namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Checks billing readiness across all active customer subscription lines.
/// Used by the Role Center cue and the "Check Billing Readiness" action
/// on the Customer Contract card.
///
/// Stale-billing detection uses the actual Billing Rhythm per line instead
/// of a fixed day threshold, so monthly, quarterly, and yearly subscriptions
/// each get the correct deadline.
/// </summary>
codeunit 70631127 BillingReadiness085SKC
{
    Access = Public;
    Permissions = tabledata "Subscription Line" = R;

    var
        GraceDays: Integer;
        AllGoodMsg: Label 'Contract %1: all lines are billing-ready.', Comment = '%1 = Contract No.';
        NoNextBillingIssueMsg: Label '\- %1 line(s) with no Next Billing Date (will never be billed)', Comment = '%1 = Count';
        ReadinessIssuesMsg: Label 'Contract %1 has billing issues:\%2', Comment = '%1 = Contract No., %2 = Issue list';
        StaleIssueMsg: Label '\- %1 line(s) with stale billing (overdue by more than one full billing cycle + %2 day grace)', Comment = '%1 = Count, %2 = Grace days';
        ZeroPriceIssueMsg: Label '\- %1 line(s) with zero price (will generate zero-amount invoices)', Comment = '%1 = Count';

    procedure CheckContractReadiness(ContractNo: Code[20])
    var
        SubLine: Record "Subscription Line";
        NoNextBillingCount: Integer;
        StaleCount: Integer;
        ZeroPriceCount: Integer;
        Issues: Text;
    begin
        GraceDays := 14;

        SubLine.SetRange("Subscription Contract No.", ContractNo);
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetFilter(Quantity, '<>0');

        SubLine.SetRange(Price, 0);
        ZeroPriceCount := SubLine.Count();
        SubLine.SetRange(Price);

        SubLine.SetRange("Next Billing Date", 0D);
        NoNextBillingCount := SubLine.Count();
        SubLine.SetRange("Next Billing Date");

        StaleCount := CountStaleLines(SubLine);

        if (ZeroPriceCount = 0) and (NoNextBillingCount = 0) and (StaleCount = 0) then begin
            Message(AllGoodMsg, ContractNo);
            exit;
        end;

        if ZeroPriceCount > 0 then
            Issues += StrSubstNo(ZeroPriceIssueMsg, ZeroPriceCount);
        if NoNextBillingCount > 0 then
            Issues += StrSubstNo(NoNextBillingIssueMsg, NoNextBillingCount);
        if StaleCount > 0 then
            Issues += StrSubstNo(StaleIssueMsg, StaleCount, GraceDays);

        Message(ReadinessIssuesMsg, ContractNo, Issues);
    end;

    procedure ComputeCues(var Cue: Record BillingReadinessCue085SKC)
    var
        SubLine: Record "Subscription Line";
        ContractNos: List of [Code[20]];
    begin
        GraceDays := 14;

        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetFilter(Quantity, '<>0');

        SubLine.SetRange(Price, 0);
        Cue."Zero-Price Lines" := SubLine.Count();
        if SubLine.FindSet() then
            repeat
                if (SubLine."Subscription Contract No." <> '') and
                   not ContractNos.Contains(SubLine."Subscription Contract No.")
                then
                    ContractNos.Add(SubLine."Subscription Contract No.");
            until SubLine.Next() = 0;
        Cue."Contracts w/ Zero-Price" := ContractNos.Count();
        SubLine.SetRange(Price);

        SubLine.SetRange("Subscription Contract No.", '');
        Cue."No Contract Assigned" := SubLine.Count();
        SubLine.SetRange("Subscription Contract No.");

        SubLine.SetRange("Next Billing Date", 0D);
        Cue."No Next Billing Date" := SubLine.Count();
        SubLine.SetRange("Next Billing Date");

        Cue."Stale Billing Lines" := CountStaleLines(SubLine);
    end;

    /// <summary>
    /// Returns true if the specific line is stale (for use in drill-down filtering).
    /// </summary>
    procedure IsLineStale(SubLine: Record "Subscription Line"): Boolean
    var
        StaleDeadline: Date;
    begin
        GraceDays := 14;
        if SubLine.Closed or (SubLine."Next Billing Date" = 0D) then
            exit(false);
        StaleDeadline := CalcStaleDeadline(SubLine);
        exit((StaleDeadline <> 0D) and (Today > StaleDeadline));
    end;

    local procedure CalcStaleDeadline(SubLine: Record "Subscription Line"): Date
    var
        RhythmEnd: Date;
    begin
        if Format(SubLine."Billing Rhythm") = '' then
            exit(SubLine."Next Billing Date" + 95);

        RhythmEnd := CalcDate(SubLine."Billing Rhythm", SubLine."Next Billing Date");
        exit(RhythmEnd + GraceDays);
    end;

    /// <summary>
    /// A line is stale when its Next Billing Date is in the past by more than
    /// one full Billing Rhythm plus a grace period. This means the billing run
    /// has missed at least one full cycle.
    ///
    /// For a monthly line (Billing Rhythm = 1M), stale if Next Billing Date
    /// is more than ~6 weeks ago. For yearly (1Y), more than ~1 year + 14 days.
    /// Lines with no Billing Rhythm fall back to a 95-day fixed threshold.
    /// </summary>
    local procedure CountStaleLines(var SubLineFilter: Record "Subscription Line"): Integer
    var
        SubLine: Record "Subscription Line";
        StaleDeadline: Date;
        StaleCount: Integer;
    begin
        SubLine.CopyFilters(SubLineFilter);
        SubLine.SetFilter("Next Billing Date", '<>%1', 0D);
        SubLine.SetLoadFields("Next Billing Date", "Billing Rhythm");
        if not SubLine.FindSet() then
            exit(0);

        repeat
            StaleDeadline := CalcStaleDeadline(SubLine);
            if (StaleDeadline <> 0D) and (Today > StaleDeadline) then
                StaleCount += 1;
        until SubLine.Next() = 0;

        exit(StaleCount);
    end;
}
