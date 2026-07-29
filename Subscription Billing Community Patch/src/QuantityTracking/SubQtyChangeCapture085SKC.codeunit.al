namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

codeunit 70631065 SubQtyChangeCapture085SKC
{
    Access = Internal;
    Permissions =
        tabledata SubQuantityHistory085SKC = IM,
        tabledata "Billing Line" = RM;

    [EventSubscriber(ObjectType::Table, Database::"Subscription Header", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure OnAfterValidateQuantity(var Rec: Record "Subscription Header"; var xRec: Record "Subscription Header")
    var
        Setup: Record "Subscription Contract Setup";
        SubLine: Record "Subscription Line";
        QtyHistory: Record SubQuantityHistory085SKC;
    begin
        if Rec.Quantity = xRec.Quantity then
            exit;

        // The standard module flags billing lines as needing an update whenever a
        // Subscription Line is modified, but a Subscription Header quantity change is not
        // covered even though it drives Service Object Quantity on the billing line and
        // Quantity on the resulting document line. Without this, an open proposal keeps a
        // stale quantity and no warning is raised.
        MarkOpenBillingLinesUpdateRequired(Rec."No.");

        if not Setup.Get() then
            exit;
        if not Setup.EnableInterimBilling085SKC then
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

    /// <summary>
    /// Flags proposal billing lines for the subscription as needing an update. Only lines
    /// without a document are touched, because the standard validation rejects the flag
    /// once an unposted invoice or credit memo exists.
    /// </summary>
    local procedure MarkOpenBillingLinesUpdateRequired(SubscriptionHeaderNo: Code[20])
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.SetRange("Subscription Header No.", SubscriptionHeaderNo);
        BillingLine.SetRange("Document No.", '');
        if BillingLine.FindSet(true) then
            repeat
                BillingLine.Validate("Update Required", true);
                BillingLine.Modify(false);
            until BillingLine.Next() = 0;
    end;
}
