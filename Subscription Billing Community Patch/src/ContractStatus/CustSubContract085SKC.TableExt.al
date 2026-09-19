namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

tableextension 70631125 CustSubContract085SKC extends "Customer Subscription Contract"
{
    fields
    {
        field(70631052; ContractStatus085SKC; Enum ContractStatus085SKC)
        {
            Caption = 'Contract Status';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies the lifecycle status derived from the subscription lines on this contract.';
        }
    }
}
