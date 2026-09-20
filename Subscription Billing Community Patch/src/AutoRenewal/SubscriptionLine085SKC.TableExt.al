namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.SubscriptionBilling;

tableextension 70631052 SubscriptionLine085SKC extends "Subscription Line"
{
    fields
    {
        field(70631120; DeferralMethod085SKC; Enum SubDeferralMethod085SKC)
        {
            Caption = 'How to Defer';
            DataClassification = CustomerContent;
            InitValue = "Setup Default";
            ToolTip = 'Specifies how billing for this subscription line is deferred. Setup Default follows the company default in Subscription Contract Setup. Standard Dynamic posts the whole future-dated schedule with the invoice and switches Create Contract Deferrals off so the two engines cannot both run.';

            trigger OnValidate()
            begin
                SyncCreateContractDeferrals085SKC();
            end;
        }
        field(70631121; DynDeferralTemplate085SKC; Code[10])
        {
            Caption = 'Dynamic Deferral Template';
            DataClassification = CustomerContent;
            TableRelation = "Deferral Template"."Deferral Code" where(DynamicSubSchedule085SKC = const(true));
            ToolTip = 'Specifies an explicit deferral template for this line. Leave blank to use the invoicing item''s default deferral template, or the fallback template in Subscription Contract Setup.';
        }
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

    /// <summary>
    /// Keeps the native contract deferral switch consistent with the method
    /// chosen here. Standard Dynamic and contract deferrals are mutually
    /// exclusive: the platform blocks a standard Deferral Code on a line that
    /// still requests contract deferrals, so leaving both on would make the
    /// document unpostable.
    /// </summary>
    procedure SyncCreateContractDeferrals085SKC()
    var
        Target: Enum "Create Contract Deferrals";
    begin
        case Rec.DeferralMethod085SKC of
            Rec.DeferralMethod085SKC::"Standard Dynamic",
            Rec.DeferralMethod085SKC::"No Deferral":
                Target := Target::No;
            Rec.DeferralMethod085SKC::"Subscription Deferral":
                Target := Target::Yes;
            else
                exit;
        end;

        if Rec."Create Contract Deferrals" <> Target then
            Rec."Create Contract Deferrals" := Target;
    end;
}
