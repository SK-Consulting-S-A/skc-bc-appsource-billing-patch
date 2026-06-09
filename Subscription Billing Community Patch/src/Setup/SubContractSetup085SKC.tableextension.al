namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

tableextension 70631097 SubContractSetup085SKC extends "Subscription Contract Setup"
{
    fields
    {
        field(70631050; EnableInterimBilling085SKC; Boolean)
        {
            Caption = 'Enable Interim Billing';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether mid-cycle quantity changes are captured and made available for interim (pro-rata) billing. When disabled, quantity-change tracking and the interim billing actions are turned off.';
        }
        field(70631051; LockCalcBasePct100085SKC; Boolean)
        {
            Caption = 'Lock Calculation Base % at 100';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether the Calculation Base % on subscription lines is forced to 100 and hidden in the UI. Enable this when you always bill the full calculation base.';
        }
    }
}
