namespace SKC.Subscription;

/// <summary>
/// Asks for the billing period and amount a schedule simulation should use.
/// </summary>
page 70631114 DynDeferralSimulate085SKC
{
    Caption = 'Simulate Deferral Schedule';
    DataCaptionExpression = '';
    PageType = StandardDialog;

    layout
    {
        area(Content)
        {
            group(Parameters085SKC)
            {
                Caption = 'Parameters';

                field(BillingFrom085SKC; BillingFrom)
                {
                    ApplicationArea = All;
                    Caption = 'Billing from';
                    ShowMandatory = true;
                    ToolTip = 'Specifies the first day of the billing period the schedule should cover.';
                }
                field(BillingTo085SKC; BillingTo)
                {
                    ApplicationArea = All;
                    Caption = 'Billing to';
                    ShowMandatory = true;
                    ToolTip = 'Specifies the last day of the billing period the schedule should cover.';
                }
                field(TotalAmount085SKC; TotalAmount)
                {
                    ApplicationArea = All;
                    Caption = 'Amount';
                    ToolTip = 'Specifies the line amount to spread across the billing period.';
                }
                field(CurrencyCode085SKC; CurrencyCode)
                {
                    ApplicationArea = All;
                    Caption = 'Currency Code';
                    ToolTip = 'Specifies the currency whose rounding precision the simulation should use. Leave blank for the local currency.';
                }
            }
        }
    }

    procedure GetBillingFrom(): Date
    begin
        exit(BillingFrom);
    end;

    procedure GetBillingTo(): Date
    begin
        exit(BillingTo);
    end;

    procedure GetAmount(): Decimal
    begin
        exit(TotalAmount);
    end;

    procedure GetCurrencyCode(): Code[10]
    begin
        exit(CurrencyCode);
    end;

    var
        BillingFrom: Date;
        BillingTo: Date;
        TotalAmount: Decimal;
        CurrencyCode: Code[10];
}
