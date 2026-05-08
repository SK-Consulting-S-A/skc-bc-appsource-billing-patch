namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631094 SubBillingRoleCenter003SKC extends "Sub. Billing Role Center"
{
    layout
    {
        addafter(ManagementActivities)
        {
            part(ExpiringActivities003SKC; SubExpiringActivities003SKC)
            {
                ApplicationArea = All;
            }
        }
    }
}
