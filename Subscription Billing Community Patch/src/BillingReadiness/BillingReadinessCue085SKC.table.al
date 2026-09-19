namespace SKC.Subscription;

table 70631123 BillingReadinessCue085SKC
{
    Caption = 'Billing Readiness Cue';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Zero-Price Lines"; Integer)
        {
            Caption = 'Zero-Price Lines';
            Editable = false;
        }
        field(11; "Contracts w/ Zero-Price"; Integer)
        {
            Caption = 'Contracts w/ Zero-Price Lines';
            Editable = false;
        }
        field(12; "Stale Billing Lines"; Integer)
        {
            Caption = 'Stale Billing Lines';
            Editable = false;
        }
        field(13; "No Contract Assigned"; Integer)
        {
            Caption = 'No Contract Assigned';
            Editable = false;
        }
        field(14; "No Next Billing Date"; Integer)
        {
            Caption = 'No Next Billing Date';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
