namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631081 apiCustBillLineArch085SKC
{
    PageType = API;
    APIPublisher = 'skconsulting';
    APIGroup = 'subscriptionBilling';
    APIVersion = 'v1.0';
    EntityName = 'customerBillingLineArchive';
    EntitySetName = 'customerBillingLineArchives';
    SourceTable = "Billing Line Archive";
    SourceTableView = where(Partner = const(Customer));
    ODataKeyFields = SystemId;
    InsertAllowed = false;
    ModifyAllowed = true;
    DeleteAllowed = false;
    Caption = 'Customer Billing Line Archives';

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId) { }
                field(entryNo; Rec."Entry No.") { }
                field(subscriptionContractNo; Rec."Subscription Contract No.")
                {
                    Editable = true;
                }
                field(subscriptionContractLineNo; Rec."Subscription Contract Line No.")
                {
                    Editable = true;
                }
                field(subscriptionHeaderNo; Rec."Subscription Header No.") { }
                field(subscriptionLineEntryNo; Rec."Subscription Line Entry No.") { }
                field(subscriptionDescription; Rec."Subscription Description") { }
                field(billingFrom; Rec."Billing from") { }
                field(billingTo; Rec."Billing to") { }
                field(unitPrice; Rec."Unit Price")
                {
                    Editable = true;
                }
                field(unitCostLCY; Rec."Unit Cost (LCY)")
                {
                    Editable = true;
                }
                field(discountPercent; Rec."Discount %") { }
                field(amount; Rec.Amount)
                {
                    Editable = true;
                }
                field(documentType; Rec."Document Type") { }
                field(documentNo; Rec."Document No.") { }
                field(documentLineNo; Rec."Document Line No.") { }
                field(partner; Rec.Partner) { }
                field(partnerNo; Rec."Partner No.") { }
                field(currencyCode; Rec."Currency Code") { }
                field(billingRhythm; Rec."Billing Rhythm") { }
                field(subscriptionLineDescription; Rec."Subscription Line Description") { }
            }
        }
    }
}
