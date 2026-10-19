namespace SKC.Subscription;

using Microsoft.Finance.Deferral;

/// <summary>
/// Exposes the dynamic subscription schedule flag and locks the fields it
/// overrides.
///
/// Calculation method, start date, and number of periods are supplied at
/// runtime from the billing period on each document line, so leaving them
/// editable would suggest a control that does not exist.
/// </summary>
pageextension 70631115 DeferralTemplateCard085SKC extends "Deferral Template Card"
{
    layout
    {
        addafter("Deferral Account")
        {
            field(DynamicSubSchedule085SKC; Rec.DynamicSubSchedule085SKC)
            {
                ApplicationArea = All;

                trigger OnValidate()
                begin
                    CurrPage.Update(true);
                end;
            }
        }
        modify("Calc. Method")
        {
            Editable = not Rec.DynamicSubSchedule085SKC;
        }
        modify("Start Date")
        {
            Editable = not Rec.DynamicSubSchedule085SKC;
        }
        modify("No. of Periods")
        {
            Editable = not Rec.DynamicSubSchedule085SKC;
        }
    }
}
