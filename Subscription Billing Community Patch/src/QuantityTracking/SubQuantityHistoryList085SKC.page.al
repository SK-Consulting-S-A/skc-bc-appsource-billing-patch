namespace SKC.Subscription;

page 70631070 SubQuantityHistoryList085SKC
{
    Caption = 'Subscription Quantity History';
    PageType = ListPart;
    SourceTable = SubQuantityHistory085SKC;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(EntryNo085SKC; Rec.EntryNo085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the entry number.';
                    Visible = false;
                }
                field(ChangeDate085SKC; Rec.ChangeDate085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date when the quantity was changed.';
                }
                field(OldQuantity085SKC; Rec.OldQuantity085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity before the change.';
                }
                field(NewQuantity085SKC; Rec.NewQuantity085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity after the change.';
                }
                field(DeltaQuantity085SKC; Rec.DeltaQuantity085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the difference between the old and new quantity.';
                    StyleExpr = DeltaStyle;
                }
                field(InterimBilled085SKC; Rec.InterimBilled085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the quantity change has been billed via interim billing.';
                    StyleExpr = BilledStyle;
                }
                field(InterimDocNo085SKC; Rec.InterimDocNo085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posted document number from the interim billing.';
                }
                field(InterimBillingDate085SKC; Rec.InterimBillingDate085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date when the interim billing was posted.';
                }
                field(Reason085SKC; Rec.Reason085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the reason for the quantity change.';
                    Editable = true;
                }
                field(UserID085SKC; Rec.UserID085SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who made the quantity change.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        UpdateStyles();
    end;

    var
        DeltaStyle: Text;
        BilledStyle: Text;

    local procedure UpdateStyles()
    begin
        if Rec.DeltaQuantity085SKC > 0 then
            DeltaStyle := 'Favorable'
        else
            if Rec.DeltaQuantity085SKC < 0 then
                DeltaStyle := 'Unfavorable'
            else
                DeltaStyle := 'Standard';

        if Rec.InterimBilled085SKC then
            BilledStyle := 'Favorable'
        else
            BilledStyle := 'Attention';
    end;
}
