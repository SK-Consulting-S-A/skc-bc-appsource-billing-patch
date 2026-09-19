namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.Sales.Document;

/// <summary>
/// Carries the resolved deferral engine onto a draft sales line.
///
/// The value is written when the billing document is created and is not edited
/// by hand: it records which engine the line was created under, so a proposal
/// reviewed before a configuration change still posts the way it was reviewed.
/// </summary>
tableextension 70631102 SalesLine085SKC extends "Sales Line"
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
