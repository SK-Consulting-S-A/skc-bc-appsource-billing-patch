namespace SKC.Subscription;

/// <summary>
/// Which engine defers the revenue or cost of a subscription billing line.
///
/// The two engines are mutually exclusive on a single document line. The
/// platform blocks a standard Deferral Code on a line whose Subscription Line
/// still requests contract deferrals, so the effective method also decides what
/// "Create Contract Deferrals" must be set to.
/// </summary>
enum 70631099 SubDeferralMethod085SKC
{
    Caption = 'Subscription Deferral Method';
    Extensible = false;

    value(0; "Setup Default")
    {
        Caption = 'Setup Default';
    }
    value(1; "Subscription Deferral")
    {
        Caption = 'Subscription Deferral';
    }
    value(2; "Standard Dynamic")
    {
        Caption = 'Standard Dynamic';
    }
    value(3; "No Deferral")
    {
        Caption = 'No Deferral';
    }
}
