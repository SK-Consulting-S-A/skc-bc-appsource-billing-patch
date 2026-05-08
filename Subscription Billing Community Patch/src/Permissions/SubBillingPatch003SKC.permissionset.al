namespace SKC.Subscription;

using Microsoft.SubscriptionBilling;

permissionset 70631095 SubBillingPatch003SKC
{
    Access = Public;
    Assignable = true;
    Caption = 'Sub. Billing Community Patch';

    Permissions =
        table SubQuantityHistory003SKC = X,
        table SubExpiringCue003SKC = X,
        tabledata SubQuantityHistory003SKC = RIMD,
        tabledata SubExpiringCue003SKC = RIMD,
        tabledata "Subscription Line" = RM,
        codeunit SubAutoReopen003SKC = X,
        codeunit ContractMerge003SKC = X,
        codeunit SubLineCurrencyFix003SKC = X,
        codeunit SubContractLineSyncClose003SKC = X,
        codeunit SubInvoicePreviewCalc003SKC = X,
        codeunit InterimBillingMgmt003SKC = X,
        codeunit SubQtyChangeCapture003SKC = X,
        page SubQuantityHistoryList003SKC = X,
        page SubBillingStatus003SKC = X,
        page SubBillingHistory003SKC = X,
        page SubExpiringActivities003SKC = X,
        page SubExpiringSubLines003SKC = X,
        page apiCustSubContracts003SKC = X,
        page apiSubBillingLines003SKC = X,
        page apiVendSubContracts003SKC = X,
        page apiVendBillingLines003SKC = X,
        page apiVendBillLineArch003SKC = X,
        page apiImportSubLines003SKC = X,
        page apiCustBillLineArch003SKC = X,
        page apiSubHeaders003SKC = X,
        page apiSubLineArchive003SKC = X,
        page apiCustContractDeferrals003SKC = X;
}
