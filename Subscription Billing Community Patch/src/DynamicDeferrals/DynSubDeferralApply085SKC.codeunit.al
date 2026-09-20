namespace SKC.Subscription;

using Microsoft.Purchases.Document;
using Microsoft.Purchases.Posting;
using Microsoft.Sales.Document;
using Microsoft.Sales.Posting;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Carries the chosen deferral engine from the subscription line through the
/// billing proposal into the sales and purchase document, and builds the
/// schedule once the document line exists.
///
/// The method is stamped on the Billing Line when the proposal is created and
/// that stamp is then treated as authoritative. A proposal reviewed before a
/// configuration change therefore posts with the engine it was reviewed under.
///
/// The schedule is built twice: once when the document line is inserted, so it
/// can be inspected before posting, and again immediately before posting,
/// because the amount, the discount, or the billing period may have been edited
/// on the draft document in the meantime.
/// </summary>
codeunit 70631111 DynSubDeferralApply085SKC
{
    Access = Internal;
    Permissions = tabledata "Billing Line" = R,
                  tabledata "Billing Line Archive" = RM,
                  tabledata "Purchase Line" = RM,
                  tabledata "Sales Line" = RM,
                  tabledata "Subscription Line" = R;

    #region Billing proposal

    [EventSubscriber(ObjectType::Table, Database::"Billing Line", OnBeforeInsertEvent, '', false, false)]
    local procedure StampProposalLine(var Rec: Record "Billing Line"; RunTrigger: Boolean)
    var
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
        Method: Enum SubDeferralMethod085SKC;
        TemplateCode: Code[10];
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec.DeferralMethod085SKC <> Rec.DeferralMethod085SKC::"Setup Default" then
            exit;

        DeferralMgmt.ResolveForSubscriptionLine(Rec."Subscription Line Entry No.", Method, TemplateCode);
        Rec.DeferralMethod085SKC := Method;
        Rec.DynDeferralTemplate085SKC := TemplateCode;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Documents", 'OnAfterInsertBillingLineArchiveOnMoveBillingLineToBillingLineArchive', '', false, false)]
    local procedure CarryMethodToSalesArchive(var BillingLineArchive: Record "Billing Line Archive"; BillingLine: Record "Billing Line")
    begin
        CarryMethodToArchive(BillingLineArchive, BillingLine);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purchase Documents", 'OnAfterInsertBillingLineArchiveOnMoveBillingLineToBillingLineArchive', '', false, false)]
    local procedure CarryMethodToPurchaseArchive(var BillingLineArchive: Record "Billing Line Archive"; BillingLine: Record "Billing Line")
    begin
        CarryMethodToArchive(BillingLineArchive, BillingLine);
    end;

    local procedure CarryMethodToArchive(var BillingLineArchive: Record "Billing Line Archive"; BillingLine: Record "Billing Line")
    begin
        if (BillingLineArchive.DeferralMethod085SKC = BillingLine.DeferralMethod085SKC) and
           (BillingLineArchive.DynDeferralTemplate085SKC = BillingLine.DynDeferralTemplate085SKC)
        then
            exit;

        BillingLineArchive.DeferralMethod085SKC := BillingLine.DeferralMethod085SKC;
        BillingLineArchive.DynDeferralTemplate085SKC := BillingLine.DynDeferralTemplate085SKC;
        if BillingLineArchive.Modify(false) then;
    end;

    #endregion

    #region Document creation

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Billing Documents", 'OnBeforeInsertSalesLineFromContractLine', '', false, false)]
    local procedure StampSalesLine(var SalesLine: Record "Sales Line"; var TempBillingLine: Record "Billing Line" temporary)
    var
        Method: Enum SubDeferralMethod085SKC;
        TemplateCode: Code[10];
    begin
        ResolveFromProposal(
            TempBillingLine.DeferralMethod085SKC, TempBillingLine.DynDeferralTemplate085SKC,
            TempBillingLine."Subscription Line Entry No.", Method, TemplateCode);

        SalesLine.DeferralMethod085SKC := Method;
        SalesLine.DynDeferralTemplate085SKC := TemplateCode;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Billing Documents", 'OnBeforeInsertPurchaseLineFromContractLine', '', false, false)]
    local procedure StampPurchaseLine(var PurchLine: Record "Purchase Line"; var TempBillingLine: Record "Billing Line" temporary)
    var
        Method: Enum SubDeferralMethod085SKC;
        TemplateCode: Code[10];
    begin
        ResolveFromProposal(
            TempBillingLine.DeferralMethod085SKC, TempBillingLine.DynDeferralTemplate085SKC,
            TempBillingLine."Subscription Line Entry No.", Method, TemplateCode);

        PurchLine.DeferralMethod085SKC := Method;
        PurchLine.DynDeferralTemplate085SKC := TemplateCode;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Billing Documents", 'OnAfterInsertSalesLineFromBillingLine', '', false, false)]
    local procedure BuildSalesLineSchedule(CustomerContractLine: Record "Cust. Sub. Contract Line"; SalesLine: Record "Sales Line")
    var
        WritableSalesLine: Record "Sales Line";
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
    begin
        if SalesLine.DeferralMethod085SKC <> SalesLine.DeferralMethod085SKC::"Standard Dynamic" then
            exit;
        if not WritableSalesLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.") then
            exit;

        CheckNoDoubleDeferral(GetSubscriptionLineEntryNo(
            WritableSalesLine."Document Type".AsInteger(), WritableSalesLine."Document No.",
            WritableSalesLine."Line No.", true));
        DeferralMgmt.ApplySalesLineDeferral(WritableSalesLine, true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Billing Documents", 'OnAfterInsertPurchaseLineFromBillingLine', '', false, false)]
    local procedure BuildPurchaseLineSchedule(SubscriptionLine: Record "Subscription Line"; PurchaseLine: Record "Purchase Line")
    var
        WritablePurchaseLine: Record "Purchase Line";
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
    begin
        if PurchaseLine.DeferralMethod085SKC <> PurchaseLine.DeferralMethod085SKC::"Standard Dynamic" then
            exit;
        if not WritablePurchaseLine.Get(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.") then
            exit;

        CheckNoDoubleDeferral(SubscriptionLine."Entry No.");
        DeferralMgmt.ApplyPurchaseLineDeferral(WritablePurchaseLine, true);
    end;

    #endregion

    #region Posting

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", OnBeforePostSalesDoc, '', false, false)]
    local procedure RebuildSalesSchedulesBeforePosting(var SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(DeferralMethod085SKC, SalesLine.DeferralMethod085SKC::"Standard Dynamic");
        if SalesLine.IsEmpty() then
            exit;

        if SalesLine.FindSet() then
            repeat
                CheckNoDoubleDeferral(GetSubscriptionLineEntryNo(
                    SalesLine."Document Type".AsInteger(), SalesLine."Document No.", SalesLine."Line No.", true));
            until SalesLine.Next() = 0;

        DeferralMgmt.RebuildSalesDocument(SalesHeader, true);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", OnBeforePostPurchaseDoc, '', false, false)]
    local procedure RebuildPurchaseSchedulesBeforePosting(var PurchaseHeader: Record "Purchase Header")
    var
        PurchaseLine: Record "Purchase Line";
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
    begin
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange(DeferralMethod085SKC, PurchaseLine.DeferralMethod085SKC::"Standard Dynamic");
        if PurchaseLine.IsEmpty() then
            exit;

        if PurchaseLine.FindSet() then
            repeat
                CheckNoDoubleDeferral(GetSubscriptionLineEntryNo(
                    PurchaseLine."Document Type".AsInteger(), PurchaseLine."Document No.", PurchaseLine."Line No.", false));
            until PurchaseLine.Next() = 0;

        DeferralMgmt.RebuildPurchaseDocument(PurchaseHeader, true);
    end;

    #endregion

    #region Helpers

    /// <summary>
    /// The proposal stamp wins. It is only recalculated when the line predates
    /// this feature, or when the dynamic engine was selected but no template
    /// could be resolved at the time the proposal was built.
    /// </summary>
    local procedure ResolveFromProposal(StampedMethod: Enum SubDeferralMethod085SKC; StampedTemplate: Code[10]; SubscriptionLineEntryNo: Integer; var Method: Enum SubDeferralMethod085SKC; var TemplateCode: Code[10])
    var
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
    begin
        Method := StampedMethod;
        TemplateCode := StampedTemplate;

        if (Method <> Method::"Setup Default") and
           ((Method <> Method::"Standard Dynamic") or (TemplateCode <> ''))
        then
            exit;

        DeferralMgmt.ResolveForSubscriptionLine(SubscriptionLineEntryNo, Method, TemplateCode);
    end;

    local procedure CheckNoDoubleDeferral(SubscriptionLineEntryNo: Integer)
    var
        DeferralMgmt: Codeunit DynSubDeferralMgmt085SKC;
        Reason: Text;
    begin
        if DeferralMgmt.ContractDeferralsConflict(SubscriptionLineEntryNo, Reason) then
            Error(Reason);
    end;

    /// <summary>
    /// Finds the subscription line behind an unposted document line. The
    /// billing line still exists at this point: it only moves to the archive
    /// once the document is posted.
    /// </summary>
    local procedure GetSubscriptionLineEntryNo(DocumentType: Integer; DocumentNo: Code[20]; DocumentLineNo: Integer; IsSales: Boolean): Integer
    var
        BillingLine: Record "Billing Line";
        Partner: Enum "Service Partner";
        RecBillingDocType: Enum "Rec. Billing Document Type";
    begin
        Partner := IsSales ? Partner::Customer : Partner::Vendor;
        RecBillingDocType := MapDocumentType(DocumentType, IsSales);
        if RecBillingDocType = RecBillingDocType::None then
            exit(0);

        BillingLine.SetRange(Partner, Partner);
        BillingLine.SetRange("Document Type", RecBillingDocType);
        BillingLine.SetRange("Document No.", DocumentNo);
        BillingLine.SetRange("Document Line No.", DocumentLineNo);
        BillingLine.SetLoadFields("Subscription Line Entry No.");
        if BillingLine.FindFirst() then
            exit(BillingLine."Subscription Line Entry No.");
        exit(0);
    end;

    local procedure MapDocumentType(DocumentType: Integer; IsSales: Boolean): Enum "Rec. Billing Document Type"
    var
        PurchaseHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        Result: Enum "Rec. Billing Document Type";
    begin
        if IsSales then
            case DocumentType of
                SalesHeader."Document Type"::Invoice.AsInteger():
                    exit(Result::Invoice);
                SalesHeader."Document Type"::"Credit Memo".AsInteger():
                    exit(Result::"Credit Memo");
            end
        else
            case DocumentType of
                PurchaseHeader."Document Type"::Invoice.AsInteger():
                    exit(Result::Invoice);
                PurchaseHeader."Document Type"::"Credit Memo".AsInteger():
                    exit(Result::"Credit Memo");
            end;
        exit(Result::None);
    end;

    #endregion
}
