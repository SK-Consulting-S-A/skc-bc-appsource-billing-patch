namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

pageextension 70631132 GetVendContractLines085SKC extends "Get Vendor Contract Lines"
{
    actions
    {
        addlast(processing)
        {
            action(SelectAll085SKC)
            {
                ApplicationArea = All;
                Caption = 'Select All';
                Image = AllLines;
                ToolTip = 'Marks all subscription lines as selected.';

                trigger OnAction()
                begin
                    SetSelectionOnAllLines(true);
                end;
            }
            action(DeselectAll085SKC)
            {
                ApplicationArea = All;
                Caption = 'Deselect All';
                Image = CancelAllLines;
                ToolTip = 'Clears the selection on all subscription lines.';

                trigger OnAction()
                begin
                    SetSelectionOnAllLines(false);
                end;
            }
            action(SelectContractLines085SKC)
            {
                ApplicationArea = All;
                Caption = 'Select Contract Lines';
                Image = SelectEntries;
                ToolTip = 'Selects all subscription lines belonging to the same contract as the current line.';

                trigger OnAction()
                begin
                    SelectLinesByContract(true);
                end;
            }
            action(DeselectContractLines085SKC)
            {
                ApplicationArea = All;
                Caption = 'Deselect Contract Lines';
                Image = RemoveFilterLines;
                ToolTip = 'Deselects all subscription lines belonging to the same contract as the current line.';

                trigger OnAction()
                begin
                    SelectLinesByContract(false);
                end;
            }
        }
    }

    local procedure SetSelectionOnAllLines(Selected: Boolean)
    var
        CurrentEntryNo: Integer;
    begin
        CurrentEntryNo := Rec."Entry No.";
        Rec.SetRange(Indent, 1);
        if Rec.FindSet() then
            repeat
                Rec.Selected := Selected;
                Rec.Modify(false);
            until Rec.Next() = 0;
        Rec.SetRange(Indent);
        if Rec.Get(CurrentEntryNo) then;
        CurrPage.Update(false);
    end;

    local procedure SelectLinesByContract(Selected: Boolean)
    var
        ContractNo: Code[20];
        CurrentEntryNo: Integer;
    begin
        ContractNo := Rec."Subscription Contract No.";
        if ContractNo = '' then
            exit;
        CurrentEntryNo := Rec."Entry No.";
        Rec.SetRange("Subscription Contract No.", ContractNo);
        Rec.SetRange(Indent, 1);
        if Rec.FindSet() then
            repeat
                Rec.Selected := Selected;
                Rec.Modify(false);
            until Rec.Next() = 0;
        Rec.SetRange("Subscription Contract No.");
        Rec.SetRange(Indent);
        if Rec.Get(CurrentEntryNo) then;
        CurrPage.Update(false);
    end;
}
