namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Writable singleton for the dynamic deferral configuration.
///
///   GET   /.../dynamicDeferralSetups
///   PATCH /.../dynamicDeferralSetups({id})
///     body: { "defaultDeferralMethod": "Standard Dynamic",
///             "customerDeferralTemplate": "SUBDYN" }
/// </summary>
page 70631117 apiDynDeferralSetup085SKC
{
    APIGroup = 'subscriptionBilling';
    APIPublisher = 'skconsulting';
    APIVersion = 'v1.0';
    Caption = 'Dynamic Deferral Setup';
    DeleteAllowed = false;
    EntityName = 'dynamicDeferralSetup';
    EntitySetName = 'dynamicDeferralSetups';
    InsertAllowed = false;
    ModifyAllowed = true;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "Subscription Contract Setup";

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'id';
                    Editable = false;
                }
                field(defaultDeferralMethod; Rec.DefaultDeferralMethod085SKC) { Caption = 'defaultDeferralMethod'; }
                field(customerDeferralTemplate; Rec.CustDynDeferralTemplate085SKC) { Caption = 'customerDeferralTemplate'; }
                field(vendorDeferralTemplate; Rec.VendDynDeferralTemplate085SKC) { Caption = 'vendorDeferralTemplate'; }
                field(nativeCreateContractDeferrals; Rec."Create Contract Deferrals")
                {
                    Caption = 'nativeCreateContractDeferrals';
                    Editable = false;
                }
            }
        }
    }
}
