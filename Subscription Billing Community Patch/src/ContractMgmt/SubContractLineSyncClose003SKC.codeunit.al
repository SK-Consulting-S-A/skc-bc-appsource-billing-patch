namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Synchronises the Closed flag from Subscription Lines to their linked
/// Customer Subscription Contract Lines.
///
/// Root cause: BC Subscription Billing keeps Subscription Line.Closed and
/// Cust. Sub. Contract Line.Closed as independent Boolean fields.
/// The standard module only closes both atomically during the "Merge Contract
/// Lines" action (CustSubContractLine.UpdateServiceCommitmentAndCloseCustomerContractLine).
/// When lines are closed by any other mechanism (manual close, external import,
/// expiration batch), the contract line is left with Closed = false and the
/// subscription line still carries a stale "Next Billing Date".
///
/// This codeunit corrects both discrepancies in a single pass:
///   1. Clears Next Billing Date on closed subscription lines (matches the
///      standard BC closing logic that sets it to 0D).
///   2. Propagates Closed = true to the linked contract line.
/// </summary>
codeunit 70631062 SubContractLineSyncClose003SKC
{
    Access = Internal;

    /// <summary>
    /// Syncs all closed subscription lines to their contract lines.
    /// Returns the number of contract lines that were newly closed.
    /// </summary>
    procedure SyncClosedContractLines(): Integer
    var
        SubLine: Record "Subscription Line";
        CustContractLine: Record "Cust. Sub. Contract Line";
        Synced: Integer;
    begin
        SubLine.SetRange(Closed, true);
        SubLine.SetFilter("Subscription Contract No.", '<>%1', '');
        if not SubLine.FindSet(true) then
            exit(0);

        repeat
            // Clear stale Next Billing Date (standard BC closing sets it to 0D)
            if SubLine."Next Billing Date" <> 0D then begin
                SubLine."Next Billing Date" := 0D;
                SubLine.Modify(false);
            end;

            // Close the linked customer contract line if not already closed
            if CustContractLine.Get(SubLine."Subscription Contract No.", SubLine."Subscription Contract Line No.") then
                if not CustContractLine.Closed then begin
                    CustContractLine.Closed := true;
                    CustContractLine.Modify(false);
                    Synced += 1;
                end;
        until SubLine.Next() = 0;

        exit(Synced);
    end;

    /// <summary>
    /// Returns the number of contract lines that are out of sync:
    /// their subscription line is Closed = true but the contract line is not.
    /// Used as a diagnostic counter on the operations API.
    /// </summary>
    procedure CountUnsynced(): Integer
    var
        SubLine: Record "Subscription Line";
        CustContractLine: Record "Cust. Sub. Contract Line";
        UnsyncedCount: Integer;
    begin
        SubLine.SetRange(Closed, true);
        SubLine.SetFilter("Subscription Contract No.", '<>%1', '');
        if not SubLine.FindSet() then
            exit(0);

        repeat
            if CustContractLine.Get(SubLine."Subscription Contract No.", SubLine."Subscription Contract Line No.") then
                if not CustContractLine.Closed then
                    UnsyncedCount += 1;
        until SubLine.Next() = 0;

        exit(UnsyncedCount);
    end;
}
