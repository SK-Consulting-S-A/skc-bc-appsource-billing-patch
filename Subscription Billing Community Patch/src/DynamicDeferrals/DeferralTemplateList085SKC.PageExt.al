namespace SKC.Subscription;

using Microsoft.Finance.Deferral;

/// <summary>
/// Shows at a glance which deferral templates are driven by the subscription
/// billing period, since their period count column is meaningless.
/// </summary>
pageextension 70631116 DeferralTemplateList085SKC extends "Deferral Template List"
{
    layout
    {
        addafter("Deferral Account")
        {
            field(DynamicSubSchedule085SKC; Rec.DynamicSubSchedule085SKC)
            {
                ApplicationArea = All;
            }
        }
    }
}
