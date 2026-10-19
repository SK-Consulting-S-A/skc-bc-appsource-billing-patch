namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.Purchases.History;

/// <summary>
/// Audit trail of the deferral engine on posted vendor credit memo lines.
/// </summary>
tableextension 70631107 PurchCrMemoLine085SKC extends "Purch. Cr. Memo Line"
{
    fields
    {
        field(70631120; DeferralMethod085SKC; Enum SubDeferralMethod085SKC)
        {
            Caption = 'Deferral Method';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies which deferral engine was used when this line was posted.';
        }
        field(70631121; DynDeferralTemplate085SKC; Code[10])
        {
            Caption = 'Dynamic Deferral Template';
            DataClassification = CustomerContent;
            Editable = false;
            TableRelation = "Deferral Template"."Deferral Code";
            ToolTip = 'Specifies the deferral template that produced the dynamic schedule for this posted line.';
        }
    }
}
