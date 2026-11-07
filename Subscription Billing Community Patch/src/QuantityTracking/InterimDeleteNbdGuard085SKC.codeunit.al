namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Keeps Next Billing Date when an interim billing line is deleted.
/// Standard Billing Line deletion resets the subscription line's Next Billing Date to the
/// deleted line's Billing from. That is right for a regular proposal line, but an interim
/// line sits inside a period that was already invoiced and never moved the date, so the
/// reset would make the next proposal bill that period again.
/// Single instance so the date read before the delete is still available after it.
/// </summary>
codeunit 70631070 InterimDeleteNbdGuard085SKC
{
    Access = Internal;
    SingleInstance = true;
    Permissions =
        tabledata "Subscription Line" = RM;

    var
        SavedNextBillingDates: Dictionary of [Integer, Date];

    [EventSubscriber(ObjectType::Table, Database::"Billing Line", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure RememberNextBillingDate(var Rec: Record "Billing Line"; RunTrigger: Boolean)
    var
        SubLine: Record "Subscription Line";
        InterimBillingMgmt: Codeunit InterimBillingMgmt085SKC;
    begin
        if not RunTrigger then
            exit;
        if Rec.IsTemporary() then
            exit;
        if not Rec.InterimBilling085SKC then
            exit;
        if not InterimBillingMgmt.IsInterimBillingEnabled() then
            exit;
        if SubLine.Get(Rec."Subscription Line Entry No.") then
            SavedNextBillingDates.Set(Rec."Entry No.", SubLine."Next Billing Date");
    end;

    [EventSubscriber(ObjectType::Table, Database::"Billing Line", 'OnAfterDeleteEvent', '', false, false)]
    local procedure RestoreNextBillingDate(var Rec: Record "Billing Line"; RunTrigger: Boolean)
    var
        SubLine: Record "Subscription Line";
        SavedDate: Date;
    begin
        if Rec.IsTemporary() then
            exit;
        if not SavedNextBillingDates.Get(Rec."Entry No.", SavedDate) then
            exit;
        SavedNextBillingDates.Remove(Rec."Entry No.");
        if not SubLine.Get(Rec."Subscription Line Entry No.") then
            exit;
        if SubLine."Next Billing Date" = SavedDate then
            exit;
        SubLine."Next Billing Date" := SavedDate;
        SubLine.Modify(false);
    end;
}
