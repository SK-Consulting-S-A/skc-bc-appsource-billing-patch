namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

tableextension 70631096 SubscriptionHeader085SKC extends "Subscription Header"
{
    fields
    {
        field(70631050; CustLineCount085SKC; Integer)
        {
            Caption = 'Customer Lines';
            FieldClass = FlowField;
            CalcFormula = count("Subscription Line" where(
                "Subscription Header No." = field("No."),
                Partner = const(Customer)));
            Editable = false;
        }
        field(70631051; ClosedCustLineCount085SKC; Integer)
        {
            Caption = 'Closed Customer Lines';
            FieldClass = FlowField;
            CalcFormula = count("Subscription Line" where(
                "Subscription Header No." = field("No."),
                Partner = const(Customer),
                Closed = const(true)));
            Editable = false;
        }
    }
}
