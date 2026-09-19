namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631128 BillingReadinessAct085SKC
{
    Caption = 'Billing Readiness';
    PageType = CardPart;
    SourceTable = BillingReadinessCue085SKC;

    layout
    {
        area(Content)
        {
            cuegroup(BillingIssues)
            {
                Caption = 'Billing Issues';

                field(ZeroPriceLines; Rec."Zero-Price Lines")
                {
                    ApplicationArea = All;
                    Caption = 'Zero-Price Lines';
                    StyleExpr = ZeroPriceStyle;
                    ToolTip = 'Specifies active customer subscription lines with a quantity but no price. These generate zero-amount invoices.';

                    trigger OnDrillDown()
                    begin
                        DrillDownZeroPrice();
                    end;
                }
                field(ContractsWithZeroPrice; Rec."Contracts w/ Zero-Price")
                {
                    ApplicationArea = All;
                    Caption = 'Contracts w/ Zero-Price';
                    StyleExpr = ZeroPriceStyle;
                    ToolTip = 'Specifies the number of customer contracts that have at least one active zero-price subscription line.';

                    trigger OnDrillDown()
                    begin
                        DrillDownContractsWithZeroPrice();
                    end;
                }
                field(StaleBillingLines; Rec."Stale Billing Lines")
                {
                    ApplicationArea = All;
                    Caption = 'Stale Billing';
                    StyleExpr = StaleStyle;
                    ToolTip = 'Specifies active customer subscription lines that are overdue by more than one full Billing Rhythm cycle plus a 14-day grace period.';

                    trigger OnDrillDown()
                    begin
                        DrillDownStale();
                    end;
                }
            }
            cuegroup(MissingSetup)
            {
                Caption = 'Missing Setup';

                field(NoContractAssigned; Rec."No Contract Assigned")
                {
                    ApplicationArea = All;
                    Caption = 'No Contract Assigned';
                    StyleExpr = NoContractStyle;
                    ToolTip = 'Specifies active customer subscription lines not assigned to any customer contract. These cannot be billed.';

                    trigger OnDrillDown()
                    begin
                        DrillDownNoContract();
                    end;
                }
                field(NoNextBillingDate; Rec."No Next Billing Date")
                {
                    ApplicationArea = All;
                    Caption = 'No Next Billing Date';
                    StyleExpr = NoNextBillingStyle;
                    ToolTip = 'Specifies active customer subscription lines with no Next Billing Date. These never appear in a billing proposal.';

                    trigger OnDrillDown()
                    begin
                        DrillDownNoNextBilling();
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
    var
        BillingReadiness: Codeunit BillingReadiness085SKC;
    begin
        BillingReadiness.ComputeCues(Rec);
        Rec.Modify();

        ZeroPriceStyle := Rec."Zero-Price Lines" > 0 ? 'Unfavorable' : 'Favorable';
        StaleStyle := Rec."Stale Billing Lines" > 0 ? 'Unfavorable' : 'Favorable';
        NoContractStyle := Rec."No Contract Assigned" > 0 ? 'Ambiguous' : 'Favorable';
        NoNextBillingStyle := Rec."No Next Billing Date" > 0 ? 'Unfavorable' : 'Favorable';
    end;

    var
        NoContractStyle: Text;
        NoNextBillingStyle: Text;
        StaleStyle: Text;
        ZeroPriceStyle: Text;

    local procedure DrillDownContractsWithZeroPrice()
    var
        CustContract: Record "Customer Subscription Contract";
        SubLine: Record "Subscription Line";
        ContractNo: Code[20];
        ContractNos: List of [Code[20]];
        FilterText: Text;
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetFilter(Quantity, '<>0');
        SubLine.SetRange(Price, 0);
        if SubLine.FindSet() then
            repeat
                if (SubLine."Subscription Contract No." <> '') and
                   not ContractNos.Contains(SubLine."Subscription Contract No.")
                then
                    ContractNos.Add(SubLine."Subscription Contract No.");
            until SubLine.Next() = 0;

        if ContractNos.Count() = 0 then
            exit;

        foreach ContractNo in ContractNos do begin
            if FilterText <> '' then
                FilterText += '|';
            FilterText += ContractNo;
        end;
        CustContract.SetFilter("No.", FilterText);
        Page.Run(Page::"Customer Contracts", CustContract);
    end;

    local procedure DrillDownNoContract()
    var
        SubLine: Record "Subscription Line";
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetFilter(Quantity, '<>0');
        SubLine.SetRange("Subscription Contract No.", '');
        Page.Run(Page::"Service Commitments", SubLine);
    end;

    local procedure DrillDownNoNextBilling()
    var
        SubLine: Record "Subscription Line";
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetFilter(Quantity, '<>0');
        SubLine.SetRange("Next Billing Date", 0D);
        Page.Run(Page::"Service Commitments", SubLine);
    end;

    local procedure DrillDownStale()
    var
        StaleLines: Record "Subscription Line";
        SubLine: Record "Subscription Line";
        BillingReadiness: Codeunit BillingReadiness085SKC;
        EntryNo: Integer;
        EntryNos: List of [Integer];
        FilterText: Text;
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetFilter(Quantity, '<>0');
        SubLine.SetFilter("Next Billing Date", '<>%1', 0D);
        SubLine.SetLoadFields("Entry No.", "Next Billing Date", "Billing Rhythm");
        if SubLine.FindSet() then
            repeat
                if BillingReadiness.IsLineStale(SubLine) then
                    EntryNos.Add(SubLine."Entry No.");
            until SubLine.Next() = 0;

        if EntryNos.Count() = 0 then
            exit;

        foreach EntryNo in EntryNos do begin
            if FilterText <> '' then
                FilterText += '|';
            FilterText += Format(EntryNo);
        end;
        StaleLines.SetFilter("Entry No.", FilterText);
        Page.Run(Page::"Service Commitments", StaleLines);
    end;

    local procedure DrillDownZeroPrice()
    var
        SubLine: Record "Subscription Line";
    begin
        SubLine.SetRange(Closed, false);
        SubLine.SetRange(Partner, SubLine.Partner::Customer);
        SubLine.SetFilter(Quantity, '<>0');
        SubLine.SetRange(Price, 0);
        Page.Run(Page::"Service Commitments", SubLine);
    end;
}
