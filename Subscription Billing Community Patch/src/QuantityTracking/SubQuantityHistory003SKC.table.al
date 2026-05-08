namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

table 70631050 SubQuantityHistory003SKC
{
    Caption = 'Subscription Quantity History';
    DataClassification = CustomerContent;
    LookupPageId = 70631070;
    DrillDownPageId = 70631070;

    fields
    {
        field(1; EntryNo003SKC; Integer)
        {
            Caption = 'Entry No.';
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(10; SubscriptionHeaderNo003SKC; Code[20])
        {
            Caption = 'Subscription Header No.';
            DataClassification = CustomerContent;
            TableRelation = "Subscription Header"."No.";
        }
        field(11; SubscriptionLineEntryNo003SKC; Integer)
        {
            Caption = 'Subscription Line Entry No.';
            DataClassification = CustomerContent;
            TableRelation = "Subscription Line"."Entry No.";
        }
        field(20; ChangeDate003SKC; Date)
        {
            Caption = 'Change Date';
            DataClassification = CustomerContent;
        }
        field(30; OldQuantity003SKC; Decimal)
        {
            Caption = 'Old Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(31; NewQuantity003SKC; Decimal)
        {
            Caption = 'New Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(32; DeltaQuantity003SKC; Decimal)
        {
            Caption = 'Delta Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(40; InterimBilled003SKC; Boolean)
        {
            Caption = 'Interim Billed';
            DataClassification = CustomerContent;
        }
        field(41; InterimBillingDate003SKC; Date)
        {
            Caption = 'Interim Billing Date';
            DataClassification = CustomerContent;
        }
        field(42; InterimDocNo003SKC; Code[20])
        {
            Caption = 'Interim Document No.';
            DataClassification = CustomerContent;
        }
        field(43; BillingLineEntryNo003SKC; Integer)
        {
            Caption = 'Billing Line Entry No.';
            DataClassification = CustomerContent;
        }
        field(50; Reason003SKC; Text[100])
        {
            Caption = 'Reason';
            DataClassification = CustomerContent;
        }
        field(60; UserID003SKC; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
    }

    keys
    {
        key(PK; EntryNo003SKC)
        {
            Clustered = true;
        }
        key(SubHeader; SubscriptionHeaderNo003SKC, InterimBilled003SKC)
        {
        }
    }
}
