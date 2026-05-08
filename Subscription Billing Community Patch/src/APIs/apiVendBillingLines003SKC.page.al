namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631078 apiVendBillingLines003SKC
{
    PageType = API;
    APIPublisher = 'skconsulting';
    APIGroup = 'subscriptionBilling';
    APIVersion = 'v1.0';
    EntityName = 'vendorBillingLine';
    EntitySetName = 'vendorBillingLines';
    SourceTable = "Billing Line";
    SourceTableView = where(Partner = const(Vendor));
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Editable = false;
    Caption = 'Vendor Billing Lines';

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId) { }
                field(subscriptionContractNo; Rec."Subscription Contract No.") { }
                field(subscriptionHeaderNo; Rec."Subscription Header No.") { }
                field(subscriptionLineEntryNo; Rec."Subscription Line Entry No.") { }
                field(subscriptionDescription; Rec."Subscription Description") { }
                field(billingFrom; Rec."Billing from") { }
                field(billingTo; Rec."Billing to") { }
                field(unitPrice; Rec."Unit Price") { }
                field(amount; Rec.Amount) { }
                field(documentType; Rec."Document Type") { }
                field(documentNo; Rec."Document No.") { }
                field(documentLineNo; Rec."Document Line No.") { }
                field(updateRequired; Rec."Update Required") { }
                field(partner; Rec.Partner) { }
                field(currencyCode; Rec."Currency Code") { }
            }
        }
    }
}
