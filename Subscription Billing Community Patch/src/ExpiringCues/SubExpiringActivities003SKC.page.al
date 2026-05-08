namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631073 SubExpiringActivities003SKC
{
    PageType = CardPart;
    SourceTable = SubExpiringCue003SKC;
    Caption = 'Subscriptions Expiring';

    layout
    {
        area(Content)
        {
            cuegroup(ExpiringSubscriptions)
            {
                Caption = 'Subscriptions Expiring';

                field(Expiring30; Rec."Expiring within 30 Days")
                {
                    ApplicationArea = All;
                    Caption = 'Expiring in 30 Days';
                    ToolTip = 'Number of active customer subscription lines (without auto-renewal) with an end date within the next 30 days.';

                    trigger OnDrillDown()
                    begin
                        DrillDownExpiring(30);
                    end;
                }
                field(Expiring90; Rec."Expiring within 90 Days")
                {
                    ApplicationArea = All;
                    Caption = 'Expiring in 90 Days';
                    ToolTip = 'Number of active customer subscription lines (without auto-renewal) with an end date within the next 90 days.';

                    trigger OnDrillDown()
                    begin
                        DrillDownExpiring(90);
                    end;
                }
                field(EndDatePassed; Rec."End Date Passed")
                {
                    ApplicationArea = All;
                    Caption = 'End Date Passed';
                    ToolTip = 'Number of subscription lines (without auto-renewal) where the end date has passed but the line has not yet been closed by the batch job.';

                    trigger OnDrillDown()
                    begin
                        DrillDownEndDatePassed();
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;

    trigger OnAfterGetRecord()
    begin
        ComputeExpiringCues();
    end;

    local procedure ComputeExpiringCues()
    var
        SubLine: Record "Subscription Line";
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetRange(AutoRenewal003SKC, false);

        SubLine.SetFilter("Subscription Line End Date", '%1..%2', Today, CalcDate('<+30D>', Today));
        Rec."Expiring within 30 Days" := SubLine.Count();

        SubLine.SetFilter("Subscription Line End Date", '%1..%2', Today, CalcDate('<+90D>', Today));
        Rec."Expiring within 90 Days" := SubLine.Count();

        SubLine.SetFilter("Subscription Line End Date", '%1..%2', 19000101D, CalcDate('<-1D>', Today));
        Rec."End Date Passed" := SubLine.Count();

        Rec.Modify();
    end;

    local procedure DrillDownExpiring(Days: Integer)
    var
        SubLine: Record "Subscription Line";
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetRange(AutoRenewal003SKC, false);
        SubLine.SetFilter("Subscription Line End Date", '%1..%2', Today, CalcDate(StrSubstNo('<+%1D>', Days), Today));
        Page.Run(Page::SubExpiringSubLines003SKC, SubLine);
    end;

    local procedure DrillDownEndDatePassed()
    var
        SubLine: Record "Subscription Line";
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetRange(AutoRenewal003SKC, false);
        SubLine.SetFilter("Subscription Line End Date", '%1..%2', 19000101D, CalcDate('<-1D>', Today));
        Page.Run(Page::SubExpiringSubLines003SKC, SubLine);
    end;
}
