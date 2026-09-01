namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Carries the resolved deferral engine into the billing archive.
///
/// The archive is the only surviving record of what a proposal line looked like
/// once the document is posted and the Billing Line is deleted, so an audit
/// that compares proposal against posted schedule needs the method here too.
/// </summary>
tableextension 70631108 BillingLineArchive085SKC extends "Billing Line Archive"
{
    fields
    {
        field(70631120; DeferralMethod085SKC; Enum SubDeferralMethod085SKC)
        {
            Caption = 'Deferral Method';
            DataClassification = SystemMetadata;
            Editable = false;
            ToolTip = 'Specifies the deferral engine that was resolved for the proposal line this archive entry came from.';
        }
        field(70631121; DynDeferralTemplate085SKC; Code[10])
        {
            Caption = 'Dynamic Deferral Template';
            DataClassification = SystemMetadata;
            Editable = false;
            TableRelation = "Deferral Template"."Deferral Code";
            ToolTip = 'Specifies the deferral template that was resolved for the proposal line this archive entry came from.';
        }
    }
}
