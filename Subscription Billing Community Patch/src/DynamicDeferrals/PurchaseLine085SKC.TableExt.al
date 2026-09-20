namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.Purchases.Document;

/// <summary>
/// Carries the resolved deferral engine onto a draft purchase line.
/// </summary>
tableextension 70631103 PurchaseLine085SKC extends "Purchase Line"
{
    fields
    {
        field(70631120; DeferralMethod085SKC; Enum SubDeferralMethod085SKC)
        {
            Caption = 'Deferral Method';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies which deferral engine applies to this subscription billing line. The value is resolved when the billing document is created.';
        }
        field(70631121; DynDeferralTemplate085SKC; Code[10])
        {
            Caption = 'Dynamic Deferral Template';
            DataClassification = CustomerContent;
            Editable = false;
            TableRelation = "Deferral Template"."Deferral Code";
            ToolTip = 'Specifies the deferral template used to build the dynamic schedule from the recurring billing period on this line.';
        }
    }
}
