namespace SKC.Subscription;

using Microsoft.Finance.Dimension;
using Microsoft.SubscriptionBilling;

pageextension 70631134 ServiceObjects085SKC extends "Service Objects"
{
    layout
    {
        addafter(Description)
        {
            field(SubscriptionStatus085SKC; SubscriptionStatusText)
            {
                ApplicationArea = All;
                Caption = 'Status';
                Editable = false;
                StyleExpr = SubscriptionStatusStyle;
                ToolTip = 'Specifies the overall status of the customer subscription lines: Active, Partially Closed, or Closed.';
            }
            field(Version085SKC; Rec.Version)
            {
                ApplicationArea = All;
                Caption = 'Version';
                Editable = false;
                ToolTip = 'Specifies the version of this subscription.';
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action(FilterByDimension085SKC)
            {
                ApplicationArea = Dimensions;
                Caption = 'Filter by Dimension';
                Image = Dimensions;
                ToolTip = 'Filters the list to show only subscriptions whose lines carry the selected dimension value.';

                trigger OnAction()
                begin
                    RunDimensionFilter();
                end;
            }
            action(ClearDimensionFilter085SKC)
            {
                ApplicationArea = Dimensions;
                Caption = 'Clear Dimension Filter';
                Image = ClearFilter;
                ToolTip = 'Removes any dimension-based filter applied to the subscription list.';

                trigger OnAction()
                begin
                    Rec.SetRange("No.");
                    CurrPage.Update(false);
                end;
            }
        }
        addlast(Category_Process)
        {
            actionref(FilterByDimension085SKC_Promoted; FilterByDimension085SKC) { }
            actionref(ClearDimensionFilter085SKC_Promoted; ClearDimensionFilter085SKC) { }
        }
    }

    trigger OnAfterGetRecord()
    begin
        CalcSubscriptionStatus();
    end;

    var
        ActiveLbl: Label 'Active';
        ClosedLbl: Label 'Closed';
        NoDimMatchMsg: Label 'No subscriptions found with dimension %1 = %2.', Comment = '%1 = Dimension Code, %2 = Dimension Value Code';
        NoLinesLbl: Label 'No Lines';
        PartiallyClosedLbl: Label 'Partially Closed';
        SubscriptionStatusStyle: Text;
        SubscriptionStatusText: Text;

    local procedure CalcSubscriptionStatus()
    var
        ClosedLines: Integer;
        TotalLines: Integer;
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

    local procedure RunDimensionFilter()
    var
        DimSetEntry: Record "Dimension Set Entry";
        DimValue: Record "Dimension Value";
        SubLine: Record "Subscription Line";
        HeaderNo: Code[20];
        HeaderNos: List of [Code[20]];
        FilterText: Text;
    begin
        DimValue.SetRange(Blocked, false);
        if not (Page.RunModal(Page::"Dimension Value List", DimValue) = Action::LookupOK) then
            exit;

        DimSetEntry.SetRange("Dimension Code", DimValue."Dimension Code");
        DimSetEntry.SetRange("Dimension Value Code", DimValue.Code);
        if not DimSetEntry.FindSet() then begin
            Message(NoDimMatchMsg, DimValue."Dimension Code", DimValue.Code);
            exit;
        end;

        repeat
            SubLine.SetRange("Dimension Set ID", DimSetEntry."Dimension Set ID");
            if SubLine.FindSet() then
                repeat
                    if not HeaderNos.Contains(SubLine."Subscription Header No.") then
                        HeaderNos.Add(SubLine."Subscription Header No.");
                until SubLine.Next() = 0;
        until DimSetEntry.Next() = 0;

        if HeaderNos.Count() = 0 then begin
            Message(NoDimMatchMsg, DimValue."Dimension Code", DimValue.Code);
            exit;
        end;

        foreach HeaderNo in HeaderNos do
            if FilterText = '' then
                FilterText := HeaderNo
            else
                FilterText += '|' + HeaderNo;

        Rec.SetFilter("No.", FilterText);
        CurrPage.Update(false);
    end;
}
