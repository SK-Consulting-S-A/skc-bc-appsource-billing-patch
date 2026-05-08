namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631093 CustSubContractInterim003SKC extends "Customer Contract"
{
    actions
    {
        addlast(processing)
        {
            action(CreateInterimBilling003SKC)
            {
                ApplicationArea = All;
                Caption = 'Create Interim Billing';
                Image = CreateDocuments;
                ToolTip = 'Creates interim billing lines for unbilled quantity changes on this contract. Review in Recurring Billing, then use Create Documents.';
                Enabled = HasUnbilledChanges;

                trigger OnAction()
                var
                    InterimBillingMgmt: Codeunit InterimBillingMgmt003SKC;
                begin
                    InterimBillingMgmt.ProcessContract(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
        addlast(Category_Process)
        {
            actionref(CreateInterimBilling003SKC_Promoted; CreateInterimBilling003SKC) { }
        }
    }

    trigger OnAfterGetRecord()
    begin
        HasUnbilledChanges := InterimBillingMgmtGlobal.HasUnbilledChangesForContract(Rec."No.");
    end;

    var
        InterimBillingMgmtGlobal: Codeunit InterimBillingMgmt003SKC;
        HasUnbilledChanges: Boolean;
}
