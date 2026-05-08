# Migration Guide: SKC Customizations to Subscription Billing Community Patch

This document describes the coordinated migration of 30 subscription billing
objects from `SK Customizations` (PTE, ID range 50xxx) to
`Subscription Billing Community Patch` (AppSource, ID range 70631xxx).

## Pre-Requisites

- Subscription Billing Community Patch v1.0 published to AppSource (or deployed via .app)
- `Backup-SubscriptionData.ps1` script tested against a sandbox
- SKC Customizations vNext prepared (files removed, dependency added)

## Objects Moved

| Type | Count | Old ID Range | New ID Range |
|---|---|---|---|
| Tables | 2 | 50317-50318 | 70631050-70631051 |
| Tableextension | 1 | 50316 | 70631052 |
| Tableext fields | 4 | 50140-50143 | 70631053-70631056 |
| Codeunits | 7 | 50055-50277 | 70631060-70631066 |
| Pages | 15 | 50274-50497 | 70631070-70631084 |
| Page extensions | 5 | 50401-50412 | 70631090-70631094 |
| Permission set | 1 (new) | - | 70631095 |

## Per-Tenant Deployment Sequence

### Step 1: Backup (BEFORE any app changes)

```powershell
.\scripts\Backup-SubscriptionData.ps1 `
    -BaseUrl "https://api.businesscentral.dynamics.com/v2.0/<tenant>/<environment>" `
    -CompanyId "<company-guid>" `
    -ClientId "<entra-app-client-id>" `
    -ClientSecret "<secret>" `
    -TenantId "<tenant-id>"
```

This creates three CSV files in `backups/`:
- `SubscriptionLines_<timestamp>.csv` — custom field values only
- `SubscriptionLines_Full_<timestamp>.csv` — all fields for safety
- `SubQuantityHistory_<timestamp>.csv` — quantity change history

### Step 2: Install Subscription Billing Community Patch v1.0

Install the new AppSource app. This creates the new tableextension fields
(70631053-70631056) and tables (70631050-70631051) — all empty initially.

### Step 3: Upgrade SKC Customizations to vNext

Install the new version of SKC Customizations that:
- Removes the 30 moved objects (including the old tableextension with fields 50140-50143)
- Adds a dependency on the Subscription Billing Community Patch app
- Old field data (AutoRenewal, ExtensionTermBackup, etc.) is dropped from SQL

### Step 4: Restore Data

Use the BC web client or API to restore the custom field values from CSV:

**Subscription Line custom fields** (critical):
1. Open the Subscription Lines API page
2. For each row in `SubscriptionLines_<timestamp>.csv` where `autoRenewal = true`:
   - PATCH the corresponding Subscription Line via API with:
     - `autoRenewal = true`
     - `extensionTermBackup = <value from CSV>`

**SubQuantityHistory records:**
1. These records are historical and informational
2. Can be restored via a temporary import page/API in the patch app, or
3. Re-imported via RapidStart/Configuration Package

### Step 5: Verify

- [ ] Check 5 random subscription lines: AutoRenewal flag is correct
- [ ] Check Extension Term Backup values match the CSV
- [ ] Check Notice Period Backup values (if any were non-empty)
- [ ] Check the Expiring Activities cue on the Sub. Billing Role Center shows data
- [ ] Run the auto-reopen batch and verify it processes correctly
- [ ] Verify SubQuantityHistory records are present (if restored)
- [ ] Verify API pages respond correctly (subscriptionLines, billingLines, etc.)

## SKC Customizations vNext Changes

The following changes are needed in `SK Customizations` for the coordinated release:

### 1. Remove 30 files from `src/SKC/Subscription/`

Delete these files (they now live in the patch app):

**AutoRenewal:**
- `SubAutoReopen003SKC.codeunit.al`
- `SubscriptionLine003SKC.tableextension.al`

**QuantityTracking:**
- `SubQuantityHistory003SKC.table.al`
- `SubQuantityHistoryList003SKC.page.al`
- `SubQtyChangeCapture003SKC.codeunit.al`
- `InterimBillingMgmt003SKC.codeunit.al`

**InvoicePreview:**
- `SubInvoicePreviewCalc003SKC.codeunit.al`

**ContractMgmt:**
- `ContractMerge003SKC.codeunit.al`
- `SubContractLineSyncClose003SKC.codeunit.al`
- `SubLineCurrencyFix003SKC.codeunit.al`

**ExpiringCues:**
- `SubExpiringCue003SKC.table.al`
- `SubExpiringActivities003SKC.page.al`
- `SubExpiringSubLines003SKC.page.al`
- `SubBillingStatus003SKC.page.al`
- `SubBillingHistory003SKC.page.al`

**APIs:**
- `apiCustSubContracts003SKC.page.al`
- `apiVendSubContracts003SKC.page.al`
- `apiSubHeaders003SKC.page.al`
- `apiCustContractDeferrals003SKC.page.al`
- `apiSubBillingLines003SKC.page.al`
- `apiSubLineArchive003SKC.page.al`
- `apiCustBillLineArch003SKC.page.al`
- `apiImportSubLines003SKC.page.al`
- `apiVendBillingLineArchive003SKC.page.al`
- `apiVendBillingLines003SKC.page.al`

**PageExtensions:**
- `ServiceCommitments003SKC.pageextension.al`
- `CustContractLineSubp003SKC.pageextension.al`
- `CustSubContractInterim003SKC.pageextension.al`
- `ServiceObjectQtyHist003SKC.pageextension.al`
- `SubBillingRoleCenter003SKC.page.al`

### 2. Add dependency in app.json

```json
{
  "id": "95a0844b-7660-4acd-ae5e-2a12ea8b7c5e",
  "name": "Subscription Billing Community Patch",
  "publisher": "SK Consulting S.A.",
  "version": "1.0.0.0"
}
```

### 3. Update SubSyncPerm003SKC permission set

Remove references to all moved objects (tables, pages, codeunits) from
`SubSyncPerm003SKC.permissionset.al`. The patch app's own
`SubBillPatch003SKC` permission set covers them.

## Rollback Plan

If issues are found after migration:

1. Re-install the previous version of SKC Customizations (with the original objects)
2. The old tableextension fields (50140-50143) are recreated
3. Restore data from the CSV backup
4. Uninstall the patch app

The CSV backup is the safety net — always verify it contains data before proceeding.
