namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;
using Microsoft.Sales.History;

page 70631072 SubBillingHistory003SKC
{
    PageType = ListPart;
    SourceTable = "Billing Line Archive";
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;
    Caption = 'Billing History';

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(DocumentType; Rec."Document Type")
                {
                    ApplicationArea = All;
                    Caption = 'Type';
                    ToolTip = 'Specifies whether this is an invoice or credit memo.';
                }
                field(DocumentNo; Rec."Document No.")
                {
                    ApplicationArea = All;
                    Caption = 'Document No.';
                    ToolTip = 'Specifies the posted document number.';

                    trigger OnDrillDown()
                    begin
                        OpenPostedDocument();
                    end;
                }
                field(PostingDate; PostingDateValue)
                {
                    ApplicationArea = All;
                    Caption = 'Posting Date';
                    ToolTip = 'The posting date of the posted document.';
                }
                field(BillingFrom; Rec."Billing from")
                {
                    ApplicationArea = All;
                    Caption = 'Billing from';
                    ToolTip = 'Start date of the billing period.';
                }
                field(BillingTo; Rec."Billing to")
                {
                    ApplicationArea = All;
                    Caption = 'Billing to';
                    ToolTip = 'End date of the billing period.';
                }
                field(Amount; Rec.Amount)
                {
                    ApplicationArea = All;
                    Caption = 'Amount';
                    ToolTip = 'The billed amount for this period.';
                }
                field(CurrencyCode; Rec."Currency Code")
                {
                    ApplicationArea = All;
                    Caption = 'Currency';
                    ToolTip = 'The currency of the billed amount.';
                    Visible = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        PostingDateValue := GetPostingDate();
    end;

    local procedure GetPostingDate(): Date
    var
        SalesInvHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        if Rec."Document No." = '' then
            exit(0D);

        case Rec.Partner of
            Rec.Partner::Customer:
                case Rec."Document Type" of
                    Rec."Document Type"::Invoice:
                        begin
                            SalesInvHeader.SetLoadFields("Posting Date");
                            if SalesInvHeader.Get(Rec."Document No.") then
                                exit(SalesInvHeader."Posting Date");
                        end;
                    Rec."Document Type"::"Credit Memo":
                        begin
                            SalesCrMemoHeader.SetLoadFields("Posting Date");
                            if SalesCrMemoHeader.Get(Rec."Document No.") then
                                exit(SalesCrMemoHeader."Posting Date");
                        end;
                end;
        end;
    end;

    local procedure OpenPostedDocument()
    var
        SalesInvHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        if Rec."Document No." = '' then
            exit;

        case Rec.Partner of
            Rec.Partner::Customer:
                case Rec."Document Type" of
                    Rec."Document Type"::Invoice:
                        if SalesInvHeader.Get(Rec."Document No.") then
                            Page.Run(Page::"Posted Sales Invoice", SalesInvHeader);
                    Rec."Document Type"::"Credit Memo":
                        if SalesCrMemoHeader.Get(Rec."Document No.") then
                            Page.Run(Page::"Posted Sales Credit Memo", SalesCrMemoHeader);
                end;
        end;
    end;

    var
        PostingDateValue: Date;
}
