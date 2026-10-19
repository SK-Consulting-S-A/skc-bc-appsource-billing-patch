namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631094 SubBillingRoleCenter085SKC extends "Sub. Billing Role Center"
{
    layout
    {
        addafter(ManagementActivities)
        {
            part(BillingReadiness085SKC; BillingReadinessAct085SKC)
            {
                ApplicationArea = All;
            }
            part(ExpiringActivities085SKC; SubExpiringActivities085SKC)
            {
                ApplicationArea = All;
            }
        }
    }
}
