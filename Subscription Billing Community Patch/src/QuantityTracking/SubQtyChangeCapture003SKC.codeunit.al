namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

codeunit 70631065 SubQtyChangeCapture003SKC
{
    Access = Internal;
    Permissions =
        tabledata SubQuantityHistory003SKC = IM;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Header", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidateQuantity(var Rec: Record "Subscription Header"; var xRec: Record "Subscription Header")
    var
        SubLine: Record "Subscription Line";
        QtyHistory: Record SubQuantityHistory003SKC;
    begin
        if Rec.Quantity = xRec.Quantity then
            exit;

        QtyHistory.Init();
        QtyHistory.SubscriptionHeaderNo003SKC := Rec."No.";
        QtyHistory.ChangeDate003SKC := WorkDate();
        QtyHistory.OldQuantity003SKC := xRec.Quantity;
        QtyHistory.NewQuantity003SKC := Rec.Quantity;
        QtyHistory.DeltaQuantity003SKC := Rec.Quantity - xRec.Quantity;
        QtyHistory.UserID003SKC := CopyStr(UserId(), 1, MaxStrLen(QtyHistory.UserID003SKC));

        SubLine.SetRange("Subscription Header No.", Rec."No.");
        SubLine.SetFilter("Subscription Contract No.", '<>%1', '');
        if SubLine.FindFirst() then
            QtyHistory.SubscriptionLineEntryNo003SKC := SubLine."Entry No.";

        QtyHistory.Insert(true);
    end;
}
