namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

tableextension 70631052 SubscriptionLine003SKC extends "Subscription Line"
{
    fields
    {
        field(70631053; AutoRenewal003SKC; Boolean)
        {
            Caption = 'Auto-Renewal';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if AutoRenewal003SKC then begin
                    if Format(ExtensionTermBackup003SKC) <> '' then
                        Validate("Extension Term", ExtensionTermBackup003SKC);
                    if Format(NoticePeriodBackup003SKC) <> '' then
                        Validate("Notice Period", NoticePeriodBackup003SKC);
                    if "Subscription Line End Date" <> 0D then
                        Validate("Subscription Line End Date", 0D);
                end else begin
                    if Format("Extension Term") <> '' then
                        ExtensionTermBackup003SKC := "Extension Term";
                    if Format("Notice Period") <> '' then
                        NoticePeriodBackup003SKC := "Notice Period";
                    Clear("Extension Term");
                    Clear("Notice Period");
                    if ("Subscription Line End Date" = 0D) and ("Term Until" <> 0D) then
                        Validate("Subscription Line End Date", "Term Until");
                end;
            end;
        }
        field(70631054; ExtensionTermBackup003SKC; DateFormula)
        {
            Caption = 'Subsequent Term Backup';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if AutoRenewal003SKC then
                    Validate("Extension Term", ExtensionTermBackup003SKC);
            end;
        }
        field(70631055; NoticePeriodBackup003SKC; DateFormula)
        {
            Caption = 'Notice Period Backup';
            DataClassification = CustomerContent;
        }
        field(70631056; TermUntilBackup003SKC; Date)
        {
            Caption = 'Term Until Backup';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
