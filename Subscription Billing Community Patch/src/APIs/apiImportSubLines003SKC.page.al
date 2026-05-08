namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631080 apiImportSubLines003SKC
{
    PageType = API;
    APIPublisher = 'skconsulting';
    APIGroup = 'subscriptionBilling';
    APIVersion = 'v1.0';
    EntityName = 'importedSubscriptionLine';
    EntitySetName = 'importedSubscriptionLines';
    SourceTable = "Imported Subscription Line";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    InsertAllowed = true;
    ModifyAllowed = true;
    DeleteAllowed = true;
    Caption = 'Imported Subscription Lines';

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
                field(entryNo; Rec."Entry No.") { }
                field(subscriptionNo; Rec."Subscription Header No.") { }
                field(subscriptionLineEntryNo; Rec."Subscription Line Entry No.") { }
                field(partner; Rec.Partner) { }
                field(subscriptionContractNo; Rec."Subscription Contract No.") { }
                field(contractLineNo; Rec."Subscription Contract Line No.") { }
                field(contractLineType; Rec."Sub. Contract Line Type") { }
                field(subscriptionPackageCode; Rec."Subscription Package Code") { }
                field(templateCode; Rec."Template Code") { }
                field(description; Rec.Description) { }
                field(subscriptionLineStartDate; Rec."Subscription Line Start Date") { }
                field(subscriptionLineEndDate; Rec."Subscription Line End Date") { }
                field(nextBillingDate; Rec."Next Billing Date") { }
                field(calculationBaseAmount; Rec."Calculation Base Amount") { }
                field(calculationBasePercent; Rec."Calculation Base %") { }
                field(discountPercent; Rec."Discount %") { }
                field(discountAmount; Rec."Discount Amount") { }
                field(amount; Rec.Amount) { }
                field(billingBasePeriod; Rec."Billing Base Period") { }
                field(invoicingVia; Rec."Invoicing via") { }
                field(billingRhythm; Rec."Billing Rhythm") { }
                field(initialTerm; Rec."Initial Term") { }
                field(extensionTerm; Rec."Extension Term") { }
                field(noticePeriod; Rec."Notice Period") { }
                field(currencyCode; Rec."Currency Code") { }
                field(subscriptionLineCreated; Rec."Subscription Line created")
                {
                    Editable = false;
                }
                field(contractLineCreated; Rec."Sub. Contract Line created")
                {
                    Editable = false;
                }
                field(errorText; Rec."Error Text")
                {
                    Editable = false;
                }
                field(processedBy; Rec."Processed by")
                {
                    Editable = false;
                }
                field(processedAt; Rec."Processed at")
                {
                    Editable = false;
                }
            }
        }
    }
}
