namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

codeunit 70631065 SubQtyChangeCapture085SKC
{
    Access = Internal;
    Permissions =
        tabledata SubQuantityHistory085SKC = IM;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Header", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidateQuantity(var Rec: Record "Subscription Header"; var xRec: Record "Subscription Header")
    var
        Setup: Record "Subscription Contract Setup";
        SubLine: Record "Subscription Line";
        QtyHistory: Record SubQuantityHistory085SKC;
    begin
        if not Setup.Get() then
            exit;
        if not Setup.EnableInterimBilling085SKC then
            exit;

        if Rec.Quantity = xRec.Quantity then
            exit;

        QtyHistory.Init();
        QtyHistory.SubscriptionHeaderNo085SKC := Rec."No.";
        QtyHistory.ChangeDate085SKC := WorkDate();
        QtyHistory.OldQuantity085SKC := xRec.Quantity;
        QtyHistory.NewQuantity085SKC := Rec.Quantity;
        QtyHistory.DeltaQuantity085SKC := Rec.Quantity - xRec.Quantity;
        QtyHistory.UserID085SKC := CopyStr(UserId(), 1, MaxStrLen(QtyHistory.UserID085SKC));

        SubLine.SetRange("Subscription Header No.", Rec."No.");
        SubLine.SetFilter("Subscription Contract No.", '<>%1', '');
        if SubLine.FindFirst() then
            QtyHistory.SubscriptionLineEntryNo085SKC := SubLine."Entry No.";

        QtyHistory.Insert(true);
    end;
}
