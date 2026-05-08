namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631082 apiSubHeaders003SKC
{
    PageType = API;
    APIPublisher = 'skconsulting';
    APIGroup = 'subscriptionBilling';
    APIVersion = 'v1.0';
    EntityName = 'subscriptionHeader';
    EntitySetName = 'subscriptionHeaders';
    SourceTable = "Subscription Header";
    ODataKeyFields = SystemId;
    InsertAllowed = false;
    ModifyAllowed = true;
    DeleteAllowed = true;
    Caption = 'Subscription Headers';

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
                field(no; Rec."No.")
                {
                    Editable = false;
                }
                field(description; Rec.Description)
                {
                    Editable = false;
                }
                field(sourceNo; Rec."Source No.")
                {
                    Editable = false;
                }
                field(endUserCustomerNo; Rec."End-User Customer No.")
                {
                    Editable = false;
                }
                field(quantity; Rec.Quantity) { }
                field(unitOfMeasure; Rec."Unit of Measure") { }
                field(provisionStartDate; Rec."Provision Start Date") { }
                field(provisionEndDate; Rec."Provision End Date") { }
                field(customerReference; Rec."Customer Reference")
                {
                    Editable = false;
                }
            }
        }
    }
}
