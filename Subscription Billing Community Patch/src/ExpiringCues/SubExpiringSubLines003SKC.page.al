namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

page 70631074 SubExpiringSubLines003SKC
{
    PageType = List;
    SourceTable = "Subscription Line";
    SourceTableView = where(Closed = const(false), Partner = const(Customer));
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;
    Caption = 'Expiring Subscription Lines';

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(EntryNo; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The unique entry number of the subscription line.';
                }
                field(SubHeaderNo; Rec."Subscription Header No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The subscription (service object) number.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Description of the subscription line.';
                }
                field(ContractNo; Rec."Subscription Contract No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The linked customer subscription contract.';
                }
                field(EndDate; Rec."Subscription Line End Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'The end date after which the line will be closed.';
                    StyleExpr = EndDateStyle;
                }
                field(NextBillingDate; Rec."Next Billing Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'The date of the next billing.';
                }
                field(TermUntil; Rec."Term Until")
                {
                    ApplicationArea = All;
                    ToolTip = 'The date until which the current contract term runs.';
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                    ToolTip = 'The recurring amount for the subscription line.';
                }
                field(AutoRenewal; Rec.AutoRenewal003SKC)
                {
                    ApplicationArea = All;
                    Caption = 'Auto-Renewal';
                    ToolTip = 'Whether the subscription auto-renews.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ShowBillingStatus)
            {
                ApplicationArea = All;
                Caption = 'Show Billing Status';
                Image = ViewDetails;
                ToolTip = 'Shows detailed billing status for the selected subscription line.';

                trigger OnAction()
                var
                    SubLine: Record "Subscription Line";
                begin
                    SubLine.Get(Rec."Entry No.");
                    Page.RunModal(Page::SubBillingStatus003SKC, SubLine);
                end;
            }
            action(OpenContract)
            {
                ApplicationArea = All;
                Caption = 'Open Contract';
                Image = Document;
                ToolTip = 'Opens the linked customer subscription contract.';

                trigger OnAction()
                var
                    CustSubContract: Record "Customer Subscription Contract";
                begin
                    if Rec."Subscription Contract No." = '' then
                        exit;
                    CustSubContract.Get(Rec."Subscription Contract No.");
                    Page.Run(Page::"Customer Contract", CustSubContract);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(ShowBillingStatus_Promoted; ShowBillingStatus) { }
                actionref(OpenContract_Promoted; OpenContract) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        if (Rec."Subscription Line End Date" <> 0D) and (Rec."Subscription Line End Date" < Today) then
            EndDateStyle := 'Unfavorable'
        else
            if (Rec."Subscription Line End Date" <> 0D) and (Rec."Subscription Line End Date" <= CalcDate('<+30D>', Today)) then
                EndDateStyle := 'Ambiguous'
            else
                EndDateStyle := '';
    end;

    var
        EndDateStyle: Text;
}
