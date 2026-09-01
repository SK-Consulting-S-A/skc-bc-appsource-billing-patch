namespace SKC.Subscription;

/// <summary>
/// What produced a dynamic deferral analysis row.
/// </summary>
enum 70631100 DynDeferralAnalysisType085SKC
{
    Caption = 'Dynamic Deferral Analysis Type';
    Extensible = false;

    value(0; Simulation)
    {
        Caption = 'Schedule Simulation';
    }
    value(1; Rebuild)
    {
        Caption = 'Document Rebuild';
    }
    value(2; Audit)
    {
        Caption = 'Posted Deferral Audit';
    }
}
