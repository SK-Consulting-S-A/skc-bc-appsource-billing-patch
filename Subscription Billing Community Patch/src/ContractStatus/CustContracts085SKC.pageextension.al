namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631130 CustContracts085SKC extends "Customer Contracts"
{
    layout
    {
        addafter(Active)
        {
            field(ContractStatus085SKC; Rec.ContractStatus085SKC)
            {
                ApplicationArea = All;
                Caption = 'Contract Status';
                Editable = false;
                StyleExpr = ContractStatusStyle;
                ToolTip = 'Specifies the calculated lifecycle status: Active, Expiring, Ending, or Closed.';
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.ContractStatus085SKC of
            Enum::ContractStatus085SKC::Active:
                ContractStatusStyle := 'Favorable';
            Enum::ContractStatus085SKC::Expiring:
                ContractStatusStyle := 'Ambiguous';
            Enum::ContractStatus085SKC::Ending:
                ContractStatusStyle := 'AttentionAccent';
            Enum::ContractStatus085SKC::Closed:
                ContractStatusStyle := 'Unfavorable';
            else
                ContractStatusStyle := 'Standard';
        end;
    end;

    var
        ContractStatusStyle: Text;
}
