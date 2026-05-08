namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631083 apiSubLineArchive003SKC
{
    PageType = API;
    APIPublisher = 'skconsulting';
    APIGroup = 'subscriptionBilling';
    APIVersion = 'v1.0';
    EntityName = 'subscriptionLineArchive';
    EntitySetName = 'subscriptionLineArchives';
    SourceTable = "Subscription Line Archive";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = false;
    DeleteAllowed = true;
    Caption = 'Subscription Line Archives';

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
                field(entryNo; Rec."Entry No.")
                {
                    Editable = false;
                }
                field(subscriptionHeaderNo; Rec."Subscription Header No.") { }
                field(subscriptionPackageCode; Rec."Subscription Package Code") { }
                field(description; Rec.Description) { }
                field(subscriptionLineStartDate; Rec."Subscription Line Start Date") { }
                field(subscriptionLineEndDate; Rec."Subscription Line End Date") { }
                field(calculationBaseAmount; Rec."Calculation Base Amount") { }
                field(calculationBasePercent; Rec."Calculation Base %") { }
                field(price; Rec.Price) { }
                field(discountPercent; Rec."Discount %") { }
                field(discountAmount; Rec."Discount Amount") { }
                field(amount; Rec.Amount) { }
                field(amountLCY; Rec."Amount (LCY)") { }
                field(billingBasePeriod; Rec."Billing Base Period") { }
                field(billingRhythm; Rec."Billing Rhythm") { }
                field(subscriptionContractNo; Rec."Subscription Contract No.") { }
                field(subscriptionContractLineNo; Rec."Subscription Contract Line No.") { }
                field(partner; Rec.Partner) { }
                field(quantitySubHeader; Rec."Quantity (Sub. Header)") { }
                field(currencyCode; Rec."Currency Code") { }
                field(initialTerm; Rec."Initial Term") { }
                field(extensionTerm; Rec."Extension Term") { }
                field(noticePeriod; Rec."Notice Period") { }
                field(nextBillingDate; Rec."Next Billing Date") { }
                field(typeOfUpdate; Rec."Type of Update") { }
            }
        }
    }
}
