namespace SKC.Subscription;

/// <summary>
/// Read-only results of schedule simulations, document rebuilds, and posted
/// deferral audits.
///
///   GET /.../dynamicDeferralAnalyses?$filter=runId eq {guid}&amp;$orderby=lineNo
/// </summary>
page 70631121 apiDynDeferralAnalysis085SKC
{
    APIGroup = 'subscriptionBilling';
    APIPublisher = 'skconsulting';
    APIVersion = 'v1.0';
    Caption = 'Dynamic Deferral Analysis';
    DeleteAllowed = false;
    Editable = false;
    EntityName = 'dynamicDeferralAnalysis';
    EntitySetName = 'dynamicDeferralAnalyses';
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = DynDeferralAnalysis085SKC;

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId) { Caption = 'id'; }
                field(runId; Rec.RunId085SKC) { Caption = 'runId'; }
                field(lineNo; Rec.LineNo085SKC) { Caption = 'lineNo'; }
                field(analysisType; Rec.AnalysisType085SKC) { Caption = 'analysisType'; }
                field(runAt; Rec.RunAt085SKC) { Caption = 'runAt'; }
                field(documentNo; Rec.DocumentNo085SKC) { Caption = 'documentNo'; }
                field(documentLineNo; Rec.DocumentLineNo085SKC) { Caption = 'documentLineNo'; }
                field(postingDate; Rec.PostingDate085SKC) { Caption = 'postingDate'; }
                field(periodStart; Rec.PeriodStart085SKC) { Caption = 'periodStart'; }
                field(periodEnd; Rec.PeriodEnd085SKC) { Caption = 'periodEnd'; }
                field(days; Rec.Days085SKC) { Caption = 'days'; }
                field(amount; Rec.Amount085SKC) { Caption = 'amount'; }
                field(currencyCode; Rec.CurrencyCode085SKC) { Caption = 'currencyCode'; }
                field(message; Rec.Message085SKC) { Caption = 'message'; }
                field(isProblem; Rec.IsProblem085SKC) { Caption = 'isProblem'; }
            }
        }
    }
}
