namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631073 SubExpiringActivities085SKC
{
    PageType = CardPart;
    SourceTable = SubExpiringCue085SKC;
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
                field(ArchiveCompleted; Rec."Archive-Completed Lines")
                {
                    ApplicationArea = All;
                    Caption = 'Archive-Completed Lines';
                    ToolTip = 'Open subscription lines whose Next Billing Date was reset backwards by credit memos even though the billing archive proves the period was fully invoiced. Click to fix the Next Billing Date from the archive and close the lines that qualify.';

                    trigger OnDrillDown()
                    begin
                        RunArchiveCloseFix();
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
        SubLine.SetRange(AutoRenewal085SKC, false);

        SubLine.SetFilter("Subscription Line End Date", '%1..%2', Today, CalcDate('<+30D>', Today));
        Rec."Expiring within 30 Days" := SubLine.Count();

        SubLine.SetFilter("Subscription Line End Date", '%1..%2', Today, CalcDate('<+90D>', Today));
        Rec."Expiring within 90 Days" := SubLine.Count();

        SubLine.SetFilter("Subscription Line End Date", '%1..%2', 19000101D, CalcDate('<-1D>', Today));
        Rec."End Date Passed" := SubLine.Count();

        Rec."Archive-Completed Lines" := ArchiveCloseCheck.CountFixableLines();

        Rec.Modify();
    end;

    local procedure RunArchiveCloseFix()
    var
        FixedCount: Integer;
    begin
        if Rec."Archive-Completed Lines" = 0 then begin
            Message(NoArchiveFixableMsg);
            exit;
        end;
        if not Confirm(ConfirmArchiveFixMsg, false, Rec."Archive-Completed Lines") then
            exit;
        FixedCount := ArchiveCloseCheck.FixArchiveCompletedLines();
        CurrPage.Update(false);
        Message(ArchiveFixDoneMsg, FixedCount);
    end;

    local procedure DrillDownExpiring(Days: Integer)
    var
        SubLine: Record "Subscription Line";
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetRange(AutoRenewal085SKC, false);
        SubLine.SetFilter("Subscription Line End Date", '%1..%2', Today, CalcDate(StrSubstNo('<+%1D>', Days), Today));
        Page.Run(Page::SubExpiringSubLines085SKC, SubLine);
    end;

    local procedure DrillDownEndDatePassed()
    var
        SubLine: Record "Subscription Line";
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetRange(AutoRenewal085SKC, false);
        SubLine.SetFilter("Subscription Line End Date", '%1..%2', 19000101D, CalcDate('<-1D>', Today));
        Page.Run(Page::SubExpiringSubLines085SKC, SubLine);
    end;

    var
        ArchiveCloseCheck: Codeunit SubArchiveCloseCheck085SKC;
        NoArchiveFixableMsg: Label 'No subscription lines need an archive-based Next Billing Date correction.';
        ConfirmArchiveFixMsg: Label 'This will correct the Next Billing Date on %1 subscription line(s) from the billing archive and close the lines that qualify.\\Do you want to continue?', Comment = '%1 = Line count';
        ArchiveFixDoneMsg: Label 'Archive-based Next Billing Date fix completed. %1 line(s) corrected.', Comment = '%1 = Fixed count';
}
