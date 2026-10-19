namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631133 RecurringBilling085SKC extends "Recurring Billing"
{
    layout
    {
        addafter("Billing to")
        {
            field(DeferralMethod085SKC; Rec.DeferralMethod085SKC)
            {
                ApplicationArea = All;
            }
            field(DynDeferralTemplate085SKC; Rec.DynDeferralTemplate085SKC)
            {
                ApplicationArea = All;
            }
        }
    }
}
