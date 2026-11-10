namespace SKC.Subscription;

using Microsoft.Sales.History;

/// <summary>
/// Posted Recurring Billing invoices, with a Cancel that lets the caller decide what happens
/// to Next Billing Date where no other invoice covers the cancelled period.
///   POST /skconsulting/subscriptionBilling/v1.0/companies({id})/postedContractInvoices({id})/Microsoft.NAV.cancelWithRebill
///     body: { "rebillCancelledPeriod": false }
/// rebillCancelledPeriod = true keeps the standard reset (the next billing run invoices the
/// period again), false puts back the date the line had before the cancel. Where other
/// invoices still bill the period, Next Billing Date stays on them either way
/// (SubCancelNbdGuard085SKC). Returns one sentence per subscription line.
/// </summary>
page 70631086 apiContractInvCancel085SKC
{
    PageType = API;
    APIPublisher = 'skconsulting';
    APIGroup = 'subscriptionBilling';
    APIVersion = 'v1.0';
    EntityName = 'postedContractInvoice';
    EntitySetName = 'postedContractInvoices';
    SourceTable = "Sales Invoice Header";
    SourceTableView = where("Recurring Billing" = const(true));
    ODataKeyFields = SystemId;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Caption = 'Posted Contract Invoices';

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId) { }
                field(no; Rec."No.") { }
                field(billToCustomerNo; Rec."Bill-to Customer No.") { }
                field(postingDate; Rec."Posting Date") { }
                field(currencyCode; Rec."Currency Code") { }
                field(amount; Rec.Amount) { }
                field(cancelled; Rec.Cancelled) { }
            }
        }
    }

    [ServiceEnabled]
    procedure cancelWithRebill(var ActionContext: WebServiceActionContext; rebillCancelledPeriod: Boolean): Text
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        CancelNbdGuard: Codeunit SubCancelNbdGuard085SKC;
        CorrectPostedSalesInvoice: Codeunit "Correct Posted Sales Invoice";
        LineOutcome: Text;
        Summary: Text;
    begin
        SalesInvoiceHeader.Get(Rec."No.");
        CancelNbdGuard.StartCancel(SalesInvoiceHeader."No.", true, rebillCancelledPeriod);
        CorrectPostedSalesInvoice.CancelPostedInvoice(SalesInvoiceHeader);
        Summary := StrSubstNo(CancelledMsg, SalesInvoiceHeader."No.");
        LineOutcome := CancelNbdGuard.FinishCancel();
        if LineOutcome <> '' then
            Summary += ' ' + LineOutcome;

        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::apiContractInvCancel085SKC);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
        exit(Summary);
    end;

    var
        CancelledMsg: Label 'Posted sales invoice %1 cancelled.', Comment = '%1 = posted sales invoice number';
}
