namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631077 apiVendSubContracts003SKC
{
    PageType = API;
    APIPublisher = 'skconsulting';
    APIGroup = 'subscriptionBilling';
    APIVersion = 'v1.0';
    EntityName = 'vendorSubscriptionContract';
    EntitySetName = 'vendorSubscriptionContracts';
    SourceTable = "Vendor Subscription Contract";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = true;
    Caption = 'Vendor Subscription Contracts';

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId)
                {
                    Editable = false;
                }
                field(contractNo; Rec."No.")
                {
                    Editable = false;
                }
                field(buyFromVendorNo; Rec."Buy-from Vendor No.") { }
                field(buyFromVendorName; Rec."Buy-from Vendor Name")
                {
                    Editable = false;
                }
                field(contractType; Rec."Contract Type") { }
                field(description; Rec."Description Preview") { }
                field(yourReference; Rec."Your Reference") { }
                field(currencyCode; Rec."Currency Code") { }
                field(paymentTermsCode; Rec."Payment Terms Code") { }
                field(paymentMethodCode; Rec."Payment Method Code") { }
                field(active; Rec.Active)
                {
                    Editable = false;
                }
                field(assignedUserID; Rec."Assigned User ID") { }
            }
        }
    }
}
