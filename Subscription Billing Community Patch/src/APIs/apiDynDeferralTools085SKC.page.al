namespace SKC.Subscription;

using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.SubscriptionBilling;

/// <summary>
/// Actions that simulate, rebuild, and audit dynamic deferral schedules.
///
/// Each action returns a Run ID in lastRunId. Read the result from
/// dynamicDeferralAnalyses, so the same evidence remains available to anyone
/// reviewing what happened.
///
///   POST /.../dynamicDeferralTools({id})/Microsoft.NAV.simulateSchedule
///     body: { "billingFrom": "2026-03-15", "billingTo": "2027-03-14",
///             "totalAmount": 1200, "currencyCode": "" }
///   POST /.../dynamicDeferralTools({id})/Microsoft.NAV.rebuildDocument
///     body: { "isSales": true, "documentType": 2, "documentNo": "SI-001" }
///   POST /.../dynamicDeferralTools({id})/Microsoft.NAV.auditDeferrals
///     body: { "fromDate": "2026-01-01", "toDate": "2026-12-31", "documentNoFilter": "" }
/// </summary>
page 70631122 apiDynDeferralTools085SKC
{
    APIGroup = 'subscriptionBilling';
    APIPublisher = 'skconsulting';
    APIVersion = 'v1.0';
    Caption = 'Dynamic Deferral Tools';
    DeleteAllowed = false;
    Editable = false;
    EntityName = 'dynamicDeferralTool';
    EntitySetName = 'dynamicDeferralTools';
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "Subscription Contract Setup";

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId) { Caption = 'id'; }
                field(defaultDeferralMethod; Rec.DefaultDeferralMethod085SKC) { Caption = 'defaultDeferralMethod'; }
                field(lastRunId; LastRunId) { Caption = 'lastRunId'; }
                field(lastRunRows; LastRunRows) { Caption = 'lastRunRows'; }
                field(lastRunProblems; LastRunProblems) { Caption = 'lastRunProblems'; }
                field(lastRunTotal; LastRunTotal) { Caption = 'lastRunTotal'; }
            }
        }
    }

    [ServiceEnabled]
    procedure simulateSchedule(var ActionContext: WebServiceActionContext; billingFrom: Date; billingTo: Date; totalAmount: Decimal; currencyCode: Code[10])
    var
        Tools: Codeunit DynSubDeferralTools085SKC;
    begin
        ReportRun(Tools.SimulateSchedule(billingFrom, billingTo, totalAmount, currencyCode), ActionContext);
    end;

    [ServiceEnabled]
    procedure rebuildDocument(var ActionContext: WebServiceActionContext; isSales: Boolean; documentType: Integer; documentNo: Code[20])
    var
        PurchaseHeader: Record "Purchase Header";
        SalesHeader: Record "Sales Header";
        Tools: Codeunit DynSubDeferralTools085SKC;
        RunId: Guid;
    begin
        if isSales then begin
            if not SalesHeader.Get(Enum::"Sales Document Type".FromInteger(documentType), documentNo) then
                Error(DocumentNotFoundErr, documentNo);
            RunId := Tools.RebuildSalesDocument(SalesHeader);
        end else begin
            if not PurchaseHeader.Get(Enum::"Purchase Document Type".FromInteger(documentType), documentNo) then
                Error(DocumentNotFoundErr, documentNo);
            RunId := Tools.RebuildPurchaseDocument(PurchaseHeader);
        end;
        ReportRun(RunId, ActionContext);
    end;

    [ServiceEnabled]
    procedure auditDeferrals(var ActionContext: WebServiceActionContext; fromDate: Date; toDate: Date; documentNoFilter: Text)
    var
        Tools: Codeunit DynSubDeferralTools085SKC;
    begin
        ReportRun(Tools.AuditDeferrals(fromDate, toDate, documentNoFilter), ActionContext);
    end;

    /// <summary>
    /// Surfaces the run summary on the entity so a caller can check the outcome
    /// without a second request, while the detail stays in the analysis table.
    /// </summary>
    local procedure ReportRun(RunId: Guid; var ActionContext: WebServiceActionContext)
    var
        Analysis: Record DynDeferralAnalysis085SKC;
    begin
        LastRunId := RunId;
        LastRunTotal := 0;

        Analysis.SetRange(RunId085SKC, RunId);
        LastRunRows := Analysis.Count();
        if Analysis.FindSet() then
            repeat
                LastRunTotal += Analysis.Amount085SKC;
            until Analysis.Next() = 0;

        Analysis.SetRange(IsProblem085SKC, true);
        LastRunProblems := Analysis.Count();

        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::apiDynDeferralTools085SKC);
        ActionContext.AddEntityKey(Rec.FieldNo(SystemId), Rec.SystemId);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;

    var
        LastRunId: Guid;
        LastRunTotal: Decimal;
        LastRunProblems: Integer;
        LastRunRows: Integer;
        DocumentNotFoundErr: Label 'Document %1 was not found.', Comment = '%1 = document number';
}
