namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.SubscriptionBilling;

tableextension 70631097 SubContractSetup085SKC extends "Subscription Contract Setup"
{
    fields
    {
        field(70631122; DefaultDeferralMethod085SKC; Enum SubDeferralMethod085SKC)
        {
            Caption = 'Default Deferral Method';
            DataClassification = CustomerContent;
            InitValue = "Subscription Deferral";
            ToolTip = 'Specifies which deferral engine subscription billing lines use when the subscription line itself is set to Setup Default. Subscription Deferral keeps the contract deferrals and the release report. Standard Dynamic posts the full future-dated schedule together with the invoice.';

            trigger OnValidate()
            begin
                if DefaultDeferralMethod085SKC = DefaultDeferralMethod085SKC::"Setup Default" then
                    Error(SetupDefaultNotAllowedErr);
            end;
        }
        field(70631123; CustDynDeferralTemplate085SKC; Code[10])
        {
            Caption = 'Customer Dynamic Deferral Template';
            DataClassification = CustomerContent;
            TableRelation = "Deferral Template"."Deferral Code";
            ToolTip = 'Specifies the fallback deferral template used for customer subscription lines when the invoicing item has no default deferral template. The template must be marked as a dynamic subscription schedule.';

            trigger OnValidate()
            begin
                CheckDynamicTemplate085SKC(CustDynDeferralTemplate085SKC);
            end;
        }
        field(70631124; VendDynDeferralTemplate085SKC; Code[10])
        {
            Caption = 'Vendor Dynamic Deferral Template';
            DataClassification = CustomerContent;
            TableRelation = "Deferral Template"."Deferral Code";
            ToolTip = 'Specifies the fallback deferral template used for vendor subscription lines when the invoicing item has no default deferral template. The template must be marked as a dynamic subscription schedule.';

            trigger OnValidate()
            begin
                CheckDynamicTemplate085SKC(VendDynDeferralTemplate085SKC);
            end;
        }
        field(70631050; EnableInterimBilling085SKC; Boolean)
        {
            Caption = 'Enable Interim Billing';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether mid-cycle quantity changes are captured and made available for interim (pro-rata) billing. When disabled, quantity-change tracking and the interim billing actions are turned off.';
        }
        field(70631051; LockCalcBasePct100085SKC; Boolean)
        {
            Caption = 'Lock Calculation Base % at 100';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether the Calculation Base % on subscription lines is forced to 100 and hidden in the UI. Enable this when you always bill the full calculation base.';
        }
    }

    /// <summary>
    /// A template that is not flagged as a dynamic subscription schedule would
    /// fall back to its own fixed period count, which is exactly the behaviour
    /// the dynamic engine exists to avoid.
    /// </summary>
    local procedure CheckDynamicTemplate085SKC(DeferralCode: Code[10])
    var
        DeferralTemplate: Record "Deferral Template";
    begin
        if DeferralCode = '' then
            exit;
        DeferralTemplate.Get(DeferralCode);
        if not DeferralTemplate.DynamicSubSchedule085SKC then
            Error(TemplateNotDynamicErr, DeferralCode);
    end;

    var
        SetupDefaultNotAllowedErr: Label 'The company default cannot be Setup Default. Choose Subscription Deferral, Standard Dynamic, or No Deferral.';
        TemplateNotDynamicErr: Label 'Deferral template %1 is not marked as a dynamic subscription schedule.', Comment = '%1 = deferral template code';
}
