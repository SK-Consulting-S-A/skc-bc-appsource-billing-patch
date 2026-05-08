namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631090 CustContractLineSubp003SKC extends "Customer Contract Line Subp."
{
    layout
    {
        addafter("Service Amount")
        {
            field(NextInvoiceAmount003SKC; NextInvoiceAmount)
            {
                ApplicationArea = All;
                Caption = 'Next Invoice Amount';
                ToolTip = 'Projected amount for the next regular invoice, based on Billing Base Period, Billing Rhythm, and the current line amount.';
                Editable = false;
                BlankZero = true;
                DecimalPlaces = 2 : 2;
            }
            field(SubscriptionClosed003SKC; SubscriptionClosed)
            {
                ApplicationArea = All;
                Caption = 'Subscription Closed';
                ToolTip = 'Indicates whether the linked Subscription Line is closed.';
                Editable = false;
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action(OpenSubscriptionCard003SKC)
            {
                ApplicationArea = All;
                Caption = 'Open Subscription';
                Image = ServiceItem;
                ToolTip = 'Open the subscription card for the selected contract line.';

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

    trigger OnAfterGetRecord()
    begin
        CalcNextInvoiceAmount();
    end;

    local procedure CalcNextInvoiceAmount()
    var
        SubscriptionLine: Record "Subscription Line";
        PreviewCalc: Codeunit SubInvoicePreviewCalc003SKC;
    begin
        NextInvoiceAmount := 0;
        SubscriptionClosed := false;
        if not Rec.GetServiceCommitment(SubscriptionLine) then
            exit;
        SubscriptionClosed := SubscriptionLine.Closed;
        SubscriptionLine.CalcFields(Quantity);
        NextInvoiceAmount := PreviewCalc.CalcNextInvoiceAmount(
            SubscriptionLine."Billing Base Period",
            SubscriptionLine."Billing Rhythm",
            SubscriptionLine.Amount);
    end;

    var
        NextInvoiceAmount: Decimal;
        SubscriptionClosed: Boolean;
}
