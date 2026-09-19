namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631131 ClosedCustContLineSubp085SKC extends "Closed Cust. Cont. Line Subp."
{
    actions
    {
        addlast(processing)
        {
            action(OpenSubscriptionCard085SKC)
            {
                ApplicationArea = All;
                Caption = 'Open Subscription';
                Image = ServiceItem;
                ToolTip = 'Opens the subscription card for the selected closed contract line.';

                trigger OnAction()
                var
                    SubscriptionHeader: Record "Subscription Header";
                begin
                    if Rec."Subscription Header No." = '' then
                        exit;
                    SubscriptionHeader.Get(Rec."Subscription Header No.");
                    Page.Run(Page::"Service Object", SubscriptionHeader);
                end;
            }
        }
    }
}
