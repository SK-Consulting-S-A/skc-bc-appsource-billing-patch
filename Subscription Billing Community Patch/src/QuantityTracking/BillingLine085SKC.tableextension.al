namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

/// <summary>
/// Marks the billing lines produced by interim billing.
///
/// An interim line charges only the quantity added mid-period, so it must not be
/// treated like an ordinary recurring line when the sales document is built.
/// Standard document creation reads the quantity from the Subscription Header
/// rather than the billing line, and the marker is what lets that be corrected
/// for interim charges alone.
/// </summary>
tableextension 70631053 BillingLine085SKC extends "Billing Line"
{
    fields
    {
        field(70631053; InterimBilling085SKC; Boolean)
        {
            Caption = 'Interim Billing';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }
}
