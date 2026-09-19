namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631093 CustSubContractInterim085SKC extends "Customer Contract"
{
    actions
    {
        addlast(processing)
        {
            action(CreateInterimBilling085SKC)
            {
                ApplicationArea = All;
                Caption = 'Create Interim Billing';
                Image = CreateDocuments;
                ToolTip = 'Creates interim billing lines for unbilled quantity changes on this contract. Review in Recurring Billing, then use Create Documents.';
                Visible = InterimBillingEnabled;
                Enabled = HasUnbilledChanges;

                trigger OnAction()
                var
                    InterimBillingMgmt: Codeunit InterimBillingMgmt085SKC;
                begin
                    InterimBillingMgmt.ProcessContract(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
        addlast(Category_Process)
        {
            actionref(CreateInterimBilling085SKC_Promoted; CreateInterimBilling085SKC) { }
        }
    }

    trigger OnOpenPage()
    begin
        InterimBillingEnabled := InterimBillingMgmtGlobal.IsInterimBillingEnabled();
    end;

    trigger OnAfterGetRecord()
    begin
        if InterimBillingEnabled then
            HasUnbilledChanges := InterimBillingMgmtGlobal.HasUnbilledChangesForContract(Rec."No.")
        else
            HasUnbilledChanges := false;
    end;

    var
        InterimBillingMgmtGlobal: Codeunit InterimBillingMgmt085SKC;
        InterimBillingEnabled: Boolean;
        HasUnbilledChanges: Boolean;
}
