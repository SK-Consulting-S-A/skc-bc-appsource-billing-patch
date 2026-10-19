namespace SKC.Subscription;

using Microsoft.Finance.Deferral;

/// <summary>
/// Read-only view of the individual periods in an unposted deferral schedule.
/// This is the level at which a test asserts that the posting dates exactly
/// cover the billing period and that the amounts add up to the line.
///
///   GET /.../dynamicDeferralLines?$filter=documentNo eq 'SI-001' and lineNo eq 10000
/// </summary>
page 70631120 apiDynDeferralLines085SKC
{
    APIGroup = 'subscriptionBilling';
    APIPublisher = 'skconsulting';
    APIVersion = 'v1.0';
    Caption = 'Dynamic Deferral Lines';
    DeleteAllowed = false;
    Editable = false;
    EntityName = 'dynamicDeferralLine';
    EntitySetName = 'dynamicDeferralLines';
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "Deferral Line";

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
                field(postingDate; Rec."Posting Date") { Caption = 'postingDate'; }
                field(description; Rec.Description) { Caption = 'description'; }
                field(amount; Rec.Amount) { Caption = 'amount'; }
                field(amountLcy; Rec."Amount (LCY)") { Caption = 'amountLcy'; }
                field(currencyCode; Rec."Currency Code") { Caption = 'currencyCode'; }
            }
        }
    }
}
