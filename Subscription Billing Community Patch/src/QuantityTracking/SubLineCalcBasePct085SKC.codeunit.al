namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// When enabled in Subscription Contract Setup, keeps Calculation Base % at 100 on
/// subscription lines (insert, modify, validate, rename) and hides the field in the UI.
/// </summary>
codeunit 70631068 SubLineCalcBasePct085SKC
{
    Access = Internal;

    procedure IsLocked(): Boolean
    var
        Setup: Record "Subscription Contract Setup";
    begin
        if not Setup.Get() then
            exit(false);
        exit(Setup.LockCalcBasePct100085SKC);
    end;

    procedure EnforceHundredPercent(var SubLine: Record "Subscription Line")
    begin
        if not IsLocked() then
            exit;
        if SubLine.IsTemporary() then
            exit;
        if SubLine."Calculation Base %" = 100 then
            exit;
        SubLine.Validate("Calculation Base %", 100);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnBeforeInsertEvent, '', false, false)]
    local procedure OnBeforeSubscriptionLineInsert(var Rec: Record "Subscription Line"; RunTrigger: Boolean)
    begin
        EnforceHundredPercent(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnBeforeModifyEvent, '', false, false)]
    local procedure OnBeforeSubscriptionLineModify(var Rec: Record "Subscription Line"; var xRec: Record "Subscription Line"; RunTrigger: Boolean)
    begin
        EnforceHundredPercent(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnAfterInsertEvent, '', false, false)]
    local procedure OnAfterSubscriptionLineInsert(var Rec: Record "Subscription Line"; RunTrigger: Boolean)
    begin
        EnforceHundredPercentAndPersist(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnAfterModifyEvent, '', false, false)]
    local procedure OnAfterSubscriptionLineModify(var Rec: Record "Subscription Line"; var xRec: Record "Subscription Line"; RunTrigger: Boolean)
    begin
        if Rec."Calculation Base %" = xRec."Calculation Base %" then
            exit;
        EnforceHundredPercentAndPersist(Rec);
    end;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnBeforeValidateEvent, 'Calculation Base %', false, false)]
    local procedure OnBeforeValidateCalculationBasePercent(var Rec: Record "Subscription Line"; var xRec: Record "Subscription Line"; CurrFieldNo: Integer)
    begin
        if not IsLocked() then
            exit;
        Rec."Calculation Base %" := 100;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Line", OnAfterRenameEvent, '', false, false)]
    local procedure OnAfterSubscriptionLineRename(var Rec: Record "Subscription Line"; var xRec: Record "Subscription Line"; RunTrigger: Boolean)
    begin
        EnforceHundredPercentAndPersist(Rec);
    end;

    local procedure EnforceHundredPercentAndPersist(var SubLine: Record "Subscription Line")
    var
        SubLineToUpdate: Record "Subscription Line";
    begin
        if not IsLocked() then
            exit;
        if SubLine.IsTemporary() then
            exit;
        if SubLine."Calculation Base %" = 100 then
            exit;

        SubLineToUpdate.Get(SubLine."Entry No.");
        SubLineToUpdate.Validate("Calculation Base %", 100);
        SubLineToUpdate.Modify(true);
        SubLine."Calculation Base %" := 100;
    end;
}
