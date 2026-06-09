namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

permissionset 70631095 SubBillPatch085SKC
{
    Access = Public;
    Assignable = true;
    Caption = 'Sub. Billing Community Patch';

    Permissions =
        table SubQuantityHistory085SKC = X,
        table SubExpiringCue085SKC = X,
        tabledata SubQuantityHistory085SKC = RIMD,
        tabledata SubExpiringCue085SKC = RIMD,
        tabledata "Subscription Line" = RM,
        tabledata "Subscription Header" = RM,
        tabledata "Subscription Contract Setup" = R,
        tabledata "Cust. Sub. Contract Line" = RM,
        tabledata "Vend. Sub. Contract Line" = RM,
        tabledata "Billing Line" = RIMD,
        tabledata "Billing Line Archive" = RM,
        codeunit SubAutoReopen085SKC = X,
        codeunit ContractMerge085SKC = X,
        codeunit SubLineCurrencyFix085SKC = X,
        codeunit SubContractLineSyncClose085SKC = X,
        codeunit SubInvoicePreviewCalc085SKC = X,
        codeunit InterimBillingMgmt085SKC = X,
        codeunit SubQtyChangeCapture085SKC = X,
        codeunit SubArchiveCloseCheck085SKC = X,
        codeunit SubLineCalcBasePct085SKC = X,
        page SubMarginFactBox085SKC = X,
        page SubQuantityHistoryList085SKC = X,
        page SubBillingStatus085SKC = X,
        page SubBillingHistory085SKC = X,
        page SubExpiringActivities085SKC = X,
        page SubExpiringSubLines085SKC = X,
        page apiCustSubContracts085SKC = X,
        page apiSubBillingLines085SKC = X,
        page apiVendSubContracts085SKC = X,
        page apiVendBillingLines085SKC = X,
        page apiVendBillLineArch085SKC = X,
        page apiImportSubLines085SKC = X,
        page apiCustBillLineArch085SKC = X,
        page apiSubHeaders085SKC = X,
        page apiSubLineArchive085SKC = X,
        page apiCustContractDeferrals085SKC = X;
}
