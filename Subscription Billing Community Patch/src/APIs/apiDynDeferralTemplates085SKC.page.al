namespace SKC.Subscription;

using Microsoft.Finance.Deferral;

/// <summary>
/// Controlled create and update of the standard deferral templates used by the
/// dynamic engine. The generated Deferral Header and Deferral Line records are
/// exposed read-only: they are derived from the document line and must never be
/// edited out of band.
///
///   POST /.../dynamicDeferralTemplates
///     body: { "deferralCode": "SUBDYN", "description": "Subscription revenue",
///             "deferralAccount": "2900", "dynamicSubscriptionSchedule": true }
/// </summary>
page 70631118 apiDynDeferralTemplates085SKC
{
    APIGroup = 'subscriptionBilling';
    APIPublisher = 'skconsulting';
    APIVersion = 'v1.0';
    Caption = 'Dynamic Deferral Templates';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityName = 'dynamicDeferralTemplate';
    EntitySetName = 'dynamicDeferralTemplates';
    InsertAllowed = true;
    ModifyAllowed = true;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "Deferral Template";

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
                field(deferralCode; Rec."Deferral Code") { Caption = 'deferralCode'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(deferralAccount; Rec."Deferral Account") { Caption = 'deferralAccount'; }
                field(deferralPercent; Rec."Deferral %") { Caption = 'deferralPercent'; }
                field(calcMethod; Rec."Calc. Method") { Caption = 'calcMethod'; }
                field(startDate; Rec."Start Date") { Caption = 'startDate'; }
                field(numberOfPeriods; Rec."No. of Periods") { Caption = 'numberOfPeriods'; }
                field(periodDescription; Rec."Period Description") { Caption = 'periodDescription'; }
                field(dynamicSubscriptionSchedule; Rec.DynamicSubSchedule085SKC) { Caption = 'dynamicSubscriptionSchedule'; }
            }
        }
    }
}
