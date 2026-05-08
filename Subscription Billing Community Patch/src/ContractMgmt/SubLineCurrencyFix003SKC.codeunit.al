namespace SKC.Subscription;

using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.SubscriptionBilling;

codeunit 70631061 SubLineCurrencyFix003SKC
{
    Access = Internal;

    procedure RunFix(): Integer
    var
        SubLine: Record "Subscription Line";
        GLSetup: Record "General Ledger Setup";
        CurrExchRate: Record "Currency Exchange Rate";
        Currency: Record Currency;
        FixedCount: Integer;
    begin
        GLSetup.Get();

        SubLine.SetFilter("Currency Code", '<>%1', '');
        SubLine.SetRange("Currency Factor", 0);
        if SubLine.IsEmpty() then
            exit(0);

        SubLine.FindSet(true);
        repeat
            if UpperCase(SubLine."Currency Code") = UpperCase(GLSetup."LCY Code") then
                ClearCurrencyToLCY(SubLine)
            else
                RepairForeignCurrencyFactor(SubLine, CurrExchRate, Currency);

            SubLine.Modify(false);
            FixedCount += 1;
        until SubLine.Next() = 0;

        exit(FixedCount);
    end;

    procedure CountAffected(): Integer
    var
        SubLine: Record "Subscription Line";
    begin
        SubLine.SetFilter("Currency Code", '<>%1', '');
        SubLine.SetRange("Currency Factor", 0);
        exit(SubLine.Count());
    end;

    local procedure ClearCurrencyToLCY(var SubLine: Record "Subscription Line")
    begin
        SubLine."Currency Code" := '';
        SubLine."Currency Factor" := 0;
        SubLine."Currency Factor Date" := 0D;
        SubLine."Price (LCY)" := SubLine.Price;
        SubLine."Amount (LCY)" := SubLine.Amount;
        SubLine."Discount Amount (LCY)" := SubLine."Discount Amount";
        SubLine."Calculation Base Amount (LCY)" := SubLine."Calculation Base Amount";
        SubLine."Unit Cost (LCY)" := SubLine."Unit Cost";
    end;

    local procedure RepairForeignCurrencyFactor(var SubLine: Record "Subscription Line"; var CurrExchRate: Record "Currency Exchange Rate"; var Currency: Record Currency)
    var
        FactorDate: Date;
        NewFactor: Decimal;
    begin
        FactorDate := SubLine."Subscription Line Start Date";
        if FactorDate = 0D then
            FactorDate := WorkDate();

        NewFactor := CurrExchRate.ExchangeRate(FactorDate, SubLine."Currency Code");
        if NewFactor = 0 then
            exit;

        SubLine."Currency Factor" := NewFactor;
        SubLine."Currency Factor Date" := FactorDate;

        Currency.Initialize(SubLine."Currency Code");
        SubLine."Price (LCY)" :=
            Round(
                CurrExchRate.ExchangeAmtFCYToLCY(FactorDate, SubLine."Currency Code", SubLine.Price, NewFactor),
                Currency."Unit-Amount Rounding Precision");
        SubLine."Amount (LCY)" :=
            Round(
                CurrExchRate.ExchangeAmtFCYToLCY(FactorDate, SubLine."Currency Code", SubLine.Amount, NewFactor),
                Currency."Amount Rounding Precision");
        SubLine."Discount Amount (LCY)" :=
            Round(
                CurrExchRate.ExchangeAmtFCYToLCY(FactorDate, SubLine."Currency Code", SubLine."Discount Amount", NewFactor),
                Currency."Amount Rounding Precision");
        SubLine."Calculation Base Amount (LCY)" :=
            Round(
                CurrExchRate.ExchangeAmtFCYToLCY(FactorDate, SubLine."Currency Code", SubLine."Calculation Base Amount", NewFactor),
                Currency."Unit-Amount Rounding Precision");
        SubLine."Unit Cost (LCY)" :=
            Round(
                CurrExchRate.ExchangeAmtFCYToLCY(FactorDate, SubLine."Currency Code", SubLine."Unit Cost", NewFactor),
                Currency."Unit-Amount Rounding Precision");
    end;
}
