namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

tableextension 70631052 SubscriptionLine085SKC extends "Subscription Line"
{
    fields
    {
        field(70631053; AutoRenewal085SKC; Boolean)
        {
            Caption = 'Auto-Renewal';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                TermUntilToRestore: Date;
            begin
                if AutoRenewal085SKC then begin
                    TermUntilToRestore := TermUntilBackup085SKC;
                    if TermUntilToRestore = 0D then
                        if "Subscription Line End Date" <> 0D then
                            TermUntilToRestore := "Subscription Line End Date";

                    if Format(ExtensionTermBackup085SKC) <> '' then
                        Validate("Extension Term", ExtensionTermBackup085SKC);
                    if Format(NoticePeriodBackup085SKC) <> '' then
                        Validate("Notice Period", NoticePeriodBackup085SKC);

                    if "Subscription Line End Date" <> 0D then
                        Validate("Subscription Line End Date", 0D);

                    if TermUntilToRestore <> 0D then
                        Validate("Term Until", TermUntilToRestore);

                    TermUntilBackup085SKC := 0D;
                end else begin
                    if Format("Extension Term") <> '' then
                        ExtensionTermBackup085SKC := "Extension Term";
                    if Format("Notice Period") <> '' then
                        NoticePeriodBackup085SKC := "Notice Period";
                    if "Term Until" <> 0D then
                        TermUntilBackup085SKC := "Term Until"
                    else
                        if "Subscription Line End Date" <> 0D then
                            TermUntilBackup085SKC := "Subscription Line End Date";
                    Clear("Extension Term");
                    Clear("Notice Period");
                    if ("Subscription Line End Date" = 0D) and ("Term Until" <> 0D) then
                        Validate("Subscription Line End Date", "Term Until");
                end;
            end;
        }
        field(70631054; ExtensionTermBackup085SKC; DateFormula)
        {
            Caption = 'Subsequent Term Backup';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if AutoRenewal085SKC then
                    Validate("Extension Term", ExtensionTermBackup085SKC);
            end;
        }
        field(70631055; NoticePeriodBackup085SKC; DateFormula)
        {
            Caption = 'Notice Period Backup';
            DataClassification = CustomerContent;
        }
        field(70631056; TermUntilBackup085SKC; Date)
        {
            Caption = 'Term Until Backup';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(70631057; BillingLineCount085SKC; Integer)
        {
            Caption = 'Billing Lines';
            FieldClass = FlowField;
            CalcFormula = count("Billing Line" where("Subscription Line Entry No." = field("Entry No.")));
            Editable = false;
        }
        field(70631058; ArchiveLineCount085SKC; Integer)
        {
            Caption = 'Archive Lines';
            FieldClass = FlowField;
            CalcFormula = count("Billing Line Archive" where("Subscription Line Entry No." = field("Entry No.")));
            Editable = false;
        }
    }
}
