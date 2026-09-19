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
            group(DynamicDeferrals085SKC)
            {
                Caption = 'Deferrals';

                field(DefaultDeferralMethod085SKC; Rec.DefaultDeferralMethod085SKC)
                {
                    ApplicationArea = All;
                }
                field(CustDynDeferralTemplate085SKC; Rec.CustDynDeferralTemplate085SKC)
                {
                    ApplicationArea = All;
                }
                field(VendDynDeferralTemplate085SKC; Rec.VendDynDeferralTemplate085SKC)
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            action(DynDeferralAnalyses085SKC)
            {
                ApplicationArea = All;
                Caption = 'Dynamic Deferral Analysis';
                Image = Log;
                RunObject = page DynDeferralAnalyses085SKC;
                ToolTip = 'Opens the results of schedule simulations, document rebuilds, and posted deferral audits.';
            }
        }
    }
}
