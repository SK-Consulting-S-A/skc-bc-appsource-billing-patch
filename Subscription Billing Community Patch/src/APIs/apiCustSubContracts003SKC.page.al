namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631075 apiCustSubContracts003SKC
{
    PageType = API;
    APIPublisher = 'skconsulting';
    APIGroup = 'subscriptionBilling';
    APIVersion = 'v1.0';
    EntityName = 'customerSubscriptionContract';
    EntitySetName = 'customerSubscriptionContracts';
    SourceTable = "Customer Subscription Contract";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    InsertAllowed = false;
    ModifyAllowed = true;
    DeleteAllowed = true;
    Editable = true;
    Caption = 'Cust. Sub. Contracts';

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
                field(sellToCustomerNo; Rec."Sell-to Customer No.") { }
                field(sellToCustomerName; Rec."Sell-to Customer Name")
                {
                    Editable = false;
                }
                field(billToCustomerNo; Rec."Bill-to Customer No.") { }
                field(billToName; Rec."Bill-to Name")
                {
                    Editable = false;
                }
                field(yourReference; Rec."Your Reference")
                {
                    Editable = false;
                }
                field(contractType; Rec."Contract Type")
                {
                    Editable = false;
                }
                field(descriptionPreview; Rec."Description Preview")
                {
                    Editable = false;
                }
                field(currencyCode; Rec."Currency Code")
                {
                    Editable = false;
                }
                field(salespersonCode; Rec."Salesperson Code")
                {
                    Editable = false;
                }
                field(paymentTermsCode; Rec."Payment Terms Code")
                {
                    Editable = false;
                }
                field(paymentMethodCode; Rec."Payment Method Code")
                {
                    Editable = false;
                }
                field(createContractDeferrals; Rec."Create Contract Deferrals")
                {
                    Editable = false;
                }
                field(active; Rec.Active)
                {
                    Editable = false;
                }
                field(nextBillingFrom; Rec."Next Billing From")
                {
                    Editable = false;
                }
                field(nextBillingTo; Rec."Next Billing To")
                {
                    Editable = false;
                }
                field(billingBaseDate; Rec."Billing Base Date")
                {
                    Editable = false;
                }
            }
        }
    }
}
