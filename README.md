# Subscription Billing Community Patch

A comprehensive bugfixing and enhancement app for Microsoft Subscription Billing. Addresses known issues, improves stability, and extends functionality with community-driven fixes.

## Publisher

[SK Consulting S.A.](https://www.skc.lu)

## Requirements

- Microsoft Dynamics 365 Business Central (v27.0+)
- [Subscription Billing](https://appsource.microsoft.com/en-us/product/dynamics-365-business-central/PUBID.microsoftdynsmb%7CAID.sub-billing%7CPAPPID.3099ffc7-4cf7-4df6-9b96-7e4bc2bb587c) by Microsoft

## Features

### Auto-Renewal Management

Prevents subscription lines from closing when they should renew indefinitely. When **Auto-Renewal** is enabled on a subscription line, the extension term and notice period are backed up and automatically restored whenever the standard module attempts to close the line. Includes automatic reopening of linked customer contract lines.

- Toggle auto-renewal per subscription line
- Backs up and restores Extension Term, Notice Period, and Term Until
- Intercepts standard close events to reopen subscription and contract lines
- Batch procedure to reopen all auto-renewal lines at once
- Links orphan vendor subscription lines to their contracts
- Integration events (`OnBeforeAutoReopenSubscriptionLine`, `OnAfterAutoReopenSubscriptionLine`) for custom logic

### Quantity Change Tracking

Captures every subscription header quantity change into a dedicated audit history table, recording old quantity, new quantity, delta, change date, and user.

- Full audit trail of quantity modifications on subscription headers
- Links each change to the relevant subscription line entry
- History viewable via assist-edit on the Service Object quantity field and as a list part

### Interim Billing

Generates pro-rata billing lines for mid-period quantity changes so customers are charged (or credited) for the difference immediately, rather than waiting for the next billing cycle.

- Computes pro-rata amounts based on days remaining in the current billing period
- Creates customer billing lines for unbilled quantity deltas
- Blocks regular billing proposals until interim changes are processed
- Tracks interim billing status (billed flag, document number, dates) on the quantity history
- Available via **Create Interim Billing** action on the Customer Contract page

### Expiring Subscription Cues

Adds a Role Center cue part showing subscription lines approaching their end date, giving proactive visibility into upcoming expirations.

- **Expiring in 30 days** — active lines ending within the next month
- **Expiring in 90 days** — active lines ending within three months
- **Past end date** — lines whose end date has passed but are not yet closed
- Drill-down opens a filtered list with actions to view billing status or open the contract
- Embedded in the **Subscription Billing Role Center**

### Billing Status & History

A detailed status card for any subscription line, combining live billing state with historical invoice data.

- Status indicator (active, expiring soon, fully invoiced, closed)
- Next invoice amount preview (pro-rata calculation from billing base period and rhythm)
- Days until auto-close countdown
- Total invoiced amount from billing line archives
- Last invoice drill-down to the posted sales invoice
- Billing history list part with posting dates and document links

### Contract Management Utilities

Maintenance codeunits for fixing data inconsistencies and consolidating contracts.

- **Contract Merge** — consolidates multiple customer contracts per customer into one, moving all contract lines and updating linked subscription lines. Supports dry-run mode and detailed logging.
- **Contract Line Sync** — synchronizes closed state between subscription lines and their customer contract lines, clearing orphaned next billing dates.
- **Currency Fix** — repairs subscription lines with missing currency factors: clears LCY-like codes or recalculates foreign currency factors from exchange rates and recomputes LCY amount fields.

### Page Extensions

Extends standard Subscription Billing pages with additional fields and actions.

- **Service Commitments** — editable Next Billing Date (for migration fixes), Next Invoice Amount, Auto-Renewal toggle, actions to Set End Date, Cancel, Reopen, Show Billing Status, and Open Contract
- **Customer Contract Line Subpage** — Next Invoice Amount, Subscription Closed indicator, Open Subscription action
- **Customer Contract** — Create Interim Billing action
- **Service Object** — Quantity history assist-edit and list part

### API Surfaces

Eleven OData v4 API pages under `skconsulting/subscriptionBilling/v1.0` for external integrations and migration tooling.

| Endpoint | Source Table | Access |
|----------|-------------|--------|
| `customerSubscriptionContracts` | Customer Subscription Contract | Read / Modify / Delete |
| `vendorSubscriptionContracts` | Vendor Subscription Contract | Full CRUD |
| `subscriptionHeaders` | Subscription Header | Read / Modify (quantity, UoM, dates) |
| `subscriptionBillingLines` | Billing Line (Customer) | Read-only |
| `vendorBillingLines` | Billing Line (Vendor) | Read-only |
| `customerBillingLineArchives` | Billing Line Archive (Customer) | Read-only |
| `vendorBillingLineArchives` | Billing Line Archive (Vendor) | Read-only |
| `customerSubscriptionContractDeferrals` | Cust. Sub. Contract Deferral | Read-only |
| `subscriptionLineArchives` | Subscription Line Archive | Insert / Delete |
| `importedSubscriptionLines` | Imported Subscription Line | Full CRUD |

### Permissions

A single assignable permission set (`SubBillPatch003SKC`) covers all custom tables, codeunits, pages, and API pages included in the extension.

## Build & CI/CD

This project uses [AL-Go for GitHub](https://aka.ms/AL-Go) for continuous integration and delivery.
