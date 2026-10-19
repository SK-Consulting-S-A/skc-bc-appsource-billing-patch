namespace SKC.Subscription;

using Microsoft.Finance.Deferral;

/// <summary>
/// Read-only view of the unposted deferral schedule headers, so an automated
/// test can confirm that a draft document carries the schedule it should before
/// anything is posted.
///
///   GET /.../dynamicDeferralHeaders?$filter=documentNo eq 'SI-001'
/// </summary>
page 70631119 apiDynDeferralHeaders085SKC
{
    APIGroup = 'subscriptionBilling';
    APIPublisher = 'skconsulting';
    APIVersion = 'v1.0';
    Caption = 'Dynamic Deferral Headers';
    DeleteAllowed = false;
    Editable = false;
    EntityName = 'dynamicDeferralHeader';
    EntitySetName = 'dynamicDeferralHeaders';
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "Deferral Header";

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId) { Caption = 'id'; }
                field(deferralDocType; Rec."Deferral Doc. Type") { Caption = 'deferralDocType'; }
                field(documentType; Rec."Document Type") { Caption = 'documentType'; }
                field(documentNo; Rec."Document No.") { Caption = 'documentNo'; }
                field(lineNo; Rec."Line No.") { Caption = 'lineNo'; }
                field(deferralCode; Rec."Deferral Code") { Caption = 'deferralCode'; }
                field(amountToDefer; Rec."Amount to Defer") { Caption = 'amountToDefer'; }
                field(amountToDeferLcy; Rec."Amount to Defer (LCY)") { Caption = 'amountToDeferLcy'; }
                field(calcMethod; Rec."Calc. Method") { Caption = 'calcMethod'; }
                field(startDate; Rec."Start Date") { Caption = 'startDate'; }
                field(numberOfPeriods; Rec."No. of Periods") { Caption = 'numberOfPeriods'; }
                field(scheduleLineTotal; Rec."Schedule Line Total") { Caption = 'scheduleLineTotal'; }
                field(scheduleDescription; Rec."Schedule Description") { Caption = 'scheduleDescription'; }
                field(currencyCode; Rec."Currency Code") { Caption = 'currencyCode'; }
            }
        }
    }
}
