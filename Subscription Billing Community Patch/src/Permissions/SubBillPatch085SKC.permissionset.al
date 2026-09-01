namespace SKC.Subscription;

using Microsoft.Finance.Deferral;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
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
        codeunit SubBillExpectedCalc085SKC = X,
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
        page apiCustContractDeferrals085SKC = X,
        table DynDeferralAnalysis085SKC = X,
        tabledata DynDeferralAnalysis085SKC = RIMD,
        tabledata "Deferral Header" = RIMD,
        tabledata "Deferral Line" = RIMD,
        tabledata "Deferral Template" = RIMD,
        tabledata "Posted Deferral Header" = R,
        tabledata "Posted Deferral Line" = R,
        tabledata "Purch. Cr. Memo Line" = R,
        tabledata "Purch. Inv. Line" = R,
        tabledata "Purchase Line" = RM,
        tabledata "Sales Cr.Memo Line" = R,
        tabledata "Sales Invoice Line" = R,
        tabledata "Sales Line" = RM,
        tabledata "Cust. Sub. Contract Deferral" = R,
        tabledata "Vend. Sub. Contract Deferral" = R,
        codeunit DynSubDeferralApply085SKC = X,
        codeunit DynSubDeferralMgmt085SKC = X,
        codeunit DynSubDeferralTools085SKC = X,
        page DynDeferralAnalyses085SKC = X,
        page DynDeferralSimulate085SKC = X,
        page apiDynDeferralAnalysis085SKC = X,
        page apiDynDeferralHeaders085SKC = X,
        page apiDynDeferralLines085SKC = X,
        page apiDynDeferralSetup085SKC = X,
        page apiDynDeferralTemplates085SKC = X,
        page apiDynDeferralTools085SKC = X;
}
