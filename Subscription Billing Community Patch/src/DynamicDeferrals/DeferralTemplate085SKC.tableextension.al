namespace SKC.Subscription;

using Microsoft.Finance.Deferral;

/// <summary>
/// Marks a standard deferral template as driven by the subscription billing
/// period rather than by a fixed period count.
///
/// When the flag is set, Calc. Method, Start Date, and No. of Periods stop
/// being meaningful: the schedule is rebuilt from Recurring Billing from/to on
/// the document line every time the amount or the period changes. The fields
/// are forced to a neutral state here so that a half-configured template cannot
/// quietly produce a twelve-period schedule for a three-month invoice.
/// </summary>
tableextension 70631101 DeferralTemplate085SKC extends "Deferral Template"
{
    fields
    {
        field(70631120; DynamicSubSchedule085SKC; Boolean)
        {
            Caption = 'Dynamic Subscription Schedule';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies that the deferral schedule is calculated from the subscription billing period on the document line instead of from the calculation method and number of periods on this template.';

            trigger OnValidate()
            begin
                if not DynamicSubSchedule085SKC then
                    exit;

                "Calc. Method" := "Calc. Method"::"User-Defined";
                "Start Date" := "Start Date"::"Posting Date";
                if "No. of Periods" < 1 then
                    "No. of Periods" := 1;
            end;
        }
    }
}
