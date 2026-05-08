namespace SKC.Subscription;

page 70631070 SubQuantityHistoryList003SKC
{
    Caption = 'Subscription Quantity History';
    PageType = ListPart;
    SourceTable = SubQuantityHistory003SKC;
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
                field(EntryNo003SKC; Rec.EntryNo003SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the entry number.';
                    Visible = false;
                }
                field(ChangeDate003SKC; Rec.ChangeDate003SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date when the quantity was changed.';
                }
                field(OldQuantity003SKC; Rec.OldQuantity003SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity before the change.';
                }
                field(NewQuantity003SKC; Rec.NewQuantity003SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity after the change.';
                }
                field(DeltaQuantity003SKC; Rec.DeltaQuantity003SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the difference between the old and new quantity.';
                    StyleExpr = DeltaStyle;
                }
                field(InterimBilled003SKC; Rec.InterimBilled003SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the quantity change has been billed via interim billing.';
                    StyleExpr = BilledStyle;
                }
                field(InterimDocNo003SKC; Rec.InterimDocNo003SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the posted document number from the interim billing.';
                }
                field(InterimBillingDate003SKC; Rec.InterimBillingDate003SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date when the interim billing was posted.';
                }
                field(Reason003SKC; Rec.Reason003SKC)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the reason for the quantity change.';
                    Editable = true;
                }
                field(UserID003SKC; Rec.UserID003SKC)
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
        if Rec.DeltaQuantity003SKC > 0 then
            DeltaStyle := 'Favorable'
        else
            if Rec.DeltaQuantity003SKC < 0 then
                DeltaStyle := 'Unfavorable'
            else
                DeltaStyle := 'Standard';

        if Rec.InterimBilled003SKC then
            BilledStyle := 'Favorable'
        else
            BilledStyle := 'Attention';
    end;
}
