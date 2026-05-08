namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Auto-reopens subscription lines closed by the standard UpdateServicesDates
/// when AutoRenewal003SKC is enabled.
///
/// Real-time path: OnAfterModifyEvent on Subscription Line detects the close,
///   captures Term Until into TermUntilBackup003SKC, and immediately re-opens
///   the line (clears end date, restores Term Until, sets Closed := false).
///   A matching subscriber on Cust. Sub. Contract Line re-opens contract lines
///   that the standard subsequently closes via CloseOpenCustomerContractLines.
///
/// Batch fallback: ReopenAutoRenewalSubscriptions catches lines that were
///   closed before this code was deployed or where the real-time path missed.
///   Falls back to the current "Term Until" when the backup field is blank.
/// </summary>
codeunit 70631066 SubAutoReopen003SKC
{
    Access = Internal;

    var
        SubLineReopenedTxt: Label 'Subscription Line %1 auto-reopened, Term Until restored to %2', Locked = true;
        ContractLineReopenedTxt: Label 'Contract line %1/%2 re-opened for auto-renewal', Locked = true;
        BatchCompletedTxt: Label 'Batch auto-reopen completed. Reopened: %1, Skipped: %2', Locked = true;
        VendOrphansLinkedTxt: Label '%1 vendor subscription lines linked to contract %2', Locked = true;

    // ── Real-time: detect close and immediately re-open ──────────────

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnAfterModifyEvent, '', false, false)]
    local procedure OnAfterSubLineModified(var Rec: Record "Subscription Line"; var xRec: Record "Subscription Line"; RunTrigger: Boolean)
    var
        SubLine: Record "Subscription Line";
        TermUntilToRestore: Date;
        IsHandled: Boolean;
    begin
        if Rec.IsTemporary() then
            exit;
        if not (Rec.Closed and not xRec.Closed) then
            exit;
        if not Rec.AutoRenewal003SKC then
            exit;

        TermUntilToRestore := xRec."Term Until";

        SubLine.Get(Rec."Entry No.");
        SubLine.TermUntilBackup003SKC := TermUntilToRestore;

        OnBeforeAutoReopenSubscriptionLine(SubLine, IsHandled);
        if IsHandled then begin
            SubLine.Modify(false);
            exit;
        end;

        ReopenSubscriptionLine(SubLine, TermUntilToRestore);
    end;

    // ── Contract Line: keep in sync with subscription line ──────────

    [EventSubscriber(ObjectType::Table, Database::"Cust. Sub. Contract Line", OnAfterModifyEvent, '', false, false)]
    local procedure OnAfterContractLineModified(var Rec: Record "Cust. Sub. Contract Line"; var xRec: Record "Cust. Sub. Contract Line"; RunTrigger: Boolean)
    var
        SubLine: Record "Subscription Line";
    begin
        if Rec.IsTemporary() then
            exit;
        if not SubLine.Get(Rec."Subscription Line Entry No.") then
            exit;

        if Rec.Closed and not xRec.Closed then
            HandleContractLineClosed(Rec, SubLine)
        else
            if not Rec.Closed and xRec.Closed then
                HandleContractLineReopened(SubLine);
    end;

    local procedure HandleContractLineClosed(var ContractLine: Record "Cust. Sub. Contract Line"; SubLine: Record "Subscription Line")
    begin
        if SubLine.Closed then
            exit;
        if not SubLine.AutoRenewal003SKC then
            exit;

        ContractLine.Closed := false;
        ContractLine.Modify(false);

        Session.LogMessage('SKC-0053',
            StrSubstNo(ContractLineReopenedTxt, ContractLine."Subscription Contract No.", ContractLine."Line No."),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            'ContractNo', ContractLine."Subscription Contract No.", 'LineNo', Format(ContractLine."Line No."));
    end;

    local procedure HandleContractLineReopened(var SubLine: Record "Subscription Line")
    begin
        if not SubLine.Closed then
            exit;

        ReopenSubscriptionLine(SubLine, SubLine.TermUntilBackup003SKC);
    end;

    // ── Core re-open logic ───────────────────────────────────────────

    procedure ReopenSubscriptionLine(var SubLine: Record "Subscription Line"; TermUntilToRestore: Date)
    begin
        if TermUntilToRestore = 0D then
            TermUntilToRestore := SubLine."Term Until";

        SubLine."Subscription Line End Date" := 0D;
        SubLine."Term Until" := TermUntilToRestore;
        SubLine.Closed := false;
        SubLine.TermUntilBackup003SKC := 0D;
        SubLine.Modify(false);

        OnAfterAutoReopenSubscriptionLine(SubLine);

        Session.LogMessage('SKC-0051',
            StrSubstNo(SubLineReopenedTxt, SubLine."Entry No.", TermUntilToRestore),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            'EntryNo', Format(SubLine."Entry No."), 'TermUntil', Format(TermUntilToRestore));
    end;

    // ── Batch fallback ───────────────────────────────────────────────

    /// <summary>
    /// Catches closed auto-renewal lines that were not re-opened by the
    /// real-time event (e.g. lines closed before this code was deployed).
    /// Falls back to the current "Term Until" when TermUntilBackup003SKC
    /// is blank. Safe to call from a job queue entry or manually.
    /// </summary>
    procedure ReopenAutoRenewalSubscriptions(): Integer
    var
        SubLine: Record "Subscription Line";
        ReopenedCount: Integer;
        SkippedCount: Integer;
        IsHandled: Boolean;
    begin
        SubLine.SetRange(Closed, true);
        SubLine.SetRange(AutoRenewal003SKC, true);
        if not SubLine.FindSet(true) then
            exit(0);

        repeat
            IsHandled := false;
            OnBeforeAutoReopenSubscriptionLine(SubLine, IsHandled);
            if IsHandled then begin
                SkippedCount += 1;
            end else begin
                ReopenSubscriptionLine(SubLine, SubLine.TermUntilBackup003SKC);
                ReopenContractLinesForSubscription(SubLine);
                ReopenedCount += 1;
            end;
        until SubLine.Next() = 0;

        Session.LogMessage('SKC-0052',
            StrSubstNo(BatchCompletedTxt, ReopenedCount, SkippedCount),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            'ReopenedCount', Format(ReopenedCount), 'SkippedCount', Format(SkippedCount));

        exit(ReopenedCount);
    end;

    procedure ReopenContractLinesForSubscription(SubLine: Record "Subscription Line")
    var
        CustContractLine: Record "Cust. Sub. Contract Line";
    begin
        CustContractLine.SetRange("Subscription Line Entry No.", SubLine."Entry No.");
        CustContractLine.SetRange(Closed, true);
        if not CustContractLine.IsEmpty() then
            CustContractLine.ModifyAll(Closed, false, false);
    end;

    // ── Vendor orphan link ──────────────────────────────────────────

    procedure LinkOrphanVendorLines(ContractNo: Code[20]): Integer
    var
        SubLine: Record "Subscription Line";
        VendContractLine: Record "Vend. Sub. Contract Line";
        NewLineNo: Integer;
        LinkedCount: Integer;
    begin
        VendContractLine.SetRange("Subscription Contract No.", ContractNo);
        if VendContractLine.FindLast() then
            NewLineNo := VendContractLine."Line No."
        else
            NewLineNo := 0;

        SubLine.SetRange(Partner, SubLine.Partner::Vendor);
        SubLine.SetRange("Subscription Contract No.", ContractNo);
        SubLine.SetRange("Subscription Contract Line No.", 0);
        if not SubLine.FindSet(true) then
            exit(0);

        repeat
            NewLineNo += 10000;

            VendContractLine.Init();
            VendContractLine."Subscription Contract No." := ContractNo;
            VendContractLine."Line No." := NewLineNo;
            VendContractLine."Subscription Header No." := SubLine."Subscription Header No.";
            VendContractLine."Subscription Line Entry No." := SubLine."Entry No.";
            VendContractLine.Closed := SubLine.Closed;
            VendContractLine.Insert(false);

            SubLine."Subscription Contract Line No." := NewLineNo;
            SubLine.Modify(false);
            LinkedCount += 1;
        until SubLine.Next() = 0;

        Session.LogMessage('SKC-0060',
            StrSubstNo(VendOrphansLinkedTxt, LinkedCount, ContractNo),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            'LinkedCount', Format(LinkedCount), 'ContractNo', ContractNo);

        exit(LinkedCount);
    end;

    // ── Integration Events ───────────────────────────────────────────

    [IntegrationEvent(false, false)]
    local procedure OnBeforeAutoReopenSubscriptionLine(var SubLine: Record "Subscription Line"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterAutoReopenSubscriptionLine(var SubLine: Record "Subscription Line")
    begin
    end;
}
