namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631081 apiCustBillLineArch003SKC
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
    ModifyAllowed = false;
    DeleteAllowed = false;
    Editable = false;
    Caption = 'Customer Billing Line Archives';

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
                field(partner; Rec.Partner) { }
                field(currencyCode; Rec."Currency Code") { }
            }
        }
    }
}
