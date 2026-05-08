namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631092 ServiceObjectQtyHist003SKC extends "Service Object"
{
    layout
    {
        modify(Quantity)
        {
            trigger OnAssistEdit()
            var
                QtyHistory: Record SubQuantityHistory003SKC;
                QtyHistoryPage: Page SubQuantityHistoryList003SKC;
            begin
                QtyHistory.SetRange(SubscriptionHeaderNo003SKC, Rec."No.");
                QtyHistoryPage.SetTableView(QtyHistory);
                QtyHistoryPage.RunModal();
            end;
        }

        addfirst(FactBoxes)
        {
            part(QuantityHistory003SKC; SubQuantityHistoryList003SKC)
            {
                ApplicationArea = All;
                Caption = 'Quantity History';
                SubPageLink = SubscriptionHeaderNo003SKC = field("No.");
            }
        }
    }
}
