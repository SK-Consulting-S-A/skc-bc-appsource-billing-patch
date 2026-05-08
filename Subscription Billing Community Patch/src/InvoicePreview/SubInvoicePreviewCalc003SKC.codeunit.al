namespace SKC.Subscription;

codeunit 70631063 SubInvoicePreviewCalc003SKC
{
    Access = Internal;

    procedure CalcNextInvoiceAmount(BillingBasePeriod: DateFormula; BillingRhythm: DateFormula; Amount: Decimal): Decimal
    var
        RefDate: Date;
        BaseEnd: Date;
        RhythmEnd: Date;
        BaseMonths: Integer;
        RhythmMonths: Integer;
        BaseDays: Integer;
        RhythmDays: Integer;
    begin
        if (Format(BillingBasePeriod) = '') or (Format(BillingRhythm) = '') then
            exit(0);
        if Amount = 0 then
            exit(0);

        RefDate := WorkDate();
        BaseEnd := CalcDate(BillingBasePeriod, RefDate);
        RhythmEnd := CalcDate(BillingRhythm, RefDate);

        BaseMonths := DateDiffMonths(RefDate, BaseEnd);
        RhythmMonths := DateDiffMonths(RefDate, RhythmEnd);

        if (BaseMonths > 0) and (RhythmMonths > 0) then
            exit(Round(Amount * RhythmMonths / BaseMonths, 0.01));

        BaseDays := BaseEnd - RefDate;
        RhythmDays := RhythmEnd - RefDate;

        if BaseDays = 0 then
            exit(0);

        exit(Round(Amount * RhythmDays / BaseDays, 0.01));
    end;

    local procedure DateDiffMonths(StartDate: Date; EndDate: Date): Integer
    begin
        exit((Date2DMY(EndDate, 3) - Date2DMY(StartDate, 3)) * 12 + (Date2DMY(EndDate, 2) - Date2DMY(StartDate, 2)));
    end;
}
