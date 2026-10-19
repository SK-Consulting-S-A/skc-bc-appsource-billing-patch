namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Calculates and maintains the ContractStatus085SKC field on Customer
/// Subscription Contracts. The status is derived from the aggregate state
/// of all linked Subscription Lines (via Cust. Sub. Contract Lines).
///
/// Status derivation (evaluated top-to-bottom, first match wins):
///   Blank    – no subscription lines assigned to the contract
///   Closed   – all lines are closed
///   Ending   – every non-closed line has an end date set (contract winding down)
///   Expiring – at least one non-closed line expires within 90 days
///   Active   – at least one non-closed line with no imminent expiration
///
/// Recalculation is triggered by event subscribers on Subscription Line
/// and Cust. Sub. Contract Line modifications.
/// </summary>
codeunit 70631126 ContractStatusCalc085SKC
{
    Access = Public;
    Permissions =
        tabledata "Cust. Sub. Contract Line" = R,
        tabledata "Customer Subscription Contract" = RM,
        tabledata "Subscription Line" = R;

    var
        ExpirationThresholdDays: Integer;
        BatchCompletedTxt: Label 'Contract status batch recalc completed. Total: %1, Changed: %2', Locked = true;
        ExpirationFormulaTok: Label '<+%1D>', Locked = true;

    /// <summary>
    /// Pure calculation: derives the status from subscription lines
    /// without modifying any records.
    /// </summary>
    procedure CalcContractStatus(ContractNo: Code[20]): Enum ContractStatus085SKC
    var
        SubLine: Record "Subscription Line";
        AllOpenLinesHaveEndDate: Boolean;
        HasExpiringLine: Boolean;
        HasOpenLines: Boolean;
        ExpirationCutoff: Date;
    begin
        ExpirationThresholdDays := 90;
        ExpirationCutoff := CalcDate(StrSubstNo(ExpirationFormulaTok, ExpirationThresholdDays), Today);

        SubLine.SetRange("Subscription Contract No.", ContractNo);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        if SubLine.IsEmpty() then
            exit(ContractStatus085SKC::" ");

        AllOpenLinesHaveEndDate := true;

        SubLine.FindSet();
        repeat
            if not SubLine.Closed then begin
                HasOpenLines := true;

                if SubLine."Subscription Line End Date" = 0D then
                    AllOpenLinesHaveEndDate := false
                else
                    if SubLine."Subscription Line End Date" <= ExpirationCutoff then
                        HasExpiringLine := true;
            end;
        until SubLine.Next() = 0;

        if not HasOpenLines then
            exit(ContractStatus085SKC::Closed);

        if AllOpenLinesHaveEndDate then
            exit(ContractStatus085SKC::Ending);

        if HasExpiringLine then
            exit(ContractStatus085SKC::Expiring);

        exit(ContractStatus085SKC::Active);
    end;

    /// <summary>
    /// Batch-recalculates status for all customer contracts.
    /// Returns the number of contracts whose status changed.
    /// </summary>
    procedure RecalcAllContractStatuses(): Integer
    var
        CustContract: Record "Customer Subscription Contract";
        NewStatus: Enum ContractStatus085SKC;
        ChangedCount: Integer;
    begin
        if not CustContract.FindSet(true) then
            exit(0);

        repeat
            NewStatus := CalcContractStatus(CustContract."No.");
            if CustContract.ContractStatus085SKC <> NewStatus then begin
                CustContract.ContractStatus085SKC := NewStatus;
                CustContract.Modify(false);
                ChangedCount += 1;
            end;
        until CustContract.Next() = 0;

        Session.LogMessage('SBCP0001',
            StrSubstNo(BatchCompletedTxt, CustContract.Count(), ChangedCount),
            Verbosity::Normal, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher,
            'TotalContracts', Format(CustContract.Count()), 'ChangedCount', Format(ChangedCount));

        exit(ChangedCount);
    end;

    /// <summary>
    /// Recalculates the status for a single contract.
    /// </summary>
    procedure UpdateContractStatus(ContractNo: Code[20])
    var
        CustContract: Record "Customer Subscription Contract";
    begin
        if ContractNo = '' then
            exit;
        if not CustContract.Get(ContractNo) then
            exit;

        UpdateContractStatusRec(CustContract);
    end;

    /// <summary>
    /// Recalculates the status for a contract record already in hand.
    /// </summary>
    procedure UpdateContractStatusRec(var CustContract: Record "Customer Subscription Contract")
    var
        NewStatus: Enum ContractStatus085SKC;
    begin
        NewStatus := CalcContractStatus(CustContract."No.");

        if CustContract.ContractStatus085SKC <> NewStatus then begin
            CustContract.ContractStatus085SKC := NewStatus;
            CustContract.Modify(false);
        end;
    end;

    local procedure StatusRelevantFieldChanged(SubLine: Record "Subscription Line"; xSubLine: Record "Subscription Line"): Boolean
    begin
        exit(
            (SubLine.Closed <> xSubLine.Closed) or
            (SubLine."Subscription Line End Date" <> xSubLine."Subscription Line End Date") or
            (SubLine."Subscription Contract No." <> xSubLine."Subscription Contract No."));
    end;

    [EventSubscriber(ObjectType::Table, Database::"Cust. Sub. Contract Line", OnAfterDeleteEvent, '', false, false)]
    local procedure OnContractLineDeleted(var Rec: Record "Cust. Sub. Contract Line"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        UpdateContractStatus(Rec."Subscription Contract No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Cust. Sub. Contract Line", OnAfterInsertEvent, '', false, false)]
    local procedure OnContractLineInserted(var Rec: Record "Cust. Sub. Contract Line"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        UpdateContractStatus(Rec."Subscription Contract No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Cust. Sub. Contract Line", OnAfterModifyEvent, '', false, false)]
    local procedure OnContractLineModified(var Rec: Record "Cust. Sub. Contract Line"; var xRec: Record "Cust. Sub. Contract Line"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec.Closed = xRec.Closed then
            exit;
        UpdateContractStatus(Rec."Subscription Contract No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnAfterDeleteEvent, '', false, false)]
    local procedure OnSubLineDeleted(var Rec: Record "Subscription Line"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        UpdateContractStatus(Rec."Subscription Contract No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnAfterInsertEvent, '', false, false)]
    local procedure OnSubLineInserted(var Rec: Record "Subscription Line"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        UpdateContractStatus(Rec."Subscription Contract No.");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnAfterModifyEvent, '', false, false)]
    local procedure OnSubLineModified(var Rec: Record "Subscription Line"; var xRec: Record "Subscription Line"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;
        if not StatusRelevantFieldChanged(Rec, xRec) then
            exit;

        UpdateContractStatus(Rec."Subscription Contract No.");
        if (xRec."Subscription Contract No." <> '') and (xRec."Subscription Contract No." <> Rec."Subscription Contract No.") then
            UpdateContractStatus(xRec."Subscription Contract No.");
    end;
}
