namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631092 ServiceObjectQtyHist085SKC extends "Service Object"
{
    layout
    {
        modify(Quantity)
        {
            trigger OnAssistEdit()
            var
                QtyHistory: Record SubQuantityHistory085SKC;
                QtyHistoryPage: Page SubQuantityHistoryList085SKC;
            begin
                QtyHistory.SetRange(SubscriptionHeaderNo085SKC, Rec."No.");
                QtyHistoryPage.SetTableView(QtyHistory);
                QtyHistoryPage.RunModal();
            end;
        }

        addfirst(FactBoxes)
        {
            part(SubMargin085SKC; SubMarginFactBox085SKC)
            {
                ApplicationArea = All;
                Caption = 'Subscription Margin';
                SubPageLink = "No." = field("No.");
            }
            part(QuantityHistory085SKC; SubQuantityHistoryList085SKC)
            {
                ApplicationArea = All;
                Caption = 'Quantity History';
                SubPageLink = SubscriptionHeaderNo085SKC = field("No.");
            }
        }
    }
}
