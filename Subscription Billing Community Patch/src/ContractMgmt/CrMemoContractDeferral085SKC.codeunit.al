namespace SKC.Subscription;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Sales.Document;
using Microsoft.Sales.Posting;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Keeps a credit memo consistent with the contract deferrals of the invoice it corrects.
/// When a credit memo corrects an invoice that has contract deferral rows, Subscription
/// Billing copies those rows to the credit memo and releases them at once, which takes the
/// amount out of the contract deferral account. Whether the credit memo line itself posts to
/// that account is decided separately, from the subscription line's current Create Contract
/// Deferrals value. Once contract deferrals have been switched off on the line, the credit memo
/// posts to revenue, revenue is debited twice and the deferral account keeps a balance that
/// nothing clears. The line is routed to the contract deferral account whenever that release
/// is going to happen, as the invoice was posted.
/// </summary>
codeunit 70631071 CrMemoContractDeferral085SKC
{
    Access = Internal;
    Permissions =
        tabledata "Billing Line" = R,
        tabledata "Billing Line Archive" = R,
        tabledata "Cust. Sub. Contract Deferral" = R,
        tabledata "General Posting Setup" = R,
        tabledata "Sales Header" = R;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Post Invoice Events", OnPrepareLineOnAfterSetAmounts, '', false, false)]
    local procedure RouteCreditMemoToContractDeferralAccount(var InvoicePostingBuffer: Record "Invoice Posting Buffer"; SalesLine: Record "Sales Line")
    begin
        RouteToContractDeferralAccount(InvoicePostingBuffer, SalesLine);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Post Invoice Events", OnPrepareLineOnAfterSetLineDiscAccount, '', false, false)]
    local procedure RouteCreditMemoLineDiscountToContractDeferralAccount(SalesLine: Record "Sales Line"; GenPostingSetup: Record "General Posting Setup"; var InvoicePostingBuffer: Record "Invoice Posting Buffer"; var TempInvoicePostingBuffer: Record "Invoice Posting Buffer")
    begin
        RouteToContractDeferralAccount(InvoicePostingBuffer, SalesLine);
    end;

    local procedure RouteToContractDeferralAccount(var InvoicePostingBuffer: Record "Invoice Posting Buffer"; SalesLine: Record "Sales Line")
    var
        DeferralAccount: Code[20];
    begin
        if not CreditMemoReleasesContractDeferrals(SalesLine, DeferralAccount) then
            exit;
        if InvoicePostingBuffer."G/L Account" = DeferralAccount then
            exit;

        InvoicePostingBuffer."G/L Account" := DeferralAccount;
        InvoicePostingBuffer.BuildPrimaryKey();
    end;

    /// <summary>
    /// Mirrors the conditions under which the credit memo posting releases contract
    /// deferrals: the credit memo corrects an invoice (the header's Applies-to Doc. No.,
    /// otherwise the correction document of its billing lines), that invoice has not been
    /// credited before, and it holds contract deferral rows for the same contract line.
    /// </summary>
    local procedure CreditMemoReleasesContractDeferrals(SalesLine: Record "Sales Line"; var DeferralAccount: Code[20]): Boolean
    var
        BillingLine: Record "Billing Line";
        BillingLineArchive: Record "Billing Line Archive";
        CustContractDeferral: Record "Cust. Sub. Contract Deferral";
        GeneralPostingSetup: Record "General Posting Setup";
        SalesHeader: Record "Sales Header";
        InvoiceNo: Code[20];
    begin
        Clear(DeferralAccount);
        if SalesLine."Document Type" <> SalesLine."Document Type"::"Credit Memo" then
            exit(false);
        if SalesLine."Deferral Code" <> '' then
            exit(false);

        BillingLine.SetRange(Partner, BillingLine.Partner::Customer);
        BillingLine.SetRange("Document Type", BillingLine."Document Type"::"Credit Memo");
        BillingLine.SetRange("Document No.", SalesLine."Document No.");
        BillingLine.SetRange("Document Line No.", SalesLine."Line No.");
        BillingLine.SetLoadFields("Subscription Contract No.", "Subscription Contract Line No.");
        if not BillingLine.FindFirst() then
            exit(false);

        SalesHeader.SetLoadFields("Applies-to Doc. No.");
        if SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.") then
            InvoiceNo := SalesHeader."Applies-to Doc. No.";
        if InvoiceNo = '' then
            InvoiceNo := GetCorrectedInvoiceNo(SalesLine."Document No.");
        if InvoiceNo = '' then
            exit(false);

        BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
        BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::"Credit Memo");
        BillingLineArchive.SetRange("Correction Document Type", BillingLineArchive."Correction Document Type"::Invoice);
        BillingLineArchive.SetRange("Correction Document No.", InvoiceNo);
        if not BillingLineArchive.IsEmpty() then
            exit(false);

        CustContractDeferral.SetRange("Document Type", CustContractDeferral."Document Type"::Invoice);
        CustContractDeferral.SetRange("Document No.", InvoiceNo);
        CustContractDeferral.SetRange("Subscription Contract No.", BillingLine."Subscription Contract No.");
        CustContractDeferral.SetRange("Subscription Contract Line No.", BillingLine."Subscription Contract Line No.");
        if CustContractDeferral.IsEmpty() then
            exit(false);

        if not GeneralPostingSetup.Get(SalesLine."Gen. Bus. Posting Group", SalesLine."Gen. Prod. Posting Group") then
            exit(false);
        DeferralAccount := GeneralPostingSetup."Cust. Sub. Contr. Def Account";
        exit(DeferralAccount <> '');
    end;

    local procedure GetCorrectedInvoiceNo(CreditMemoNo: Code[20]): Code[20]
    var
        BillingLine: Record "Billing Line";
    begin
        BillingLine.SetRange(Partner, BillingLine.Partner::Customer);
        BillingLine.SetRange("Document Type", BillingLine."Document Type"::"Credit Memo");
        BillingLine.SetRange("Document No.", CreditMemoNo);
        BillingLine.SetLoadFields("Correction Document No.");
        if BillingLine.FindFirst() then
            exit(BillingLine."Correction Document No.");
        exit('');
    end;
}
