namespace SKC.Subscription;

using Microsoft.Sales.History;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Decides which subscriptions of a posted sales invoice a posted sales credit memo credits.
/// Meant for anything that must act only on what a credit memo really credited, such as
/// reversing what is left of a deferral or reporting invoices that were credited, so such a
/// tool and a check that asks for it follow the same rule.
///
/// A sales line belongs to the subscription of the customer contract line it bills
/// (Subscription Contract No. / Line No.), otherwise to the subscription of its customer
/// billing archive rows when they all name the same one.
///
/// A credit memo credits a subscription of the invoice only when the part of it that credits
/// this invoice covers what the invoice charged for the subscription (never a partial credit):
/// - (a) standard correction: its customer billing archive rows, or its billing lines while not
///   archived yet, for the subscription have Correction Document Type Invoice and Correction
///   Document No. = the invoice (Cancel, Correct, corrective credit memo). The rows that correct
///   the invoice must cover the invoice's own archive rows for the subscription - rows of the
///   same credit memo that correct another invoice do not count - and its lines for the
///   subscription the invoice's lines.
/// - (b) not a Recurring Billing document (manual or API v2.0 credit) and not applied to any
///   other document. When it has customer archive rows for the subscription, only the rows that
///   overlap a billing period the invoice billed for it count, also when it is applied to the
///   invoice, and they must cover the invoice's net amount for the subscription: a credit of
///   another term that is only applied to the invoice to settle its balance never qualifies. A
///   row with exactly the period of another invoice on the same subscription line credits that
///   other invoice (an interim charge inside a three-year invoice overlaps it without crediting
///   it). Only a credit memo without archive rows for the subscription (v2.0 credit whose archive
///   was not reconstructed) can qualify through being applied to the invoice, by its line amounts,
///   and only when its lines carry the contract line they credit.
/// Archive rows are taken by size (Abs, credit rows are archived with either sign); rows of a
/// discount subscription line count negative. Amounts are without VAT, in LCY when the
/// currencies differ.
/// Never counted: Recurring Billing credit memos without a correction reference (billing run
/// and interim seat decreases, which settle a quantity change inside a period), any document
/// listed as interim document (InterimDocNo) in the quantity history, credits of another term
/// and partial credits.
/// Read-only.
/// </summary>
codeunit 70631073 SubCreditMatch085SKC
{
    Access = Public;
    Permissions =
        tabledata "Billing Line" = R,
        tabledata "Billing Line Archive" = R,
        tabledata "Cust. Sub. Contract Line" = R,
        tabledata "Sales Cr.Memo Header" = R,
        tabledata "Sales Cr.Memo Line" = R,
        tabledata "Sales Invoice Header" = R,
        tabledata "Sales Invoice Line" = R,
        tabledata SubQuantityHistory085SKC = R,
        tabledata "Subscription Line" = R;

    #region Public API

    /// <summary>
    /// The subscriptions of the posted invoice that a posted credit memo credits, each with the
    /// numbers of the credit memos that do so. Empty when no subscription qualifies.
    /// </summary>
    procedure CollectCreditedSubscriptions(InvoiceNo: Code[20]; var CreditedBy: Dictionary of [Code[20], Text])
    var
        CreditMemoNos: List of [Code[20]];
        Subscriptions: List of [Code[20]];
        CreditMemoNo: Code[20];
        SubscriptionNo: Code[20];
    begin
        Clear(CreditedBy);
        CollectInvoiceSubscriptions(InvoiceNo, Subscriptions);
        if Subscriptions.Count() = 0 then
            exit;

        AddCorrectingCreditMemos(InvoiceNo, CreditMemoNos);
        AddAppliedCreditMemos(InvoiceNo, CreditMemoNos);
        AddOverlappingCreditMemos(InvoiceNo, CreditMemoNos);

        foreach CreditMemoNo in CreditMemoNos do
            foreach SubscriptionNo in Subscriptions do
                if CreditsSubscription(CreditMemoNo, InvoiceNo, SubscriptionNo) then
                    AddCredit(CreditedBy, SubscriptionNo, CreditMemoNo);
    end;

    /// <summary>
    /// Whether the posted credit memo credits the subscription on the posted invoice, by the
    /// rule described on this codeunit. Results are kept for the lifetime of the instance.
    /// </summary>
    procedure CreditsSubscription(CreditMemoNo: Code[20]; InvoiceNo: Code[20]; SubscriptionNo: Code[20]) Result: Boolean
    var
        MatchKey: Text;
    begin
        if (CreditMemoNo = '') or (InvoiceNo = '') or (SubscriptionNo = '') then
            exit(false);
        MatchKey := StrSubstNo(MatchKeyTok, CreditMemoNo, InvoiceNo, SubscriptionNo);
        if MatchResults.Get(MatchKey, Result) then
            exit(Result);
        Result := EvaluateCredit(CreditMemoNo, InvoiceNo, SubscriptionNo);
        MatchResults.Add(MatchKey, Result);
    end;

    /// <summary>
    /// False when the credit memo can credit an invoice only through a correction reference,
    /// or not at all: a Recurring Billing document (billing run, interim seat decrease), a
    /// document listed as interim document in the quantity history, or no posted credit memo.
    /// </summary>
    procedure MayCreditWithoutReference(CreditMemoNo: Code[20]): Boolean
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        SalesCrMemoHeader.SetLoadFields("Recurring Billing");
        if not SalesCrMemoHeader.Get(CreditMemoNo) then
            exit(false);
        if SalesCrMemoHeader."Recurring Billing" then
            exit(false);
        exit(not IsInterimDocument(CreditMemoNo));
    end;

    /// <summary>
    /// Whether this customer archive row of a credit memo, without correction reference, credits
    /// a billing period of the invoice: it overlaps one the invoice billed for its subscription and
    /// is not the exact period of another invoice. The monitor pairs a credit row only with such an
    /// invoice.
    /// </summary>
    procedure CreditRowOverlapsInvoice(CreditArchive: Record "Billing Line Archive"; InvoiceNo: Code[20]): Boolean
    begin
        if CreditArchive."Correction Document No." <> '' then
            exit(false);
        exit(RowOverlapsInvoice(CreditArchive, InvoiceNo));
    end;

    #endregion

    #region Rule

    local procedure EvaluateCredit(CreditMemoNo: Code[20]; InvoiceNo: Code[20]; SubscriptionNo: Code[20]): Boolean
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        AppliedToInvoice: Boolean;
    begin
        SalesCrMemoHeader.SetLoadFields(
            "Recurring Billing", "Applies-to Doc. Type", "Applies-to Doc. No.", "Pre-Assigned No.", "Currency Code", "Currency Factor");
        if not SalesCrMemoHeader.Get(CreditMemoNo) then
            exit(false);
        SalesInvoiceHeader.SetLoadFields("Currency Code", "Currency Factor");
        if not SalesInvoiceHeader.Get(InvoiceNo) then
            exit(false);
        if IsInterimDocument(CreditMemoNo) then
            exit(false);

        // (a) Standard correction of the invoice.
        if HasCorrectionReference(SalesCrMemoHeader, InvoiceNo, SubscriptionNo) then
            exit(
                LinesCoverInvoice(SalesCrMemoHeader, SalesInvoiceHeader, SubscriptionNo) and
                CorrectionRowsCoverInvoice(SalesCrMemoHeader, InvoiceNo, SubscriptionNo));

        // (b) Manual or v2.0 credit memo. Without a correction reference a Recurring Billing
        // credit memo is a billing-run or interim credit, never a credit of the invoice.
        if SalesCrMemoHeader."Recurring Billing" then
            exit(false);
        if SalesCrMemoHeader."Applies-to Doc. No." <> '' then begin
            if (SalesCrMemoHeader."Applies-to Doc. Type" <> SalesCrMemoHeader."Applies-to Doc. Type"::Invoice) or
               (SalesCrMemoHeader."Applies-to Doc. No." <> InvoiceNo)
            then
                exit(false);
            AppliedToInvoice := true;
        end;
        // The archive tells which term was credited; an application may only settle a balance.
        if HasArchiveRows(CreditMemoNo, SubscriptionNo) then
            exit(OverlappingRowsCoverInvoice(SalesCrMemoHeader, SalesInvoiceHeader, SubscriptionNo));
        if AppliedToInvoice then
            exit(LinesCoverInvoice(SalesCrMemoHeader, SalesInvoiceHeader, SubscriptionNo));
        exit(false);
    end;

    /// <summary>
    /// The credit memo's lines for the subscription add up to at least the invoice's net amount
    /// for it.
    /// </summary>
    local procedure LinesCoverInvoice(SalesCrMemoHeader: Record "Sales Cr.Memo Header"; SalesInvoiceHeader: Record "Sales Invoice Header"; SubscriptionNo: Code[20]): Boolean
    begin
        exit(
            AmountCovers(
                SubscriptionAmount(true, SalesCrMemoHeader."No.", SubscriptionNo), SalesCrMemoHeader,
                SubscriptionAmount(false, SalesInvoiceHeader."No.", SubscriptionNo), SalesInvoiceHeader));
    end;

    /// <summary>
    /// The credited amount covers the invoice's amount (both without VAT, in LCY when the
    /// currencies differ). A subscription the invoice did not charge never qualifies.
    /// </summary>
    local procedure AmountCovers(CreditAmount: Decimal; SalesCrMemoHeader: Record "Sales Cr.Memo Header"; InvoiceAmount: Decimal; SalesInvoiceHeader: Record "Sales Invoice Header"): Boolean
    begin
        if SalesCrMemoHeader."Currency Code" <> SalesInvoiceHeader."Currency Code" then begin
            InvoiceAmount := ToLCY(InvoiceAmount, SalesInvoiceHeader."Currency Code", SalesInvoiceHeader."Currency Factor");
            CreditAmount := ToLCY(CreditAmount, SalesCrMemoHeader."Currency Code", SalesCrMemoHeader."Currency Factor");
        end;
        if InvoiceAmount < AmountTolerance() then
            exit(false);
        exit(CreditAmount >= InvoiceAmount - AmountTolerance());
    end;

    /// <summary>
    /// (a) The credit memo's rows that correct the invoice for the subscription (archive, or
    /// billing lines while not archived yet) cover the invoice's own archive rows for it. Both
    /// sides come from the billing archive, so a full correction matches to the cent, and rows of
    /// the same credit memo that correct another invoice do not count.
    /// </summary>
    local procedure CorrectionRowsCoverInvoice(SalesCrMemoHeader: Record "Sales Cr.Memo Header"; InvoiceNo: Code[20]; SubscriptionNo: Code[20]): Boolean
    var
        BillingLine: Record "Billing Line";
        CreditArchive: Record "Billing Line Archive";
        InvoiceArchive: Record "Billing Line Archive";
        CreditedAmount: Decimal;
        InvoicedAmount: Decimal;
    begin
        InvoiceArchive.SetRange(Partner, InvoiceArchive.Partner::Customer);
        InvoiceArchive.SetRange("Document Type", InvoiceArchive."Document Type"::Invoice);
        InvoiceArchive.SetRange("Document No.", InvoiceNo);
        InvoiceArchive.SetRange("Subscription Header No.", SubscriptionNo);
        InvoiceArchive.SetLoadFields("Subscription Line Entry No.", Amount);
        if InvoiceArchive.FindSet() then
            repeat
                InvoicedAmount += OrientedAmount(InvoiceArchive."Subscription Line Entry No.", InvoiceArchive.Amount);
            until InvoiceArchive.Next() = 0;

        CreditArchive.SetRange(Partner, CreditArchive.Partner::Customer);
        CreditArchive.SetRange("Document Type", CreditArchive."Document Type"::"Credit Memo");
        CreditArchive.SetRange("Document No.", SalesCrMemoHeader."No.");
        CreditArchive.SetRange("Correction Document Type", CreditArchive."Correction Document Type"::Invoice);
        CreditArchive.SetRange("Correction Document No.", InvoiceNo);
        CreditArchive.SetRange("Subscription Header No.", SubscriptionNo);
        CreditArchive.SetLoadFields("Subscription Line Entry No.", Amount);
        if CreditArchive.FindSet() then
            repeat
                CreditedAmount += OrientedAmount(CreditArchive."Subscription Line Entry No.", CreditArchive.Amount);
            until CreditArchive.Next() = 0
        else begin
            BillingLine.SetRange(Partner, BillingLine.Partner::Customer);
            BillingLine.SetRange("Document Type", BillingLine."Document Type"::"Credit Memo");
            if SalesCrMemoHeader."Pre-Assigned No." <> '' then
                BillingLine.SetFilter("Document No.", '%1|%2', SalesCrMemoHeader."No.", SalesCrMemoHeader."Pre-Assigned No.")
            else
                BillingLine.SetRange("Document No.", SalesCrMemoHeader."No.");
            BillingLine.SetRange("Correction Document Type", BillingLine."Correction Document Type"::Invoice);
            BillingLine.SetRange("Correction Document No.", InvoiceNo);
            BillingLine.SetRange("Subscription Header No.", SubscriptionNo);
            BillingLine.SetLoadFields("Subscription Line Entry No.", Amount);
            if BillingLine.FindSet() then
                repeat
                    CreditedAmount += OrientedAmount(BillingLine."Subscription Line Entry No.", BillingLine.Amount);
                until BillingLine.Next() = 0;
        end;

        exit(CreditedAmount >= InvoicedAmount - AmountTolerance());
    end;

    /// <summary>
    /// (a) The credit memo's customer billing archive rows for the subscription, or its billing
    /// lines (under the posted or the pre-assigned number) while they are not archived yet, name
    /// the invoice as the corrected document.
    /// </summary>
    local procedure HasCorrectionReference(SalesCrMemoHeader: Record "Sales Cr.Memo Header"; InvoiceNo: Code[20]; SubscriptionNo: Code[20]): Boolean
    var
        BillingLine: Record "Billing Line";
        BillingLineArchive: Record "Billing Line Archive";
    begin
        BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
        BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::"Credit Memo");
        BillingLineArchive.SetRange("Document No.", SalesCrMemoHeader."No.");
        BillingLineArchive.SetRange("Correction Document Type", BillingLineArchive."Correction Document Type"::Invoice);
        BillingLineArchive.SetRange("Correction Document No.", InvoiceNo);
        BillingLineArchive.SetRange("Subscription Header No.", SubscriptionNo);
        if not BillingLineArchive.IsEmpty() then
            exit(true);

        BillingLine.SetRange(Partner, BillingLine.Partner::Customer);
        BillingLine.SetRange("Document Type", BillingLine."Document Type"::"Credit Memo");
        if SalesCrMemoHeader."Pre-Assigned No." <> '' then
            BillingLine.SetFilter("Document No.", '%1|%2', SalesCrMemoHeader."No.", SalesCrMemoHeader."Pre-Assigned No.")
        else
            BillingLine.SetRange("Document No.", SalesCrMemoHeader."No.");
        BillingLine.SetRange("Correction Document Type", BillingLine."Correction Document Type"::Invoice);
        BillingLine.SetRange("Correction Document No.", InvoiceNo);
        BillingLine.SetRange("Subscription Header No.", SubscriptionNo);
        exit(not BillingLine.IsEmpty());
    end;

    /// <summary>
    /// Whether the credit memo has customer archive rows for the subscription at all. When it
    /// does, they decide which term it credits.
    /// </summary>
    local procedure HasArchiveRows(CreditMemoNo: Code[20]; SubscriptionNo: Code[20]): Boolean
    var
        BillingLineArchive: Record "Billing Line Archive";
    begin
        BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
        BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::"Credit Memo");
        BillingLineArchive.SetRange("Document No.", CreditMemoNo);
        BillingLineArchive.SetRange("Subscription Header No.", SubscriptionNo);
        exit(not BillingLineArchive.IsEmpty());
    end;

    /// <summary>
    /// (b) Only the credit memo's customer archive rows for the subscription, without correction
    /// reference, that credit a billing period of the invoice count (RowOverlapsInvoice), and
    /// together they must cover the invoice's net amount for the subscription. A row for another
    /// term never helps, whether or not the credit memo is applied to the invoice.
    /// </summary>
    local procedure OverlappingRowsCoverInvoice(SalesCrMemoHeader: Record "Sales Cr.Memo Header"; SalesInvoiceHeader: Record "Sales Invoice Header"; SubscriptionNo: Code[20]): Boolean
    var
        CreditArchive: Record "Billing Line Archive";
        CreditedAmount: Decimal;
        Overlaps: Boolean;
    begin
        CreditArchive.SetRange(Partner, CreditArchive.Partner::Customer);
        CreditArchive.SetRange("Document Type", CreditArchive."Document Type"::"Credit Memo");
        CreditArchive.SetRange("Document No.", SalesCrMemoHeader."No.");
        CreditArchive.SetRange("Subscription Header No.", SubscriptionNo);
        CreditArchive.SetRange("Correction Document No.", '');
        CreditArchive.SetLoadFields("Subscription Header No.", "Subscription Line Entry No.", "Billing from", "Billing to", Amount);
        if CreditArchive.FindSet() then
            repeat
                if RowOverlapsInvoice(CreditArchive, SalesInvoiceHeader."No.") then begin
                    Overlaps := true;
                    CreditedAmount += OrientedAmount(CreditArchive."Subscription Line Entry No.", CreditArchive.Amount);
                end;
            until CreditArchive.Next() = 0;
        if not Overlaps then
            exit(false);
        exit(
            AmountCovers(
                CreditedAmount, SalesCrMemoHeader,
                SubscriptionAmount(false, SalesInvoiceHeader."No.", SubscriptionNo), SalesInvoiceHeader));
    end;

    /// <summary>
    /// The credit row overlaps a billing period the invoice billed for its subscription and does
    /// not belong to another invoice.
    /// </summary>
    local procedure RowOverlapsInvoice(CreditArchive: Record "Billing Line Archive"; InvoiceNo: Code[20]): Boolean
    var
        InvoiceArchive: Record "Billing Line Archive";
    begin
        if CreditArchive."Subscription Header No." = '' then
            exit(false);
        InvoiceArchive.SetRange(Partner, InvoiceArchive.Partner::Customer);
        InvoiceArchive.SetRange("Document Type", InvoiceArchive."Document Type"::Invoice);
        InvoiceArchive.SetRange("Document No.", InvoiceNo);
        InvoiceArchive.SetRange("Subscription Header No.", CreditArchive."Subscription Header No.");
        InvoiceArchive.SetFilter("Billing from", '<=%1', CreditArchive."Billing to");
        InvoiceArchive.SetFilter("Billing to", '>=%1', CreditArchive."Billing from");
        InvoiceArchive.SetLoadFields("Document No.", "Billing from", "Billing to");
        if InvoiceArchive.FindSet() then
            repeat
                if not CreditBelongsToOtherInvoice(CreditArchive, InvoiceArchive) then
                    exit(true);
            until InvoiceArchive.Next() = 0;
        exit(false);
    end;

    /// <summary>
    /// A credit row whose exact period is that of another invoice on the same subscription
    /// line, while this invoice's period differs, credits that other invoice: an interim seat
    /// charge inside a three-year invoice overlaps it without crediting it.
    /// </summary>
    local procedure CreditBelongsToOtherInvoice(CreditArchive: Record "Billing Line Archive"; InvoiceArchive: Record "Billing Line Archive"): Boolean
    var
        OtherArchive: Record "Billing Line Archive";
    begin
        if (CreditArchive."Billing from" = InvoiceArchive."Billing from") and (CreditArchive."Billing to" = InvoiceArchive."Billing to") then
            exit(false);
        OtherArchive.SetRange(Partner, OtherArchive.Partner::Customer);
        OtherArchive.SetRange("Document Type", OtherArchive."Document Type"::Invoice);
        OtherArchive.SetRange("Subscription Line Entry No.", CreditArchive."Subscription Line Entry No.");
        OtherArchive.SetRange("Billing from", CreditArchive."Billing from");
        OtherArchive.SetRange("Billing to", CreditArchive."Billing to");
        OtherArchive.SetFilter("Document No.", '<>%1', InvoiceArchive."Document No.");
        exit(not OtherArchive.IsEmpty());
    end;

    /// <summary>
    /// A document interim billing raised for a quantity change (InterimDocNo in the quantity
    /// history). An interim credit memo settles a seat decrease inside a period and never
    /// credits an invoice.
    /// </summary>
    local procedure IsInterimDocument(DocumentNo: Code[20]): Boolean
    var
        QtyHistory: Record SubQuantityHistory085SKC;
        IsInterim: Boolean;
    begin
        if InterimDocuments.Get(DocumentNo, IsInterim) then
            exit(IsInterim);
        QtyHistory.SetRange(InterimDocNo085SKC, DocumentNo);
        IsInterim := not QtyHistory.IsEmpty();
        InterimDocuments.Add(DocumentNo, IsInterim);
        exit(IsInterim);
    end;

    #endregion

    #region Candidates

    /// <summary>
    /// The subscriptions on the invoice's lines.
    /// </summary>
    local procedure CollectInvoiceSubscriptions(InvoiceNo: Code[20]; var Subscriptions: List of [Code[20]])
    var
        SalesInvoiceLine: Record "Sales Invoice Line";
        SubscriptionNo: Code[20];
    begin
        Clear(Subscriptions);
        SalesInvoiceLine.SetRange("Document No.", InvoiceNo);
        SalesInvoiceLine.SetFilter(Type, '<>%1', SalesInvoiceLine.Type::" ");
        SalesInvoiceLine.SetLoadFields(Type, "Line No.", "Subscription Contract No.", "Subscription Contract Line No.");
        if SalesInvoiceLine.FindSet() then
            repeat
                SubscriptionNo := SubscriptionOfLine(
                    false, InvoiceNo, SalesInvoiceLine."Line No.",
                    SalesInvoiceLine."Subscription Contract No.", SalesInvoiceLine."Subscription Contract Line No.");
                if SubscriptionNo <> '' then
                    if not Subscriptions.Contains(SubscriptionNo) then
                        Subscriptions.Add(SubscriptionNo);
            until SalesInvoiceLine.Next() = 0;
    end;

    /// <summary>
    /// Credit memos whose archive rows, or billing lines while not posted, name the invoice as
    /// the corrected document. A billing line is mapped to the posted credit memo through its
    /// pre-assigned number; an unposted draft credits nothing.
    /// </summary>
    local procedure AddCorrectingCreditMemos(InvoiceNo: Code[20]; var CreditMemoNos: List of [Code[20]])
    var
        BillingLine: Record "Billing Line";
        BillingLineArchive: Record "Billing Line Archive";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
        BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::"Credit Memo");
        BillingLineArchive.SetRange("Correction Document Type", BillingLineArchive."Correction Document Type"::Invoice);
        BillingLineArchive.SetRange("Correction Document No.", InvoiceNo);
        BillingLineArchive.SetLoadFields("Document No.");
        if BillingLineArchive.FindSet() then
            repeat
                AddCandidate(CreditMemoNos, BillingLineArchive."Document No.");
            until BillingLineArchive.Next() = 0;

        BillingLine.SetRange(Partner, BillingLine.Partner::Customer);
        BillingLine.SetRange("Document Type", BillingLine."Document Type"::"Credit Memo");
        BillingLine.SetRange("Correction Document Type", BillingLine."Correction Document Type"::Invoice);
        BillingLine.SetRange("Correction Document No.", InvoiceNo);
        BillingLine.SetFilter("Document No.", '<>%1', '');
        BillingLine.SetLoadFields("Document No.");
        if BillingLine.FindSet() then
            repeat
                SalesCrMemoHeader.Reset();
                SalesCrMemoHeader.SetCurrentKey("Pre-Assigned No.");
                SalesCrMemoHeader.SetRange("Pre-Assigned No.", BillingLine."Document No.");
                SalesCrMemoHeader.SetLoadFields("No.");
                if SalesCrMemoHeader.FindFirst() then
                    AddCandidate(CreditMemoNos, SalesCrMemoHeader."No.");
            until BillingLine.Next() = 0;
    end;

    local procedure AddAppliedCreditMemos(InvoiceNo: Code[20]; var CreditMemoNos: List of [Code[20]])
    var
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        SalesCrMemoHeader.SetRange("Applies-to Doc. Type", SalesCrMemoHeader."Applies-to Doc. Type"::Invoice);
        SalesCrMemoHeader.SetRange("Applies-to Doc. No.", InvoiceNo);
        SalesCrMemoHeader.SetLoadFields("No.");
        if SalesCrMemoHeader.FindSet() then
            repeat
                AddCandidate(CreditMemoNos, SalesCrMemoHeader."No.");
            until SalesCrMemoHeader.Next() = 0;
    end;

    /// <summary>
    /// Credit memos with a customer archive row, without correction reference, on a subscription
    /// of the invoice whose period overlaps the invoice's row for that subscription.
    /// </summary>
    local procedure AddOverlappingCreditMemos(InvoiceNo: Code[20]; var CreditMemoNos: List of [Code[20]])
    var
        CreditArchive: Record "Billing Line Archive";
        InvoiceArchive: Record "Billing Line Archive";
    begin
        InvoiceArchive.SetRange(Partner, InvoiceArchive.Partner::Customer);
        InvoiceArchive.SetRange("Document Type", InvoiceArchive."Document Type"::Invoice);
        InvoiceArchive.SetRange("Document No.", InvoiceNo);
        InvoiceArchive.SetFilter("Subscription Header No.", '<>%1', '');
        InvoiceArchive.SetLoadFields("Subscription Header No.", "Billing from", "Billing to");
        if InvoiceArchive.FindSet() then
            repeat
                CreditArchive.Reset();
                CreditArchive.SetRange(Partner, CreditArchive.Partner::Customer);
                CreditArchive.SetRange("Document Type", CreditArchive."Document Type"::"Credit Memo");
                CreditArchive.SetRange("Subscription Header No.", InvoiceArchive."Subscription Header No.");
                CreditArchive.SetRange("Correction Document No.", '');
                CreditArchive.SetFilter("Billing from", '<=%1', InvoiceArchive."Billing to");
                CreditArchive.SetFilter("Billing to", '>=%1', InvoiceArchive."Billing from");
                CreditArchive.SetLoadFields("Document No.");
                if CreditArchive.FindSet() then
                    repeat
                        AddCandidate(CreditMemoNos, CreditArchive."Document No.");
                    until CreditArchive.Next() = 0;
            until InvoiceArchive.Next() = 0;
    end;

    local procedure AddCandidate(var CreditMemoNos: List of [Code[20]]; CreditMemoNo: Code[20])
    begin
        if CreditMemoNo = '' then
            exit;
        if not CreditMemoNos.Contains(CreditMemoNo) then
            CreditMemoNos.Add(CreditMemoNo);
    end;

    local procedure AddCredit(var CreditedBy: Dictionary of [Code[20], Text]; SubscriptionNo: Code[20]; CreditMemoNo: Code[20])
    var
        CreditMemoNos: Text;
    begin
        if not CreditedBy.Get(SubscriptionNo, CreditMemoNos) then begin
            CreditedBy.Add(SubscriptionNo, CreditMemoNo);
            exit;
        end;
        if CreditMemoNos.Split(', ').Contains(CreditMemoNo) then
            exit;
        CreditedBy.Set(SubscriptionNo, CreditMemoNos + ', ' + CreditMemoNo);
    end;

    #endregion

    #region Amounts

    /// <summary>
    /// The net amount (without VAT) of the document's lines that bill the subscription, discount
    /// lines included.
    /// </summary>
    local procedure SubscriptionAmount(IsCreditMemo: Boolean; DocumentNo: Code[20]; SubscriptionNo: Code[20]): Decimal
    var
        Amount: Decimal;
    begin
        LoadDocumentAmounts(IsCreditMemo, DocumentNo);
        if DocumentAmounts.Get(AmountKey(IsCreditMemo, DocumentNo, SubscriptionNo), Amount) then
            exit(Amount);
        exit(0);
    end;

    local procedure LoadDocumentAmounts(IsCreditMemo: Boolean; DocumentNo: Code[20])
    var
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        SalesInvoiceLine: Record "Sales Invoice Line";
        DocumentKey: Text;
    begin
        DocumentKey := AmountKey(IsCreditMemo, DocumentNo, '');
        if LoadedDocuments.Contains(DocumentKey) then
            exit;
        LoadedDocuments.Add(DocumentKey);

        if IsCreditMemo then begin
            SalesCrMemoLine.SetRange("Document No.", DocumentNo);
            SalesCrMemoLine.SetFilter(Type, '<>%1', SalesCrMemoLine.Type::" ");
            SalesCrMemoLine.SetLoadFields(Type, "Line No.", Amount, "Subscription Contract No.", "Subscription Contract Line No.");
            if SalesCrMemoLine.FindSet() then
                repeat
                    AddDocumentAmount(
                        AmountKey(
                            IsCreditMemo, DocumentNo,
                            SubscriptionOfLine(
                                IsCreditMemo, DocumentNo, SalesCrMemoLine."Line No.",
                                SalesCrMemoLine."Subscription Contract No.", SalesCrMemoLine."Subscription Contract Line No.")),
                        SalesCrMemoLine.Amount);
                until SalesCrMemoLine.Next() = 0;
            exit;
        end;

        SalesInvoiceLine.SetRange("Document No.", DocumentNo);
        SalesInvoiceLine.SetFilter(Type, '<>%1', SalesInvoiceLine.Type::" ");
        SalesInvoiceLine.SetLoadFields(Type, "Line No.", Amount, "Subscription Contract No.", "Subscription Contract Line No.");
        if SalesInvoiceLine.FindSet() then
            repeat
                AddDocumentAmount(
                    AmountKey(
                        IsCreditMemo, DocumentNo,
                        SubscriptionOfLine(
                            IsCreditMemo, DocumentNo, SalesInvoiceLine."Line No.",
                            SalesInvoiceLine."Subscription Contract No.", SalesInvoiceLine."Subscription Contract Line No.")),
                    SalesInvoiceLine.Amount);
            until SalesInvoiceLine.Next() = 0;
    end;

    local procedure AddDocumentAmount(AmountKeyText: Text; Amount: Decimal)
    var
        KnownAmount: Decimal;
    begin
        if DocumentAmounts.Get(AmountKeyText, KnownAmount) then
            DocumentAmounts.Set(AmountKeyText, KnownAmount + Amount)
        else
            DocumentAmounts.Add(AmountKeyText, Amount);
    end;

    local procedure AmountKey(IsCreditMemo: Boolean; DocumentNo: Code[20]; SubscriptionNo: Code[20]): Text
    begin
        if IsCreditMemo then
            exit(StrSubstNo(AmountKeyTok, CreditMemoKeyTok, DocumentNo, SubscriptionNo));
        exit(StrSubstNo(AmountKeyTok, InvoiceKeyTok, DocumentNo, SubscriptionNo));
    end;

    local procedure ToLCY(Amount: Decimal; CurrencyCode: Code[10]; CurrencyFactor: Decimal): Decimal
    begin
        if (CurrencyCode = '') or (CurrencyFactor = 0) then
            exit(Amount);
        exit(Round(Amount / CurrencyFactor));
    end;

    /// <summary>
    /// The size of an archive amount (credit rows are archived with either sign), negative for a
    /// discount subscription line. The line's own Discount flag decides: on reconstructed rows the
    /// archive's Discount field is also set by a line discount %.
    /// </summary>
    local procedure OrientedAmount(SubLineEntryNo: Integer; Amount: Decimal): Decimal
    begin
        if IsDiscountLine(SubLineEntryNo) then
            exit(-Abs(Amount));
        exit(Abs(Amount));
    end;

    local procedure IsDiscountLine(SubLineEntryNo: Integer): Boolean
    var
        SubscriptionLine: Record "Subscription Line";
        IsDiscount: Boolean;
    begin
        if DiscountLines.Get(SubLineEntryNo, IsDiscount) then
            exit(IsDiscount);
        SubscriptionLine.SetLoadFields(Discount);
        if SubscriptionLine.Get(SubLineEntryNo) then
            IsDiscount := SubscriptionLine.Discount;
        DiscountLines.Add(SubLineEntryNo, IsDiscount);
        exit(IsDiscount);
    end;

    local procedure AmountTolerance(): Decimal
    begin
        exit(0.005);
    end;

    /// <summary>
    /// The subscription a posted sales line bills: that of the customer contract line it bills,
    /// otherwise that of its customer billing archive rows when they all name the same one. A
    /// line that maps to no subscription (or to several) counts for none.
    /// </summary>
    local procedure SubscriptionOfLine(IsCreditMemo: Boolean; DocumentNo: Code[20]; LineNo: Integer; ContractNo: Code[20]; ContractLineNo: Integer): Code[20]
    var
        BillingLineArchive: Record "Billing Line Archive";
        CustContractLine: Record "Cust. Sub. Contract Line";
        LineKey: Text;
        SubscriptionNo: Code[20];
    begin
        if (ContractNo <> '') and (ContractLineNo <> 0) then begin
            LineKey := StrSubstNo(ContractLineKeyTok, ContractNo, ContractLineNo);
            if SubscriptionByLine.Get(LineKey, SubscriptionNo) then
                exit(SubscriptionNo);
            CustContractLine.SetLoadFields("Subscription Header No.");
            if CustContractLine.Get(ContractNo, ContractLineNo) then
                SubscriptionNo := CustContractLine."Subscription Header No.";
            SubscriptionByLine.Add(LineKey, SubscriptionNo);
            if SubscriptionNo <> '' then
                exit(SubscriptionNo);
        end;

        BillingLineArchive.SetRange(Partner, BillingLineArchive.Partner::Customer);
        if IsCreditMemo then
            BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::"Credit Memo")
        else
            BillingLineArchive.SetRange("Document Type", BillingLineArchive."Document Type"::Invoice);
        BillingLineArchive.SetRange("Document No.", DocumentNo);
        BillingLineArchive.SetRange("Document Line No.", LineNo);
        BillingLineArchive.SetFilter("Subscription Header No.", '<>%1', '');
        BillingLineArchive.SetLoadFields("Subscription Header No.");
        if not BillingLineArchive.FindFirst() then
            exit('');
        SubscriptionNo := BillingLineArchive."Subscription Header No.";
        BillingLineArchive.SetFilter("Subscription Header No.", '<>%1&<>%2', '', SubscriptionNo);
        if not BillingLineArchive.IsEmpty() then
            exit('');
        exit(SubscriptionNo);
    end;
    #endregion

    var
        DiscountLines: Dictionary of [Integer, Boolean];
        DocumentAmounts: Dictionary of [Text, Decimal];
        InterimDocuments: Dictionary of [Code[20], Boolean];
        MatchResults: Dictionary of [Text, Boolean];
        SubscriptionByLine: Dictionary of [Text, Code[20]];
        LoadedDocuments: List of [Text];
        ContractLineKeyTok: Label '%1|%2', Comment = '%1 = contract number, %2 = contract line number', Locked = true;
        AmountKeyTok: Label '%1|%2|%3', Comment = '%1 = document kind, %2 = document number, %3 = subscription number', Locked = true;
        CreditMemoKeyTok: Label 'C', Locked = true;
        InvoiceKeyTok: Label 'I', Locked = true;
        MatchKeyTok: Label '%1|%2|%3', Comment = '%1 = credit memo number, %2 = invoice number, %3 = subscription number', Locked = true;
}
