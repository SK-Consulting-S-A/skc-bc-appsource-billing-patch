namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Marks the billing lines produced by interim billing.
///
/// An interim line charges only the quantity added mid-period, so it must not be
/// treated like an ordinary recurring line when the sales document is built.
/// Standard document creation reads the quantity from the Subscription Header
/// rather than the billing line, and the marker is what lets that be corrected
/// for interim charges alone.
/// </summary>
tableextension 70631053 BillingLine085SKC extends "Billing Line"
{
    fields
    {
        field(70631053; InterimBilling085SKC; Boolean)
        {
            Caption = 'Interim Billing';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(70631120; DeferralMethod085SKC; Enum SubDeferralMethod085SKC)
        {
            Caption = 'Deferral Method';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies the deferral engine resolved for this proposal line. The value is stamped when the line is created so that the proposal, the document, and the posted schedule can be compared afterwards.';
        }
        field(70631121; DynDeferralTemplate085SKC; Code[10])
        {
            Caption = 'Dynamic Deferral Template';
            DataClassification = SystemMetadata;
            Editable = false;
            TableRelation = "Deferral Template"."Deferral Code";
            ToolTip = 'Specifies the deferral template resolved for this proposal line.';
        }
    }
}
