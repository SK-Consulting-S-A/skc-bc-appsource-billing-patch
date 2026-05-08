namespace SKC.Subscription;

table 70631051 SubExpiringCue003SKC
{
    Caption = 'Subscription Expiring Cue';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; "Expiring within 30 Days"; Integer)
        {
            Caption = 'Expiring within 30 Days';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(11; "Expiring within 90 Days"; Integer)
        {
            Caption = 'Expiring within 90 Days';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(12; "End Date Passed"; Integer)
        {
            Caption = 'End Date Passed';
            DataClassification = SystemMetadata;
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
