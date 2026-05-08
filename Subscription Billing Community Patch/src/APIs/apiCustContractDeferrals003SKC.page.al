namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Read-only API for Customer Subscription Contract Deferrals (table 8066).
/// GET .../customerSubscriptionContractDeferrals
/// </summary>
page 70631084 apiCustContractDeferrals003SKC
{
    PageType = API;
    APIPublisher = 'skconsulting';
    APIGroup = 'subscriptionBilling';
    APIVersion = 'v1.0';
    EntityName = 'customerSubscriptionContractDeferral';
    EntitySetName = 'customerSubscriptionContractDeferrals';
    SourceTable = "Cust. Sub. Contract Deferral";
    ODataKeyFields = SystemId;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Editable = false;
    Caption = 'Cust. Sub. Contract Deferrals';

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId) { Caption = 'id'; }
                field(entryNo; Rec."Entry No.") { Caption = 'entryNo'; }
                field(subscriptionContractNo; Rec."Subscription Contract No.") { Caption = 'subscriptionContractNo'; }
                field(subscriptionContractLineNo; Rec."Subscription Contract Line No.") { Caption = 'subscriptionContractLineNo'; }
                field(documentType; Rec."Document Type") { Caption = 'documentType'; }
                field(documentNo; Rec."Document No.") { Caption = 'documentNo'; }
                field(documentLineNo; Rec."Document Line No.") { Caption = 'documentLineNo'; }
                field(documentPostingDate; Rec."Document Posting Date") { Caption = 'documentPostingDate'; }
                field(postingDate; Rec."Posting Date") { Caption = 'postingDate'; }
                field(amount; Rec.Amount) { Caption = 'amount'; }
                field(deferralBaseAmount; Rec."Deferral Base Amount") { Caption = 'deferralBaseAmount'; }
                field(discountAmount; Rec."Discount Amount") { Caption = 'discountAmount'; }
                field(discountPercent; Rec."Discount %") { Caption = 'discountPercent'; }
                field(released; Rec.Released) { Caption = 'released'; }
                field(releasePostingDate; Rec."Release Posting Date") { Caption = 'releasePostingDate'; }
                field(glEntryNo; Rec."G/L Entry No.") { Caption = 'glEntryNo'; }
                field(numberOfDays; Rec."Number of Days") { Caption = 'numberOfDays'; }
                field(customerNo; Rec."Customer No.") { Caption = 'customerNo'; }
                field(billToCustomerNo; Rec."Bill-to Customer No.") { Caption = 'billToCustomerNo'; }
                field(currencyCode; Rec."Currency Code") { Caption = 'currencyCode'; }
                field(subscriptionDescription; Rec."Subscription Description") { Caption = 'subscriptionDescription'; }
                field(subscriptionLineDescription; Rec."Subscription Line Description") { Caption = 'subscriptionLineDescription'; }
                field(discount; Rec.Discount) { Caption = 'discount'; }
            }
        }
    }
}
