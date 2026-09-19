namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.Sales.History;

/// <summary>
/// Audit trail of the deferral engine on posted customer credit memo lines, so
/// a reversal can be matched to the invoice schedule it unwinds.
/// </summary>
tableextension 70631105 SalesCrMemoLine085SKC extends "Sales Cr.Memo Line"
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
