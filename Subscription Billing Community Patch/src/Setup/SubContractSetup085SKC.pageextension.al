namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631098 SubContractSetup085SKC extends "Service Contract Setup"
{
    layout
    {
        addlast(Content)
        {
            group(CommunityPatch085SKC)
            {
                Caption = 'Community Patch';

                field(EnableInterimBilling085SKC; Rec.EnableInterimBilling085SKC)
                {
                    ApplicationArea = All;
                }
                field(LockCalcBasePct100085SKC; Rec.LockCalcBasePct100085SKC)
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
