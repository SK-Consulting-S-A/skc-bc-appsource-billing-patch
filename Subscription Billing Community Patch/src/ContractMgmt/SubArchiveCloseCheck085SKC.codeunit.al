namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Detects subscription lines whose Next Billing Date was reset by credit memos
/// even though the billing archive proves invoices covered the full period.
/// Fixes the NBD from archive evidence, then closes the lines where the standard
/// closing condition (End Date &lt;= NBD - 1) is now satisfied.
/// </summary>
codeunit 70631067 SubArchiveCloseCheck085SKC
{
    Access = Internal;

    Permissions =
        tabledata "Subscription Line" = RM,
        tabledata "Subscription Header" = RM,
        tabledata "Billing Line Archive" = R,
        tabledata "Billing Line" = R,
        tabledata "Cust. Sub. Contract Line" = RM,
        tabledata "Vend. Sub. Contract Line" = RM;

    var
        NbdFixedTxt: Label 'Entry %1: NBD corrected from %2 to %3 (billed through %4)', Locked = true;
        LineClosedTxt: Label 'Entry %1 auto-closed after NBD fix (End Date %2)', Locked = true;
        BatchCompletedTxt: Label 'Archive NBD fix completed. Fixed: %1, Closed: %2, Skipped: %3', Locked = true;

    /// <summary>
    /// Returns the latest "Billing to" date from posted invoices in the
    /// Billing Line Archive for the given subscription line.
    /// </summary>
    procedure GetArchiveBilledThrough(SubLineEntryNo: Integer): Date
    var
        BillingArchive: Record "Billing Line Archive";
        MaxBilledTo: Date;
    begin
        BillingArchive.SetRange("Subscription Line Entry No.", SubLineEntryNo);
        BillingArchive.SetRange("Document Type", BillingArchive."Document Type"::Invoice);
        BillingArchive.SetLoadFields("Billing to");
        if BillingArchive.FindSet() then
            repeat
                if BillingArchive."Billing to" > MaxBilledTo then
                    MaxBilledTo := BillingArchive."Billing to";
            until BillingArchive.Next() = 0;
        exit(MaxBilledTo);
    end;

    /// <summary>
    /// Returns true when the archive proves billing went further than
    /// the current Next Billing Date indicates and no open billing lines
    /// prevent the correction.
    /// </summary>
    procedure IsArchiveFixable(SubLine: Record "Subscription Line"): Boolean
    var
        BillingLine: Record "Billing Line";
        BilledThrough: Date;
        CorrectNBD: Date;
    begin
        if SubLine.Closed then
            exit(false);

        BillingLine.SetRange("Subscription Line Entry No.", SubLine."Entry No.");
        if not BillingLine.IsEmpty() then
            exit(false);

        BilledThrough := GetArchiveBilledThrough(SubLine."Entry No.");
        if BilledThrough = 0D then
            exit(false);

        CorrectNBD := BilledThrough + 1;
        exit(CorrectNBD > SubLine."Next Billing Date");
    end;

    /// <summary>
    /// Counts how many lines would be fixed by FixArchiveCompletedLines.
    /// Used for the role center cue.
    /// </summary>
    procedure CountFixableLines(): Integer
    var
        SubLine: Record "Subscription Line";
        FixableCount: Integer;
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetFilter("Next Billing Date", '<>%1', 0D);
        SubLine.SetLoadFields("Entry No.", Closed, "Next Billing Date");
        if not SubLine.FindSet() then
            exit(0);

        repeat
            if IsArchiveFixable(SubLine) then
                FixableCount += 1;
        until SubLine.Next() = 0;

        exit(FixableCount);
    end;

    /// <summary>
    /// Batch: fixes the Next Billing Date on all lines where the archive
    /// proves billing went further than the current NBD. For lines where
    /// the fix satisfies the standard closing condition (End Date = NBD - 1),
    /// closes them directly.
    /// </summary>
    procedure FixArchiveCompletedLines(): Integer
    var
        SubLine: Record "Subscription Line";
        FixedCount: Integer;
        ClosedCount: Integer;
        SkippedCount: Integer;
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetFilter("Next Billing Date", '<>%1', 0D);
        if SubLine.FindSet(true) then
            repeat
                if FixNextBillingDate(SubLine) then begin
                    FixedCount += 1;
                    if TryCloseLine(SubLine) then
                        ClosedCount += 1;
                end else
                    SkippedCount += 1;
            until SubLine.Next() = 0;

        Session.LogMessage('SKC-0070',
            StrSubstNo(BatchCompletedTxt, FixedCount, ClosedCount, SkippedCount),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            'FixedCount', Format(FixedCount), 'ClosedCount', Format(ClosedCount));

        exit(FixedCount);
    end;

    local procedure FixNextBillingDate(var SubLine: Record "Subscription Line"): Boolean
    var
        BillingLine: Record "Billing Line";
        BilledThrough: Date;
        NewNBD: Date;
        OldNBD: Date;
    begin
        BillingLine.SetRange("Subscription Line Entry No.", SubLine."Entry No.");
        if not BillingLine.IsEmpty() then
            exit(false);

        BilledThrough := GetArchiveBilledThrough(SubLine."Entry No.");
        if BilledThrough = 0D then
            exit(false);

        NewNBD := BilledThrough + 1;
        if NewNBD <= SubLine."Next Billing Date" then
            exit(false);

        OldNBD := SubLine."Next Billing Date";
        SubLine."Next Billing Date" := NewNBD;
        SubLine.Modify(false);

        Session.LogMessage('SKC-0071',
            StrSubstNo(NbdFixedTxt, SubLine."Entry No.", OldNBD, NewNBD, BilledThrough),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            'EntryNo', Format(SubLine."Entry No."));

        exit(true);
    end;

    /// <summary>
    /// If the fixed NBD now satisfies the standard closing condition
    /// (End Date &lt;= NBD - 1), close the line and its linked contract line.
    /// </summary>
    local procedure TryCloseLine(var SubLine: Record "Subscription Line"): Boolean
    var
        SubHeader: Record "Subscription Header";
        CustContractLine: Record "Cust. Sub. Contract Line";
        VendContractLine: Record "Vend. Sub. Contract Line";
        SiblingLine: Record "Subscription Line";
        AllClosed: Boolean;
    begin
        if SubLine."Subscription Line End Date" = 0D then
            exit(false);
        if SubLine."Subscription Line End Date" >= SubLine."Next Billing Date" then
            exit(false);

        SubLine.Closed := true;
        SubLine."Next Billing Date" := 0D;
        SubLine.Modify(false);

        if (SubLine."Subscription Contract No." <> '') and
           (SubLine."Subscription Contract Line No." <> 0)
        then
            case SubLine.Partner of
                SubLine.Partner::Customer:
                    if CustContractLine.Get(
                        SubLine."Subscription Contract No.",
                        SubLine."Subscription Contract Line No.")
                    then begin
                        CustContractLine.Closed := true;
                        CustContractLine.Modify(false);
                    end;
                SubLine.Partner::Vendor:
                    if VendContractLine.Get(
                        SubLine."Subscription Contract No.",
                        SubLine."Subscription Contract Line No.")
                    then begin
                        VendContractLine.Closed := true;
                        VendContractLine.Modify(false);
                    end;
            end;

        if SubHeader.Get(SubLine."Subscription Header No.") then begin
            AllClosed := true;
            SiblingLine.SetRange("Subscription Header No.", SubLine."Subscription Header No.");
            if SiblingLine.FindSet() then
                repeat
                    if not SiblingLine.Closed then
                        AllClosed := false;
                until (SiblingLine.Next() = 0) or (not AllClosed);

            if AllClosed and (SubHeader."Provision End Date" = 0D) then begin
                SubHeader."Provision End Date" := SubLine."Subscription Line End Date";
                SubHeader.Modify(false);
            end;
        end;

        Session.LogMessage('SKC-0072',
            StrSubstNo(LineClosedTxt, SubLine."Entry No.", SubLine."Subscription Line End Date"),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            'EntryNo', Format(SubLine."Entry No."));

        exit(true);
    end;
}
