namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

table 70631050 SubQuantityHistory085SKC
{
    Caption = 'Subscription Quantity History';
    DataClassification = CustomerContent;
    LookupPageId = 70631070;
    DrillDownPageId = 70631070;

    fields
    {
        field(1; EntryNo085SKC; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(10; SubscriptionHeaderNo085SKC; Code[20])
        {
            Caption = 'Subscription Header No.';
            DataClassification = CustomerContent;
            TableRelation = "Subscription Header"."No.";
        }
        field(11; SubscriptionLineEntryNo085SKC; Integer)
        {
            Caption = 'Subscription Line Entry No.';
            DataClassification = CustomerContent;
            TableRelation = "Subscription Line"."Entry No.";
        }
        field(20; ChangeDate085SKC; Date)
        {
            Caption = 'Change Date';
            DataClassification = CustomerContent;
        }
        field(30; OldQuantity085SKC; Decimal)
        {
            Caption = 'Old Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(31; NewQuantity085SKC; Decimal)
        {
            Caption = 'New Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(32; DeltaQuantity085SKC; Decimal)
        {
            Caption = 'Delta Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(40; InterimBilled085SKC; Boolean)
        {
            Caption = 'Interim Billed';
            DataClassification = CustomerContent;
        }
        field(41; InterimBillingDate085SKC; Date)
        {
            Caption = 'Interim Billing Date';
            DataClassification = CustomerContent;
        }
        field(42; InterimDocNo085SKC; Code[20])
        {
            Caption = 'Interim Document No.';
            DataClassification = CustomerContent;
        }
        field(43; BillingLineEntryNo085SKC; Integer)
        {
            Caption = 'Billing Line Entry No.';
            DataClassification = CustomerContent;
        }
        field(50; Reason085SKC; Text[100])
        {
            Caption = 'Reason';
            DataClassification = CustomerContent;
        }
        field(60; UserID085SKC; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
    }

    keys
    {
        key(PK; EntryNo085SKC)
        {
            Clustered = true;
        }
        key(SubHeader; SubscriptionHeaderNo085SKC, InterimBilled085SKC)
        {
        }
    }
}
