namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631085 SubMarginFactBox085SKC
{
    PageType = CardPart;
    SourceTable = "Subscription Header";
    Caption = 'Subscription Margin';
    Editable = false;

    layout
    {
        area(Content)
        {
            group(StatusGroup)
            {
                Caption = 'Status';
                ShowCaption = false;

                field(SubscriptionStatusField; SubscriptionStatusText)
                {
                    ApplicationArea = All;
                    Caption = 'Subscription Status';
                    ToolTip = 'Overall status of customer subscription lines: Active, Partially Closed, or Closed.';
                    StyleExpr = SubscriptionStatusStyle;
                }
            }
            group(MarginSummary)
            {
                Caption = 'Margin Summary';
                ShowCaption = false;

                field(CustRevenueField; CustRevenue)
                {
                    ApplicationArea = All;
                    Caption = 'Customer Revenue';
                    ToolTip = 'Total Amount across all open customer subscription lines on this Service Object.';
                    BlankZero = true;
                    DecimalPlaces = 2 : 2;
                    AutoFormatType = 1;
                }
                field(VendorCostField; VendorCost)
                {
                    ApplicationArea = All;
                    Caption = 'Vendor Cost';
                    ToolTip = 'Total Amount across all open vendor subscription lines on this Service Object.';
                    BlankZero = true;
                    DecimalPlaces = 2 : 2;
                    AutoFormatType = 1;
                }
                field(GrossMarginField; GrossMargin)
                {
                    ApplicationArea = All;
                    Caption = 'Gross Margin';
                    ToolTip = 'Customer Revenue minus Vendor Cost.';
                    BlankZero = true;
                    DecimalPlaces = 2 : 2;
                    AutoFormatType = 1;
                    StyleExpr = MarginAmtStyle;
                }
                field(MarginPctField; MarginPct)
                {
                    ApplicationArea = All;
                    Caption = 'Margin %';
                    ToolTip = 'Gross Margin / Customer Revenue. Red if negative, amber if below 6%.';
                    BlankZero = true;
                    DecimalPlaces = 1 : 1;
                    StyleExpr = MarginPctStyle;
                }
            }
            group(LineDetail)
            {
                Caption = 'Line Breakdown';
                ShowCaption = true;

                field(CustLineCount; CustLines)
                {
                    ApplicationArea = All;
                    Caption = 'Customer Lines';
                    ToolTip = 'Number of open customer subscription lines.';
                    BlankZero = true;
                }
                field(VendLineCount; VendLines)
                {
                    ApplicationArea = All;
                    Caption = 'Vendor Lines';
                    ToolTip = 'Number of open vendor subscription lines.';
                    BlankZero = true;
                }
                field(NoVendorMatchField; NoVendorMatch)
                {
                    ApplicationArea = All;
                    Caption = 'Unmatched (no vendor)';
                    ToolTip = 'Customer lines with no corresponding vendor line. Margin is 100% but might indicate a missing vendor contract.';
                    BlankZero = true;
                    StyleExpr = UnmatchedStyle;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        CalcSubscriptionStatus();
        CalcAggregatedMargin();
    end;

    local procedure CalcSubscriptionStatus()
    var
        TotalLines: Integer;
        ClosedLines: Integer;
    begin
        Rec.CalcFields(CustLineCount085SKC, ClosedCustLineCount085SKC);
        TotalLines := Rec.CustLineCount085SKC;
        ClosedLines := Rec.ClosedCustLineCount085SKC;

        if TotalLines = 0 then begin
            SubscriptionStatusText := NoLinesLbl;
            SubscriptionStatusStyle := 'Standard';
        end else
            if ClosedLines = TotalLines then begin
                SubscriptionStatusText := ClosedLbl;
                SubscriptionStatusStyle := 'Unfavorable';
            end else
                if ClosedLines > 0 then begin
                    SubscriptionStatusText := PartiallyClosedLbl;
                    SubscriptionStatusStyle := 'Ambiguous';
                end else begin
                    SubscriptionStatusText := ActiveLbl;
                    SubscriptionStatusStyle := 'Favorable';
                end;
    end;

    local procedure CalcAggregatedMargin()
    var
        SubLine: Record "Subscription Line";
    begin
        CustRevenue := 0;
        VendorCost := 0;
        GrossMargin := 0;
        MarginPct := 0;
        CustLines := 0;
        VendLines := 0;
        NoVendorMatch := 0;
        MarginAmtStyle := '';
        MarginPctStyle := '';
        UnmatchedStyle := '';

        SubLine.SetRange("Subscription Header No.", Rec."No.");
        SubLine.SetRange(Closed, false);

        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetLoadFields(Amount);
        if SubLine.FindSet() then
            repeat
                CustRevenue += SubLine.Amount;
                CustLines += 1;
            until SubLine.Next() = 0;

        SubLine.SetRange(Partner, SubLine.Partner::Vendor);
        if SubLine.FindSet() then
            repeat
                VendorCost += SubLine.Amount;
                VendLines += 1;
            until SubLine.Next() = 0;

        GrossMargin := CustRevenue - VendorCost;

        if CustRevenue <> 0 then
            MarginPct := Round(GrossMargin / CustRevenue * 100, 0.1)
        else
            if VendorCost <> 0 then
                MarginPct := -100;

        if GrossMargin < 0 then
            MarginAmtStyle := 'Unfavorable'
        else
            MarginAmtStyle := 'Favorable';

        if MarginPct < 0 then
            MarginPctStyle := 'Unfavorable'
        else
            if MarginPct < 6 then
                MarginPctStyle := 'Ambiguous'
            else
                MarginPctStyle := 'Favorable';

        if (CustLines > 0) and (VendLines = 0) then
            NoVendorMatch := CustLines
        else
            NoVendorMatch := 0;

        if NoVendorMatch > 0 then
            UnmatchedStyle := 'Ambiguous';
    end;

    var
        CustRevenue: Decimal;
        VendorCost: Decimal;
        GrossMargin: Decimal;
        MarginPct: Decimal;
        CustLines: Integer;
        VendLines: Integer;
        NoVendorMatch: Integer;
        MarginAmtStyle: Text;
        MarginPctStyle: Text;
        UnmatchedStyle: Text;
        SubscriptionStatusText: Text;
        SubscriptionStatusStyle: Text;
        ActiveLbl: Label 'Active';
        ClosedLbl: Label 'Closed';
        PartiallyClosedLbl: Label 'Partially Closed';
        NoLinesLbl: Label 'No Lines';
}
