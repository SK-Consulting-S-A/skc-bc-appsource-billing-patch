namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631129 CustContractReadiness085SKC extends "Customer Contract"
{
    layout
    {
        addafter("Active")
        {
            field(ContractStatus085SKC; Rec.ContractStatus085SKC)
            {
                ApplicationArea = All;
                Caption = 'Contract Status';
                Editable = false;
                StyleExpr = ContractStatusStyle;
                ToolTip = 'Specifies the calculated lifecycle status of the contract: Active, Expiring (within 90 days), Ending (all lines have end dates), or Closed.';
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action(CheckBillingReadiness085SKC)
            {
                ApplicationArea = All;
                Caption = 'Check Billing Readiness';
                Image = CheckRulesSyntax;
                ToolTip = 'Checks whether all subscription lines on this contract are properly set up for billing (price, next billing date, and billing cadence).';

                trigger OnAction()
                var
                    BillingReadiness: Codeunit BillingReadiness085SKC;
                begin
                    BillingReadiness.CheckContractReadiness(Rec."No.");
                end;
            }
            action(RefreshContractStatus085SKC)
            {
                ApplicationArea = All;
                Caption = 'Refresh Status';
                Image = Refresh;
                ToolTip = 'Recalculates the contract lifecycle status from the current subscription lines.';

                trigger OnAction()
                var
                    StatusCalc: Codeunit ContractStatusCalc085SKC;
                begin
                    StatusCalc.UpdateContractStatusRec(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
        addlast(Category_Process)
        {
            actionref(CheckBillingReadiness085SKC_Promoted; CheckBillingReadiness085SKC) { }
            actionref(RefreshContractStatus085SKC_Promoted; RefreshContractStatus085SKC) { }
        }
    }

    var
        ContractStatusStyle: Text;

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
}
