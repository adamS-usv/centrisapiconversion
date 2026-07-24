# Project Atlas Phase 2 — Master Implementation Plan

This is the consolidated, single-source implementation plan for converting the legacy SQL Server stored procedures, views, and functions across the four `*-idb` source databases into REST APIs following the USV Stack architecture template.

It supersedes the per-source planning documents (`aisREADME.md`, `boomiREADME.md`) for execution; those remain in this folder as reference.

**For developers porting consumers**: see the companion `SPROC_VIEW_API_MAPPING.md` for the per-object cheat sheet (every sproc/view → target API endpoint with parameters).

**Source databases covered**:


| Source DB         | Status     | Sprocs                                           | Views                                          | Notes                                                            |
| ----------------- | ---------- | ------------------------------------------------ | ---------------------------------------------- | ---------------------------------------------------------------- |
| `ais-idb`         | ✅ Planned | ~270 (~145 after triage)                         | several                                        | core business procs (D365 mirror)                                |
| `boomi-idb`       | ✅ Planned | 3 truncate-only (no API surface)                 | 5                                              | Salesforce sync                                                  |
| `integration-idb` | ✅ Planned | 26 (12 USV business + 4 Esker + 10 DBA-skipped) | ~70 USV/business views in scope                | **The ~290 `dbo.*` base-table mirror views are OUT OF SCOPE** — repositories will query the `d365.*` source tables directly (see §D.1, §J) |
| `rudi-idb`        | ✅ Planned | 16 (4 COMPASS + 12 lookup)                       | 1                                              | RUDI/COMPASS reconciliation surface                              |


**Total planned: 19 APIs / ~165 endpoints.** Net new objects from integration + rudi = 12 USV procs + 4 Esker procs + 16 rudi procs + 1 rudi view + ~10 USV business views worth API exposure; the rest absorb into existing endpoints as join inputs. The 290 integration base-table mirror views are dropped (the repos go straight to `d365.*` instead — see §J).

---

## A. Inventory triage rules

These rules apply to every source DB. ais drops ~125 dead-code variants down to ~145 canonical procs; boomi needed no triage; integration drops ~10 DBA/utility procs (`AzureSQLMaintenance`, `CommandExecute`, `DatabaseIntegrityCheck`, `MERGECDC`, `SetTableStatus`, `sp_dbRolesUsersMap`, `sp_WhoIsActive`, `spApplyIndexes`, `usv_row_counts`, `usv_RowCounts`) — these stay as DB-side maintenance objects, no API surface; rudi has no dead code (16 of 16 procs and the 1 view are all canonical).

Integration also drops the **~290 `dbo.*` base-table mirror views** (e.g. `dbo.custtable`, `dbo.salesline`, `dbo.dirpartytable`, etc.). These are simple `SELECT * FROM <ax_source>` projections that exist only to provide a queryable mirror of the AX/D365 source schema. Since API repositories will query the `d365.*` schema directly (see §D.1), these mirror views are not needed and are NOT being ported.

**Drop the following name patterns** (the latest non-suffixed name survives):

- **Backup/snapshot suffixes**: `_BAK_*`, `_Bkup`, `_ORIG`, `_old`, `_New`, `_DEBUG`, `_DEBUG2`, `_TEST_*`
- **Author/review tags**: `_RK_*`, `_NickReview_*`, `_JimW`, `_DL_ReadyForDL`
- **Dated revisions**: e.g. `_07172024`, `_08082025`, `_01022026`, `_20260223`, `_Dec122022`, `_1106`, `_1014`, `_1013`, `_02262026`, `_03042026`, `_02032026`, `_2024_10_04`, `_01262025`
- **Numeric versions** (`vN`): collapse to highest version, but **confirm with the source team which `vN` is in production** — see Open Question §I.1
- `**5001/5002` prefix** files: Phase-1 migration stubs, treat the un-prefixed variant as canonical
- `**0001` prefix**: seed/init scripts — handled as ref-data DDL, not endpoints

**Vendor-specific variants are NOT dead code** (`_Michelin`, `_Bridgestone`, `_ToyoTYMT`, `_GoodyearEnduranceTrailer`, `_FordLubes`). They encode different join/filter logic per vendor and collapse into a single endpoint with a `vendor` discriminator parameter; the per-vendor branching moves into the handler/repository.

---

## B. Master domain map

The 19 planned APIs span four schemas: `ais.*` (AX/D365 mirror business data — the bulk), `eta.*` (route/transit), `boomi.*` (Salesforce sync), `rudi.*` (COMPASS reconciliation), plus `dbo.*` integration-side USV objects that fold into ais domains.

Endpoint counts marked **(+N from integ/rudi)** show net additions from the integration-idb / rudi-idb consolidation. "Canonical objects" totals reflect both the original ais/boomi count and any procs/views absorbed from integration/rudi.


| #   | Domain                | Project                              | Schemas             | Endpoints           | Canonical objects                 |
| --- | --------------------- | ------------------------------------ | ------------------- | ------------------- | --------------------------------- |
| 1   | OrderStatus           | `Services.OrderStatus.Api`           | `ais` + `dbo`       | ~10 (+1 from integ) | ~22 (+2)                          |
| 2   | Invoice               | `Services.Invoice.Api`               | `ais` + `rudi`      | ~10 (+1 from rudi)  | ~16 (+1)                          |
| 3   | InvoiceMatching       | `Services.InvoiceMatching.Api`       | `ais` + `dbo`       | ~6                  | ~8 (+usvibsinvoicematchdata view) |
| 4   | PurchaseOrder         | `Services.PurchaseOrder.Api`         | `ais`               | ~6                  | ~9                                |
| 5   | TransferOrder         | `Services.TransferOrder.Api`         | `ais` + `dbo`       | 3                   | 4 (+usvwarehousetransfersupplywarehouse) |
| 6   | Customer              | `Services.Customer.Api`              | `ais` + `dbo` + `rudi` | ~15 (+3)         | ~31 (+6)                          |
| 7   | Vendor                | `Services.Vendor.Api`                | `ais` + `rudi`      | ~13 (+4 from rudi)  | ~17 (+6)                          |
| 8   | VendorProgram         | `Services.VendorProgram.Api`         | `ais` + `dbo`       | ~16                 | ~36 (+SSP/TPNA support views)     |
| 9   | Product               | `Services.Product.Api`               | `ais` + `dbo`       | ~19                 | ~33 (+ecores attribute views)     |
| 10  | Program               | `Services.Program.Api`               | `ais` + `dbo`       | ~10 (+1 dq)         | ~20 (+program/exclusion views)    |
| 11  | Warehouse             | `Services.Warehouse.Api`             | `ais` + `dbo`       | ~10 (+2)            | ~16 (+3)                          |
| 12  | EdiInbound            | `Services.EdiInbound.Api`            | `ais` + `dbo`       | ~6                  | ~11 (+usvtpnabatchduplicatetable) |
| 13  | EdiOutbound           | `Services.EdiOutbound.Api`           | `ais`               | ~6                  | ~13                               |
| 14  | Delivery              | `Services.Delivery.Api`              | `ais` + `dbo` + `rudi` | ~10 (+3)         | ~14 (+5)                          |
| 15  | Routes                | `Services.Routes.Api`                | `eta` + `dbo`       | ~6                  | 11 (+route views)                 |
| 16  | Platform              | `Services.Platform.Api`              | `ais` + `dbo`       | ~6 (+1 dq)          | ~7 (+usvinboundqueuelog)          |
| 17  | SalesforceIntegration | `Services.SalesforceIntegration.Api` | `boomi` + `dbo`     | 7 (+1)              | 6 views (+vCustomerContactInfo_SalesForce) |
| **18** | **Finance** *(new)* | `Services.Finance.Api`               | `dbo` + `rudi`      | ~12 *(new)*         | ~14 (4 Esker + USVExtractARVentus + 5 USV views + 4 rudi procs + 1 rudi view) |
| **19** | **RudiCompass** *(new)* | `Services.RudiCompass.Api`         | `rudi`              | 4 *(new)*           | 4 (the 4 COMPASSValidate* procs)  |


**Subtotals**: ~165 endpoints across 19 APIs. ~211 ais/boomi canonical objects + 16 net new procs (12 USV biz + 4 rudi domain-internal) + 16 USV/rudi views absorbed into existing domains + ~290 integration base-table views shipped as AlloyDB schema (no API).

---

## C. Domain detail

### 1. `OrderStatus` — Sales Orders & Order Status

**Scope**: Read-side queries for sales orders, order status detail/summary, backorders, holds, web order numbers, wave status. The single largest read domain.

**Source procs (canonical)**: `spGetSalesOrder*` (10), `spOrderStatusDetail` (collapse `v3`–`v15`), `spOrderStatusDetailTracking`, `spOrderStatusSummary`, `USVOrderStatusSummaryByInvoiceAccount(AndDateRange)`, `spBackorderSummary` (collapse `V2`/`V3`), `spGetExpiringBackOrders`, `spCheckSalesOrderHold`, `spGetWebOrderNumbers`, `spGetSalesOrderByPO`, `spGetSalesOrderByWaveId`, `spGetWhsSalesLine`, `spGetOrderDetailBySO`, `spGetOrderDetailTestNew`, `ais.GetOrderDetailForDiscountTire`

**Endpoints**:


| Logical Op                                                                                               | HTTP | Endpoint                                   |
| -------------------------------------------------------------------------------------------------------- | ---- | ------------------------------------------ |
| Get sales orders (filters: customer, date range, sales origin, invoice numbers, accounts list, PO, wave) | GET  | `/sales-orders`                            |
| Get sales order detail by SalesId                                                                        | GET  | `/sales-orders/{salesId}`                  |
| Order status detail (filters: customer, status, dates, warehouse)                                        | GET  | `/order-status/detail`                     |
| Order status summary (filters: customer, order type, status, warehouse, top N)                           | GET  | `/order-status/summary`                    |
| Order status summary by invoice account (with optional date range)                                       | GET  | `/order-status/summary/by-invoice-account` |
| Backorder summary                                                                                        | GET  | `/backorders/summary`                      |
| Expiring backorders                                                                                      | GET  | `/backorders/expiring`                     |
| Sales-order hold check                                                                                   | GET  | `/sales-orders/{salesId}/hold`             |
| Tracking detail                                                                                          | GET  | `/order-status/{salesId}/tracking`         |


**Additional sources from `integration-idb`** (consolidated into the endpoints above):

- `dbo.USVOrderStatusDetail(@CustAccount, @OrderNumber, @OrderType, @OrderStatus, @InvoiceNumber, @Warehouse, @PONumber)` — **duplicate of `ais.spOrderStatusDetail*`**, identical contract → `/order-status/detail`
- `dbo.USVOrderStatusSummary(@CustAccount, @OrderType, @OrderStatus, @Warehouse, @NumberOfRecords)` — **duplicate of `ais.spOrderStatusSummary`** → `/order-status/summary`
- `dbo.USVOrderStatusSummaryByInvoiceAccount(@InvoiceAccount, @OrderType, @OrderStatus, @Warehouse, @NumberOfRecords)` — **duplicate** of the ais variant → `/order-status/summary/by-invoice-account`
- `dbo.USVCancelledOrderDetail(@CustAccount, @OrderNumber)` — **new endpoint**: `GET /order-status/cancelled/{salesId}` (filters: customer, order number)

**Depends on**: Customer, Warehouse, Invoice.

---

### 2. `Invoice` — Invoice Read & Lookup

**Scope**: Invoice retrieval by various keys, metadata, journal markups, FedEx invoice data, remainder calculations, line-code detail, summary roll-ups.

**Source procs**: `spGetInvoiceData(*)`, `spGetInvoiceDataByOrderAcctAndPONumber`, `spGetInvoiceDataWithInvoiceNumberAndCustomerAccount`, `spGetInvoiceDataByVendor_*` (Michelin variants → vendor parameter), `spGetInvoiceMetaData`, `spGetInvoiceCount`, `spGetInvoiceJournalMarkups`, `spGetInvoiceRemainder` (collapse v2–v4), `spGetFedExInvoiceData`, `ais.AllInvoicesSummary`, `ais.GetInvoiceDetailsByLineCode`, `spGetInvoiceAccountByProgramIdAndAccountNumber`, `spGetInvoiceAccountByProgramIdItemNumberAndCustomerAccount`, `spGetSalesOrdersByInvoiceNumbers` (cross-cuts OrderStatus — kept here for the invoice→SO direction)

**Endpoints**:


| Logical Op                                                                                                                 | HTTP | Endpoint                                   |
| -------------------------------------------------------------------------------------------------------------------------- | ---- | ------------------------------------------ |
| Search invoices (filters: invoice account, vendor, PO, invoice number, customer account, date range, vendor-discriminator) | GET  | `/invoices`                                |
| Get invoice metadata by id                                                                                                 | GET  | `/invoices/{invoiceId}`                    |
| Get invoice line details by line code                                                                                      | GET  | `/invoices/{invoiceId}/lines/by-line-code` |
| Invoice count (filters)                                                                                                    | GET  | `/invoices/count`                          |
| Invoice journal markups                                                                                                    | GET  | `/invoices/{invoiceId}/markups`            |
| Invoice remainder                                                                                                          | GET  | `/invoices/{invoiceId}/remainder`          |
| All invoices summary (date range)                                                                                          | GET  | `/invoices/summary`                        |
| Resolve invoice account from program + account (and optional item)                                                         | GET  | `/invoices/account-resolution`             |
| FedEx-format export                                                                                                        | GET  | `/invoices/fedex-export`                   |


**Additional sources from `rudi-idb`** (consolidated):

- `rudi.GetInvoicePostedDate(@InvoiceType nvarchar(2)/* AR/AP/CC */, @PostedDateInput rudi.PostedDateInputTableType READONLY)` — **new endpoint**: `POST /invoices/posted-dates` (body carries the TVP — invoice type + list of invoice keys; returns posted-date per row)

**Depends on**: Customer, Product, Program.

---

### 3. `InvoiceMatching` — RWA Invoice Matching (returns processing)

**Scope**: The Returns Work-Ahead matching engine. Most complex logic in the codebase — return-reason resolution, program-rule eligibility, IBS path vs. non-IBS path, fractional quantity handling, discontinue/acquisition overrides, misc-charge inclusion. Kept separate from `Invoice` because it's a transactional decision engine, not lookup.

**Source procs**: `spRWAInvoiceMatchingService` (collapse v2–v9 + IBS variants — confirm latest), `spRWAInvoiceData` (collapse v2–v9 + IBS variants), `spRWAGetReturnOrderData`, `spRWAReturnReasonType`, `spRWAItemsByItemGroup`, `spRWADeliveryModesForAccount`

**Endpoints**:


| Logical Op                                 | HTTP | Endpoint                                                   |
| ------------------------------------------ | ---- | ---------------------------------------------------------- |
| Match candidate invoice for a return claim | POST | `/invoice-matching/match`                                  |
| Fetch RWA invoice data for a claim context | GET  | `/invoice-matching/invoice-data`                           |
| Get return order data                      | GET  | `/invoice-matching/return-orders/{returnId}`               |
| Lookup return reason types                 | GET  | `/invoice-matching/return-reason-types`                    |
| Items by item group                        | GET  | `/invoice-matching/items/by-item-group/{groupId}`          |
| Delivery modes available for account       | GET  | `/invoice-matching/delivery-modes/by-account/{accountNum}` |


**Additional join inputs from `integration-idb`** (joined inside repository SQL, not exposed as endpoints):

- `dbo.usvibsinvoicematchdata` view — IBS-path matching data feed
- `dbo.usvreturnsparameters` view — returns-engine config table
- `dbo.usvwarrantyclaimtable` view — warranty-related returns enrichment

**POST for matching** because it's a stateful evaluation, not a query. Depends on Program, Product, Customer, Vendor, Warehouse.

---

### 4. `PurchaseOrder` — POs (read + EDI-side create-prep)

**Scope**: PO lookup, duplicate-PO checks, PO line data prep for downstream systems, format validation, supplier-on-order.

**Source procs**: `spPurchaseOrderLookupByPO`, `spGetPurchaseOrderDetails`, `spDuplicatePoCheck`, `spGetDuplicatePoCheckForSegmentID`, `spEDIPurchOrderCreateDetails`, `spGetPOFormatValidationForCustomer`, `spGetPOLineDataForBoomi`, `spGetSupplierOnOrderByVendorId`, `spTPNADuplicateCheck` (TPNA-specific dup check — placed here as it's a PO-keyed dedup)

**Endpoints**:


| Logical Op                                                                      | HTTP | Endpoint                                               |
| ------------------------------------------------------------------------------- | ---- | ------------------------------------------------------ |
| Get PO details by PO number                                                     | GET  | `/purchase-orders/{poNumber}`                          |
| Check for duplicate PO (filters: customer, segment, item, optional time window) | GET  | `/purchase-orders/duplicate-check`                     |
| Build EDI PO line payload                                                       | GET  | `/purchase-orders/{poNumber}/edi-line-data`            |
| PO format validation for customer                                               | GET  | `/purchase-orders/format-validation/{customerAccount}` |
| Boomi-shaped PO line export                                                     | GET  | `/purchase-orders/{poNumber}/boomi-export`             |
| Supplier-on-order by vendor                                                     | GET  | `/purchase-orders/supplier-on-order/{vendorId}`        |


---

### 5. `TransferOrder` — Inter-warehouse transfers & vendor returns

**Scope**: Small domain. Transfer order detail and transport notes, vendor-return order details.

**Source procs**: `spGetTransferOrderDetails`, `spGetTransferOrderTransportNote`, `spGetVendorReturnOrderDeatils` *(typo in original)*

**Endpoints**:


| Logical Op                        | HTTP | Endpoint                                       |
| --------------------------------- | ---- | ---------------------------------------------- |
| Get transfer order detail         | GET  | `/transfer-orders/{transferId}`                |
| Get transfer order transport note | GET  | `/transfer-orders/{transferId}/transport-note` |
| Get vendor return order details   | GET  | `/vendor-return-orders/{returnId}`             |


**Additional join inputs from `integration-idb`** (referenced inside repository SQL, not exposed as endpoints):

- `dbo.usvwarehousetransfersupplywarehouse` view — supply-warehouse-by-transfer mapping

Could be folded into `OrderStatus` to reduce domain count — recommend keeping separate; transfer orders have a distinct state machine.

---

### 6. `Customer` — Customer/Account Master & Cross-References

**Scope**: Customer master pulls, account info by various IBS/Nav/Invoice/Org keys, child accounts, customer→store-code cross-refs (Discount Tire, Tire Rack, Tire Rack TW, Mavis, Cust generic), 1P customer exports, postal addresses.

**Source procs**: `spCustomerLookup`, `spCustomerLookupByCustomerRef`, `spCustomerLookupByCustomerRefAndGroup`, `spGetAccountInfo*` (~12 — by IBS, by Nav, by InvoiceAccount, by InvoiceAccount+OrgNum, by AccountNum, by AMI dealer code, by Like-CustomerID-for-Like-Program, etc.), `spGetCustomersByCreatedDateTime`, `spGetCustomersByProgramId`, `spGetCustomerDataFor1P`, `spGetCreditCardCustomers`, `spGetChildAccountsByInvoiceAccountAndAccountNum`, `spGetCustomerRefByProgramAndAccount`, `spGetCustStoreCodeXRefs`, `spGetDiscountTireStoreCodeXRefs`, `spGetTireRackStoreCodeXRefs`, `spGetTireRackTWStoreCodeXRefs`, `spGetMavisAccountsByIBSAccountNum`, `spGetPostalAddressByRole`, `spGetPrimaryPostalAddress`, `spCCSurchargeProgramLookup`

**Endpoints**:


| Logical Op                                                                                                                                   | HTTP | Endpoint                                       |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------------------------------------------- |
| Search customers (filters: ref, ref+group, AMI dealer code, like-program)                                                                    | GET  | `/customers`                                   |
| Account info lookup (filters: IBS#, Nav#, AccountNum, InvoiceAccount, InvoiceAccount+OrgNum, IBSAccount+OrgNum, InvoiceAccounts list+OrgNum) | GET  | `/customers/account-info`                      |
| Customers created since timestamp                                                                                                            | GET  | `/customers/created-since`                     |
| Customers by program                                                                                                                         | GET  | `/customers/by-program/{programId}`            |
| 1P customer export                                                                                                                           | GET  | `/customers/1p-export`                         |
| Credit card customers                                                                                                                        | GET  | `/customers/credit-card`                       |
| Child accounts                                                                                                                               | GET  | `/customers/{invoiceAccount}/children`         |
| Customer ref by program + account                                                                                                            | GET  | `/customers/customer-ref`                      |
| Store-code cross-references (filters: source = `cust`/`discount-tire`/`tire-rack`/`tire-rack-tw`)                                            | GET  | `/customers/store-code-xrefs`                  |
| Postal address — primary                                                                                                                     | GET  | `/customers/{accountNum}/addresses/primary`    |
| Postal address — by role                                                                                                                     | GET  | `/customers/{accountNum}/addresses/by-role`    |
| CC surcharge program lookup                                                                                                                  | GET  | `/customers/{accountNum}/cc-surcharge-program` |


**Additional sources from `integration-idb`** (consolidated into `/customers`):

- `dbo.USVCustomerLookup(@CustomerRef)` — **duplicate of `ais.spCustomerLookup`** → `/customers?customerRef=...`
- `dbo.USVCustomerLookupByCustRefAndGroup(@CustomerRef, @ProgramGroup)` — **duplicate of `ais.spCustomerLookupByCustomerRefAndGroup`** → `/customers?customerRef=...&programGroup=...`
- `dbo.USVCustomerLookupByOrgNumAndSegment(@OrgNum, @SegmentId)` — **new filter combo** → `/customers?orgNum=...&segmentId=...`
- `dbo.USVCustomerLookupByAltOrgNum(@OrgNum, @AltOrgNum, @SegmentId)` — **new filter combo** → `/customers?orgNum=...&altOrgNum=...&segmentId=...`

**Additional join inputs from `integration-idb`** (joined inside repository SQL, not exposed as endpoints):

- `dbo.USVAISCustomerLookupByOrgNumSegmentStagingView` — staging view for the org-num lookups above
- `dbo.usvcustavailcredit` — customer available credit (also surfaced via Finance)
- `dbo.USVCUSTOMERRESPONSIBILITIESEMPLENTITY` — customer-responsibility-employee mapping (used by Salesforce flows too)
- `dbo.USVDIRPARTYCONTACTV3ENTITY`, `dbo.USVDIRPARTYPOSTALADDRESSSTAGINGVIEW`, `dbo.USVLOGISTICSCONTACTINFOSTAGINGVIEW`, `dbo.USVLOGISTICSPOSTALADDRESSSTAGINGVIEW`, `dbo.USVLOGISTICSPOSTALADDRESSENTITY` — party/contact/address staging views feeding the `/customers/.../addresses/*` endpoints
- `dbo.vwDimCustomerContacts` — dimensional customer-contact rollup

**Additional sources from `rudi-idb`** (consolidated into `/customers`):

- `rudi.GetAllInactiveCustomerAccounts(@Company)` — **new endpoint**: `GET /customers/inactive?legalEntity={Company}`
- `rudi.GetCustomerAccountAvailableCredit(@Company, @CustomerAccount)` — **new endpoint**: `GET /customers/{accountNum}/available-credit?legalEntity={Company}` (also referenced from Finance)

Most heavily consolidated domain — ~25 ais procs + 4 integration procs + 2 rudi procs collapse into ~15 endpoints driven by parameter unions.

---

### 7. `Vendor` — Vendor Master & Vendor-side Lookups

**Scope**: Vendor master fetch, vendor item/PO/MFG3 lookups, payment terms, vendor warehouse external codes, "your account number" reverse-resolution, commission codes, vendor loyalty return reason codes.

**Source procs**: `spFindVendorMFG3CodeForAccount`, `spFindVendorWithIBSAccount`, `spGetYourAccountNumForVendor`, `spGetPaymentTermsByVendorAccount`, `spGetVendorWarehouseExternalCodes`, `spVendorExternalCodeLookupByCodeClassId`, `sp810InboundLookupVendorCommissionCode`, `sp810InboundLookupItemNumberForVendor`, `sp810InboundGetVendorItemForPoNumberAndItemId`, `ais.VendorLoyaltyReturnReasonCodes`, `spGetWDNonSig`

**Endpoints**:


| Logical Op                                                                 | HTTP | Endpoint                                            |
| -------------------------------------------------------------------------- | ---- | --------------------------------------------------- |
| Find vendor (filters: IBS account, MFG3 code)                              | GET  | `/vendors`                                          |
| Get "your account number" for vendor                                       | GET  | `/vendors/{vendorAccount}/your-account-number`      |
| Payment terms                                                              | GET  | `/vendors/{vendorAccount}/payment-terms`            |
| Warehouse external codes                                                   | GET  | `/vendors/{vendorAccount}/warehouse-external-codes` |
| External code lookup by class id                                           | GET  | `/vendors/external-codes/{codeClassId}`             |
| Vendor commission code                                                     | GET  | `/vendors/{vendorAccount}/commission-code`          |
| Vendor item lookup (filters: item id, PO+item)                             | GET  | `/vendors/{vendorAccount}/items`                    |
| Vendor loyalty return reason codes                                         | GET  | `/vendors/loyalty-return-reason-codes`              |
| WD non-signatory account (currently hardcoded — flag for parameterization) | GET  | `/vendors/wd-non-signatory`                         |


**Additional sources from `rudi-idb`** (consolidated into Vendor; all pass `@Company` as `legalEntity`):

- `rudi.GetVendorDetails(@Company, @CustomerAccount /* note: param mis-named, actually vendor account */)` — **new endpoint**: `GET /vendors/{vendorAccount}` (canonical vendor master record by company + account)
- `rudi.GetVendorBlockedStatus(@Company, @VendorAccount)` — **new endpoint**: `GET /vendors/{vendorAccount}/blocked-status`
- `rudi.GetVendorPaymentMethod(@Company, @VendorAccount)` — **new endpoint**: `GET /vendors/{vendorAccount}/payment-method`
- `rudi.GetVendorDefaultBankAccount(@DataAreaID, @AccountNum)` — **new endpoint**: `GET /vendors/{vendorAccount}/bank-account/default?legalEntity={DataAreaID}`

`rudi.GetVendorRemainingBalance` lives in **Finance** (#18) since it's a balance-rollup query, not a vendor-master lookup.

**Additional join inputs from `integration-idb`** (joined inside repository SQL, not exposed):

- `dbo.usvsalescommissionresptable` — sales-commission responsibility mapping
- `dbo.VENDVENDOREXTERNALCODEENTITY` — vendor external-code entity (also feeds `external-codes` endpoint)
- `dbo.usvvendorcredittable`, `dbo.usvvendorcreditline`, `dbo.usvvendorcreditreturntable`, `dbo.usvvendorcreditreturnline`, `dbo.USVVENDORCREDITRETURNHEADERLINESENTITY` — vendor-credit/return-line views (also referenced by InvoiceMatching for return processing)

Note `spGetWDNonSig` hardcodes vendor `'100687'` — surface this as a config-driven endpoint.

---

### 8. `VendorProgram` — SSP / TPNA / CMP / Sellout / DirectSales

**Scope**: Vendor program reporting & claim data — the quarterly/monthly extracts vendors consume. Highly parameterized per vendor; strong overlap in shape but different join paths.

**Source procs**:

- **SSP**: `spGetSSPDataByVendorAccount(*)`, `spGetSSPDataByVendorAccountForEDI`, `spGetSSPDataByVendorAccountAndInvoiceIDListForEDI`, `spGetSSPItemsByAccountNumber(AndItemId)`, `spGetSSPReturnDataByVendorAccount(ForEDI)`, `spGetSSPAccountsFor1P`, `spLookupSspClaimNumberExists`
- **TPNA**: `spGetTPNAData`, `spGetTPNAHistory`, `spGetMigratedTPNAHistory`, `spGetTPNAEligibilityByAccountNumber`, `spGetTPNAProgramsByVendAccount`, `spGetTPNASSPDataByVendorAccount(ForEDI)`, `spGetTPNAVendorAccountByCustomerAccount`, `sp810InboundGetTPNAData`, `spLookupTPNAClaimNumberExists`
- **CMP**: `spGetCMPDataByVendorAccount(*)`, `spGetCMPReturnDataByVendorAccount`, `spGetCMPDataForFordLubes` (vendor variant)
- **Sellout**: `spGetSelloutDataBridgestone` (vendor variant)
- **DirectSales**: `spGetDirectSalesDataByCat3`, `spGetDirectSalesDataByCat4`, `spGetDirectSalesDataByVendor`, `spGetDirectSales_GoodyearEnduranceTrailer` (vendor variant)

**Endpoints** (program-typed sub-resources):


| Logical Op                                                                   | HTTP | Endpoint                                                             |
| ---------------------------------------------------------------------------- | ---- | -------------------------------------------------------------------- |
| SSP data (filters: vendor, dealer, dates, invoice-id list, EDI mode)         | GET  | `/vendor-programs/ssp/data`                                          |
| SSP items (filters: account, item)                                           | GET  | `/vendor-programs/ssp/items`                                         |
| SSP return data (filters: vendor, EDI mode)                                  | GET  | `/vendor-programs/ssp/returns`                                       |
| SSP claim-number exists                                                      | GET  | `/vendor-programs/ssp/claims/{claimNumber}/exists`                   |
| SSP 1P account export                                                        | GET  | `/vendor-programs/ssp/accounts/1p-export`                            |
| TPNA data (filters: vendor, dates)                                           | GET  | `/vendor-programs/tpna/data`                                         |
| TPNA history (filters: include migrated)                                     | GET  | `/vendor-programs/tpna/history`                                      |
| TPNA eligibility                                                             | GET  | `/vendor-programs/tpna/eligibility/{accountNumber}`                  |
| TPNA programs by vendor                                                      | GET  | `/vendor-programs/tpna/programs/{vendorAccount}`                     |
| TPNA SSP data (filters: vendor, EDI mode)                                    | GET  | `/vendor-programs/tpna/ssp-data`                                     |
| TPNA vendor account by customer account                                      | GET  | `/vendor-programs/tpna/vendor-account-by-customer/{customerAccount}` |
| TPNA claim-number exists                                                     | GET  | `/vendor-programs/tpna/claims/{claimNumber}/exists`                  |
| CMP data (filters: vendor, dates, vendor-discriminator e.g. `ford-lubes`)    | GET  | `/vendor-programs/cmp/data`                                          |
| CMP return data                                                              | GET  | `/vendor-programs/cmp/returns`                                       |
| Sellout data (filters: vendor required)                                      | GET  | `/vendor-programs/sellout/data`                                      |
| Direct sales (filters: vendor, category-3, category-4, vendor-discriminator) | GET  | `/vendor-programs/direct-sales`                                      |


**Additional join inputs from `integration-idb`** (joined inside repository SQL, not exposed as endpoints):

- `dbo.usvsspprogramcustomer` — SSP program-customer mapping (drives `/ssp/data`, `/ssp/accounts/1p-export`)
- `dbo.usvsspprogramproducts` — SSP program-product mapping (drives `/ssp/items`)
- `dbo.usvtpnaonlinecusteligibility` — TPNA online eligibility table (drives `/tpna/eligibility/{accountNumber}`)
- `dbo.usvtpnaonlinedeliveryreceiptreturnheader`, `dbo.usvtpnaonlinedeliveryreceiptreturnline`, `dbo.usvtpnaonlinedeliveryreceiptvendornumseq` — TPNA delivery-receipt-return tables (drive `/tpna/data`, `/tpna/history`)

Second-largest domain (~30 procs → ~16 endpoints). Candidate to split if it grows: `VendorProgram.Ssp`, `VendorProgram.Tpna`, `VendorProgram.Cmp`. For Phase-2 v1 keep as one bounded context.

---

### 9. `Product` — Items, Tires, Attributes, Pricing

**Scope**: Product attribute search, tire details, item barcodes, item groups, customer product-number resolution, core/MAP/price-group pricing, brand catalog, price-group ↔ item mapping, 1P product export, ratings, inclusions/exclusions, Goodyear-Cooper part xref.

**Source procs**: `spGetProductAttibutes` (typo preserved), `spGetAllProductAttributes`, `spGetAllProductExclusionsByWarehouse`, `spGetExclusionsByAccountNumber`, `spGetProductGroupExclusionsByAccountNumber`, `spGetAllInclusions`, `spGetAllItemGroups`, `spGetItemBarcodes`, `spFindCustomerProductNumber`, `spGetTireDetailsByItemId`, `spGetTireProgramsWithFees`, `spGetCorePrices`, `spGetMapPrices`, `spGetCatalogCodes`, `spGetBrandsFromProductAttributes`, `spGetPriceGroupFromProductAttributes(*)`, `spGetPriceGroupAndBrandCodesFromProductAttributes`, `spGetPriceGroupAndMarketingLineFromProductAttributes`, `spGetPriceGroupItemIdFromProductAttributes`, `spGetProductAttributeItemsForPriceGroup(List)`, `spGetProductAttributesFor1P`, `spGetProductDetailsFor1P`, `spGetGoodyearCooperPartNumber`, `spGetRequireRating`, `spGetItemIdsAndWarehouses`, `ais.v_ecoresinstancevalue` (legacy product hierarchy view — exposed as ref-data endpoint)

**Endpoints**:


| Logical Op                                                                            | HTTP | Endpoint                            |
| ------------------------------------------------------------------------------------- | ---- | ----------------------------------- |
| Search product attributes (filters: brand, price-group, marketing-line, catalog-code) | GET  | `/products/attributes`              |
| Items by price group (single or list)                                                 | GET  | `/products/price-groups/items`      |
| Get tire detail                                                                       | GET  | `/products/tires/{itemId}`          |
| Tire programs with fees                                                               | GET  | `/products/tires/programs`          |
| Item barcodes                                                                         | GET  | `/products/{itemId}/barcodes`       |
| Customer product number resolution                                                    | GET  | `/products/customer-product-number` |
| Core prices                                                                           | GET  | `/products/prices/core`             |
| MAP prices                                                                            | GET  | `/products/prices/map`              |
| Brands from product attributes                                                        | GET  | `/products/brands`                  |
| Catalog codes                                                                         | GET  | `/products/catalog-codes`           |
| Item groups                                                                           | GET  | `/products/item-groups`             |
| Item-id ↔ warehouse map                                                               | GET  | `/products/item-warehouses`         |
| Inclusions (all)                                                                      | GET  | `/products/inclusions`              |
| Exclusions (filters: by account, by warehouse, by product-group+account)              | GET  | `/products/exclusions`              |
| Goodyear-Cooper part xref                                                             | GET  | `/products/goodyear-cooper-xref`    |
| Require-rating flag                                                                   | GET  | `/products/{itemId}/require-rating` |
| 1P product export                                                                     | GET  | `/products/1p-export`               |
| 1P product attributes export                                                          | GET  | `/products/attributes/1p-export`    |
| EcoRes instance values (legacy ref view)                                              | GET  | `/products/ecores-instance-values`  |


**Additional join inputs from `integration-idb`** (joined inside repository SQL, not exposed):

- `dbo.usvecoresprodtiresattributes`, `dbo.usvecoresprodtiresattributesext`, `dbo.usvecoresprodtiresaccessoriesattributes`, `dbo.usvecoresprodtubesattributes`, `dbo.usvecoresprodlubeschemicalattributes`, `dbo.usvecoresprodpartsattributes`, `dbo.usvecoresprodexhuastattributes`, `dbo.usvecoresprodmicsitemsattributes` — category-specific EcoRes attribute projections (drive `/products/attributes`, `/products/tires/...`)
- `dbo.usvfndcategory` — foundation-category lookup
- `dbo.usvitemchargestable` — item-level charges (cross-cuts Invoice)
- `dbo.usvproductexclusionbywhs` — product-by-warehouse exclusion
- `dbo.usvproductfirstreceiptdate` — first-receipt-date enrichment

---

### 10. `Program` — USV Program Rules & Eligibility

**Scope**: USV program metadata, eligibility/rule evaluation (program reason-code rules, item-on-program checks), program→customer/account rollups, campaign metadata.

**Source procs**: `spFindWithInProgramRule`, `spItemOnProgram`, `spGetAllProgramItemsForAccount`, `spGetAccountsForProgram`, `spGetProgramIdByItemId`, `spGetProgramsByRelatedProgramIdAndCustomerAccount`, `spGetProgramCustomerAccountsForVendor`, `spGetCampaignEndDateByCampaignId`, `spGetIgnoreReturnsPORequirement`, `spGetCCSurchargeProgramLookup` (lives between Program & Customer — placing here)

**Endpoints**:


| Logical Op                                                                                  | HTTP | Endpoint                                                      |
| ------------------------------------------------------------------------------------------- | ---- | ------------------------------------------------------------- |
| Evaluate within-program rule (reason code + customer + invoice date + claim date + program) | POST | `/programs/rules/within-program/evaluate`                     |
| Check item on program                                                                       | GET  | `/programs/{programId}/items/{itemId}`                        |
| All items on program for account                                                            | GET  | `/programs/{programId}/items/by-account/{accountNum}`         |
| Accounts on program                                                                         | GET  | `/programs/{programId}/accounts`                              |
| Program by item                                                                             | GET  | `/programs/by-item/{itemId}`                                  |
| Programs by related-program + customer                                                      | GET  | `/programs/related`                                           |
| Programs available for vendor's customer accounts                                           | GET  | `/programs/by-vendor/{vendorAccount}`                         |
| Campaign end date                                                                           | GET  | `/programs/campaigns/{campaignId}/end-date`                   |
| Ignore-returns-PO-requirement flag (by reason code)                                         | GET  | `/programs/return-rules/ignore-po-requirement/{reasonCodeId}` |


POST on rule evaluation matches `InvoiceMatching` style — it's a decision call.

**Additional join inputs from `integration-idb`** (joined inside repository SQL, not exposed):

- `dbo.usvprogramtable`, `dbo.USVPROGRAMTABLEENTITY` — program master view (entity = staging-flavored)
- `dbo.usvprogramcustomer`, `dbo.USVPROGRAMCUSTOMERENTITY` — program-customer mapping
- `dbo.usvprogramproducts`, `dbo.USVPROGRAMPRODUCTSTABLEENTITY` — program-products mapping
- `dbo.usvprogramcustprodexclusiontable`, `dbo.USVPROGRAMCUSTPRODEXCLUSIONTABLEENTITY` — customer-product exclusion overrides
- `dbo.usvprogramreasoncode` — reason-code-to-program mapping (drives within-program rule evaluation)
- `dbo.usvexclusionprogramcustomerproducts` — combined exclusion view
- `dbo.usvacquisitiontable` — acquisition-program lookup (drives program override logic)

**Additional data-quality endpoints from `integration-idb` views** (operational visibility, not consumer-facing):

- `dbo.vDuplicatePrograms`, `dbo.vProgramsWithNoItems`, `dbo.vProgramTablesWithZeroRecords` — surface as `GET /programs/data-quality/{check}` (single endpoint with `check` discriminator: `duplicates`/`no-items`/`zero-records`)

---

### 11. `Warehouse` — Warehouse / Inventory Location Master

**Scope**: Warehouse list, primary/secondary/backup warehouses for an account, IBS-warehouse predicate, location data, vendor warehouse external codes (cross-cuts Vendor — kept there).

**Source procs**: `spGetWarehouseList`, `spGetWarehouseListForAccount`, `spGetWarehouseByAccountInfo(AndWarehouseId|ForGoodYearReplenish)`, `spGetWarehouseForAccountAndPurchId`, `spGetPrimaryWarehouseByCustomerAccount`, `spGetSecondaryWarehouses`, `spGetWarehouseBackups`, `spGetWarehouseBackupsFromPrimaryWarehouse`, `spFindWarehouseData`, `spIsIBSWarehouse`, `spWarehouseLocationData`, `spGetInventLocationRecord`, `spGetWarehouseCodesForPartner`

**Endpoints**:


| Logical Op                                                                                                 | HTTP | Endpoint                                   |
| ---------------------------------------------------------------------------------------------------------- | ---- | ------------------------------------------ |
| List warehouses (filters: account, partner)                                                                | GET  | `/warehouses`                              |
| Get warehouse data (filters: account, account+warehouse-id, account+purch-id, replenish-mode = `goodyear`) | GET  | `/warehouses/by-account`                   |
| Primary warehouse for customer                                                                             | GET  | `/warehouses/primary/{customerAccount}`    |
| Secondary warehouses for customer                                                                          | GET  | `/warehouses/secondary/{customerAccount}`  |
| Backups (filters: by account, by primary-warehouse)                                                        | GET  | `/warehouses/backups`                      |
| IBS warehouse predicate                                                                                    | GET  | `/warehouses/{warehouseId}/is-ibs`         |
| Warehouse location detail                                                                                  | GET  | `/warehouses/{warehouseId}/location`       |
| InventLocation record                                                                                      | GET  | `/warehouses/invent-location/{locationId}` |


**Additional sources from `integration-idb`** (consolidated into `/warehouses`):

- `dbo.USVGetAllWarehouseData()` — **new endpoint**: `GET /warehouses/all-with-address` (returns warehouse + address + phone, no params)
- `dbo.USVGetWarehouseDataByExternalCode(@ExternalWarehouseCode)` — **new endpoint**: `GET /warehouses/by-external-code/{externalCode}`

**Additional join inputs from `integration-idb`** (joined inside repository SQL, not exposed):

- `dbo.usvwarehousepostaladdress` — warehouse postal-address rollup (drives `/warehouses/{warehouseId}/location` and `/warehouses/all-with-address`)

---

### 12. `EdiInbound` — 810 Inbound (vendor invoices) + Distro dedup

**Scope**: Inbound EDI 810 processing — duplicate checks across `3Way`/`Misc`/`PassThru`/`Ssp`/`Tpna` modes, invoice-existence pre-check, customer-ref-for-program lookup, bank account fetch, distro-message dedup.

**Source procs**: `sp810InboundCheckForDuplicate3Way`, `sp810InboundCheckForDuplicateMisc`, `sp810InboundCheckForDuplicatePassThru`, `sp810InboundCheckForDuplicateSsp`, `sp810InboundCheckForDuplicateTpna`, `sp810InboundLookupInvoiceExists`, `sp810InboundLookupCustomerRefForProgram`, `sp810GetAccountBankData`, `spCheckForRecentDistroDuplicateMessage`, `spGetTradingPartnerCrossRefFor810`

**Endpoints**:


| Logical Op                                                                            | HTTP | Endpoint                                  |
| ------------------------------------------------------------------------------------- | ---- | ----------------------------------------- |
| 810 duplicate check (filters: mode = `3way`/`misc`/`passthru`/`ssp`/`tpna` + payload) | POST | `/edi/inbound/810/duplicate-check`        |
| 810 invoice-exists                                                                    | GET  | `/edi/inbound/810/invoice-exists`         |
| 810 customer-ref for program                                                          | GET  | `/edi/inbound/810/customer-ref`           |
| 810 account bank data                                                                 | GET  | `/edi/inbound/810/bank-data/{accountNum}` |
| Trading partner xref for 810                                                          | GET  | `/edi/inbound/810/trading-partners`       |
| Distro recent-duplicate check (filters: msgId, dupe-window-mins)                      | GET  | `/edi/inbound/distro/duplicate-check`     |


POST for duplicate-check because the request carries enough payload that GET is awkward, and the call has integration-side significance.

**Additional join inputs from `integration-idb`** (joined inside repository SQL, not exposed):

- `dbo.usvtpnabatchduplicatetable` — TPNA batch-duplicate detection table (drives the `tpna` mode of `/edi/inbound/810/duplicate-check`)

---

### 13. `EdiOutbound` — 810/850/855/856 Outbound

**Scope**: Outbound EDI payload assembly. Each transaction set has 1–4 lookup procs that pull the data needed to build the EDI document.

**Source procs**:

- **810 out**: `sp810OutboundLookupBySalesId`, `sp810OutboundLookupMarkupsBySalesId`, `sp810OutboundLookupRestockFeesBySalesId`
- **850 out**: `sp850OutboundLookupByAccountAndDate`, `sp850OutboundLookupByPONumbers`, `sp850OutboundLookupBySalesId`, `sp850OutboundLookupBySalesIDList`
- **855 out**: `sp855OutboundLookupBySalesId`, `sp855OutboundLookupConfirmDocNum`, `sp855OutboundLookupInvoiceAccountBySalesId`
- **856 out**: `sp856OutboundLookupBySalesId`, `sp856OutboundCombinedASNLookupBySalesId`

**Endpoints** (transaction-set-typed sub-resources):


| Logical Op                                                              | HTTP | Endpoint                                      |
| ----------------------------------------------------------------------- | ---- | --------------------------------------------- |
| 810 outbound payload (filters: include-markups, include-restock-fees)   | GET  | `/edi/outbound/810/{salesId}`                 |
| 850 outbound (filters: salesId, salesId-list, PO-numbers, account+date) | GET  | `/edi/outbound/850`                           |
| 855 outbound                                                            | GET  | `/edi/outbound/855/{salesId}`                 |
| 855 confirm doc num                                                     | GET  | `/edi/outbound/855/{salesId}/confirm-doc-num` |
| 855 invoice account                                                     | GET  | `/edi/outbound/855/{salesId}/invoice-account` |
| 856 outbound (filters: combined-asn)                                    | GET  | `/edi/outbound/856/{salesId}`                 |


---

### 14. `Delivery` — Delivery Modes, Receipts, Tracking

**Scope**: Delivery modes globally and by account, vendor-specific delivery receipts (Continental, Pirelli, Yokohama), Goodyear eCom freight tracking, FedEx/tracking-number lookup, master route code lookup, truck route names.

**Source procs**: `spGetDeliveryModes`, `spRWADeliveryModesForAccount` *(also referenced in InvoiceMatching — canonical home is Delivery; InvoiceMatching consumers should call this API)*, `spGetContinentalDeliveryReceipts`, `spGetPirelliDeliveryReceipts`, `spGetYokohamaDeliveryReceipts`, `spGetGoodyearEComFreightTracking`, `spFindTrackingNum`, `spGetMasterRouteCodeFromRouteId`, `spGetTruckRouteNamesForAccounts`

**Endpoints**:


| Logical Op                                                                              | HTTP | Endpoint                                   |
| --------------------------------------------------------------------------------------- | ---- | ------------------------------------------ |
| List delivery modes                                                                     | GET  | `/delivery/modes`                          |
| Delivery modes for account                                                              | GET  | `/delivery/modes/by-account/{accountNum}`  |
| Vendor delivery receipts (filters: vendor = `continental`/`pirelli`/`yokohama` + dates) | GET  | `/delivery/receipts`                       |
| Goodyear eCom freight tracking                                                          | GET  | `/delivery/freight-tracking/goodyear-ecom` |
| Find tracking number                                                                    | GET  | `/delivery/tracking`                       |
| Master route code from route id                                                         | GET  | `/delivery/routes/{routeId}/master-code`   |
| Truck route names for accounts                                                          | GET  | `/delivery/routes/truck-names`             |


**Additional sources from `integration-idb`** (consolidated into `/delivery`):

- `dbo.USVContinentalWarehouses(@CustomerAccount)` — Continental-vendor warehouse list for an account → folds into existing `/delivery/receipts?vendor=continental` flow OR surface as `GET /delivery/receipts/continental/warehouses-by-account/{accountNum}`. Recommend the latter (it's a warehouse-list, not a receipt feed).

**Additional sources from `rudi-idb`** (consolidated into `/delivery`):

- `rudi.GetAccountDeliverySettings(@Company, @CustomerAccount)` — **new endpoint**: `GET /delivery/customers/{accountNum}/settings?legalEntity={Company}` (returns delivery-mode + FTP/electronic-address settings — used by RUDI to drive print/email/EDI routing decisions)

**Additional join inputs from `integration-idb`** (joined inside repository SQL, not exposed):

- `dbo.usvroutetable`, `dbo.usvrouteline`, `dbo.usvroutedeliveryschedule`, `dbo.USVROUTETABLECUSTVIEW` — route master + line + schedule + customer-overlay views (drive `/delivery/routes/*`)
- `dbo.usvsalestrackingnumbers` — sales-order tracking-number rollup (drives `/delivery/tracking`)

---

### 15. `Routes` — ETA Schema (`eta.*`)

**Scope**: ETA route master & connectivity for transfer routing.

**Source procs**: `eta.spGetAllRoutes`, `eta.spGetAccountInfoWithAccountNum`, `eta.spGetConnectingWarehouses`, `eta.spGetCustomerTransferRoutesForWarehouse`, `eta.spGetRouteNamesForAccounts`, `eta.spGetRouteNamesForAccountsAndWarehouse`, `eta.spGetTransferRoutesForWarehouses`

**Endpoints**:


| Logical Op                                                           | HTTP | Endpoint                                          |
| -------------------------------------------------------------------- | ---- | ------------------------------------------------- |
| List all routes                                                      | GET  | `/eta/routes`                                     |
| Route names for accounts (filters: account list, optional warehouse) | GET  | `/eta/routes/names-by-account`                    |
| Connecting warehouses                                                | GET  | `/eta/warehouses/connecting`                      |
| Customer transfer routes for warehouse                               | GET  | `/eta/transfer-routes/by-warehouse/{warehouseId}` |
| Transfer routes for warehouses                                       | GET  | `/eta/transfer-routes`                            |
| Account info (eta-side)                                              | GET  | `/eta/customers/account-info`                     |


Lives in `eta` schema — separate API project per the USV Stack template. Note duplication of "account info" between `ais.spGetAccountInfoWithAccountNum` and `eta.spGetAccountInfoWithAccountNum` is intentional in legacy; recommend they remain separate APIs but flag for the data team to confirm field-level parity.

**Additional join inputs from `integration-idb`** (the `usvroute*` views above can be referenced from this domain too — the canonical home is Delivery; Routes consumers join to them via the API, not directly).

---

### 16. `Platform` — Azure Outbound / Queue Plumbing + Reference Data

**Scope**: Operational visibility into the Azure outbound integration table (the queue metadata layer that supports EDI/Boomi) plus pure reference data (holidays). Merged from earlier `Integration` + `ReferenceData` proposals — too small to warrant separate projects.

**Source procs**: `spGetAzureOutboundInfo`, `spGetAzureOutboundRequests`, `spGetAzureOutBoundRequestErrors`, `spGetAzureQueueErrors`, `spGetHolidays`

**Endpoints**:


| Logical Op                        | HTTP | Endpoint                               |
| --------------------------------- | ---- | -------------------------------------- |
| Azure outbound info               | GET  | `/integration/azure/outbound/info`     |
| Azure outbound requests (filters) | GET  | `/integration/azure/outbound/requests` |
| Azure outbound request errors     | GET  | `/integration/azure/outbound/errors`   |
| Azure queue errors                | GET  | `/integration/azure/queue/errors`      |
| Holidays list                     | GET  | `/reference/holidays`                  |


**Additional sources from `integration-idb`** (consolidated into `/integration/...`):

- `dbo.usvinboundqueuelog` view — **new endpoint**: `GET /integration/inbound/queue-log` (filters: queue name, date range, status — operational visibility into the inbound integration queue)
- `dbo.usvibsparameters` view — **new endpoint**: `GET /integration/ibs/parameters` (read-only IBS configuration snapshot)

---

### 17. `SalesforceIntegration` — Boomi/Salesforce sync surface (`boomi.*`)

**Project**: `Services.SalesforceIntegration.Api` (alternative names: `Services.BoomiSync.Api`, `Services.SalesforceSync.Api` — pick per team naming convention).

**Scope**: Read-only API exposing Salesforce-shaped projections of AX/D365 master data (customer, case, warehouse, employee responsible) plus the inventory-check default-warehouse lookup. All output uses Central Standard Time conversion to match Salesforce's storage convention.

**Source objects**:

- **Views (API-exposed)**: `SalesforceCustomerV2`, `SalesforceCaseDetail`, `SalesforceWarehouse`, `SalesforceEmployeeResponsible`, `FlexInventCheck_DefaultWarehouse`
- **Internal tables (queries join to them; not API-exposed)**: `SalesforceXrefCustomer`, `SalesforceXrefProgram`, `SalesforceXrefUser`

**Endpoints**:


| Logical Op                                                                                                    | HTTP | Endpoint                                          |
| ------------------------------------------------------------------------------------------------------------- | ---- | ------------------------------------------------- |
| Get Salesforce-shaped customer projections (filters: customer account, modified-since for delta-pull, paging) | GET  | `/salesforce/customers`                           |
| Get a single Salesforce customer projection                                                                   | GET  | `/salesforce/customers/{customerAccount}`         |
| Get Salesforce case detail (filters: case id, status, modified-since)                                         | GET  | `/salesforce/cases`                               |
| Get Salesforce warehouse projection (filters: warehouse id, modified-since)                                   | GET  | `/salesforce/warehouses`                          |
| Get employee-responsible mapping (filters: customer account, responsibility id)                               | GET  | `/salesforce/employee-responsible`                |
| Get default warehouse for customer (FlexInventCheck)                                                          | GET  | `/salesforce/flex-invent-check/default-warehouse` |


**Additional sources from `integration-idb`** (consolidated here):

- `dbo.vCustomerContactInfo_SalesForce` view — **new endpoint**: `GET /salesforce/customers/{customerAccount}/contacts` (Salesforce-shaped contact info for a customer; complement to `/salesforce/customers/{customerAccount}`)

**Note on xref tables**: `SalesforceXrefCustomer/Program/User` are joined to inside repository SQL but **not exposed via API**. Boomi continues to populate them by writing directly to AlloyDB using the existing wipe-and-reload pattern (truncate proc + bulk insert). Their DDL must be included in the AlloyDB schema migration; the truncate procs (`usp_Truncate_SalesforceXref*`) remain as DB objects for Boomi to call, but the API does not surface either the tables or the procs.

**Depends on**: nothing within Atlas. Could be deployed independently.

---

### 18. `Finance` *(new)* — AR exports, Esker integration, customer/vendor balances

**Project**: `Services.Finance.Api` (alternative names: `Services.Ar.Api`, `Services.ArIntegration.Api` — pick per team naming convention).

**Scope**: Read-only AR/AP/finance surface that didn't exist in the original ais plan but emerges naturally when integration's Esker procs and rudi's voucher/balance procs are consolidated. Covers Esker AR system feeds, Ventus cash-receipts extract, customer statements / available credit / open transactions, vendor remaining balance, voucher/invoice posted dates, financial dimensions, and outstanding firm-fixed collateral.

**Source procs/views**:

- **Esker outbound feeds** (`integration-idb`): `dbo.Esker_company_AF()`, `dbo.Esker_Contacts_AF(@startdate, @enddate)`, `dbo.Esker_OutsidePmts_AF(@startdate, @enddate)`, `dbo.Esker_WriteOff_AF(@startdate, @enddate)`
- **Ventus cash-receipts extract** (`integration-idb`): `dbo.USVExtractARVentus(@date)` — note hour-of-day branching logic (defaults to "yesterday before 5pm, today after")
- **Open AR rollups** (`integration-idb` views): `dbo.USVOpenAR`, `dbo.Esker_USVOpenAR`
- **Customer statements** (`integration-idb` views): `dbo.usvcuststatement`, `dbo.usvcustinvoicejourstatement`, `dbo.usvcustavailcredit`
- **PNC bank integration** (`integration-idb` view): `dbo.USVPNCCUSTTRANSDATAENTITY`
- **GL hierarchy** (`integration-idb` view): `dbo.usvgeneralledgerhierarchy`
- **Rudi finance** (`rudi-idb` procs): `rudi.GetVendorRemainingBalance(@D365Company, @MAINACCOUNT, @DEPARTMENT, @LOCATION, @CUSTOMER)`, `rudi.GetCustomerOpenTransactions(@Company, @CustomerAccount, @DueDateFrom, @DueDateTo)`, `rudi.GetVoucherPostedDate(@Company, @VoucherNumber)`, `rudi.GetFinancialDimensions(@Company)`
- **Rudi finance** (`rudi-idb` view): `rudi.OUTSTANDINGFIRMFIXEDCOLLATERALDETAIL`

**Endpoints**:


| Logical Op                                                                                | HTTP | Endpoint                                                                |
| ----------------------------------------------------------------------------------------- | ---- | ----------------------------------------------------------------------- |
| Esker company export (no params — full AR customer list)                                   | GET  | `/finance/esker/companies`                                              |
| Esker contacts export (filters: start, end)                                                | GET  | `/finance/esker/contacts`                                               |
| Esker outside-payments export (filters: start, end)                                        | GET  | `/finance/esker/outside-payments`                                       |
| Esker write-off export (filters: start, end)                                               | GET  | `/finance/esker/write-offs`                                             |
| Ventus AR cash-receipts extract (filters: date — default = yesterday-before-5pm logic)     | GET  | `/finance/ventus/ar-extract`                                            |
| Open AR (filters: scope = `default`/`esker`)                                               | GET  | `/finance/ar/open`                                                      |
| Customer statement (filters: invoice-jour vs. summary)                                     | GET  | `/finance/customers/{accountNum}/statement`                             |
| Customer available credit                                                                  | GET  | `/finance/customers/{accountNum}/available-credit?legalEntity=...`      |
| Customer open transactions (filters: due-date range)                                       | GET  | `/finance/customers/{accountNum}/open-transactions?legalEntity=...`     |
| PNC customer-transaction data (banking integration)                                        | GET  | `/finance/pnc/customer-transactions`                                    |
| GL hierarchy                                                                               | GET  | `/finance/gl/hierarchy`                                                 |
| Vendor remaining balance (filters: main-account, department, location, customer)           | GET  | `/finance/vendors/remaining-balance?legalEntity=...&mainAccount=...&...` |
| Voucher posted date                                                                        | GET  | `/finance/vouchers/{voucherNumber}/posted-date?legalEntity=...`         |
| Financial dimensions (all dimension types for a legal entity)                              | GET  | `/finance/dimensions?legalEntity=...`                                   |
| Outstanding firm-fixed collateral detail                                                   | GET  | `/finance/collateral/firm-fixed-outstanding`                            |

**Depends on**: Customer (resolves account → invoice account → org), Vendor (resolves vendor account). All endpoints accept `legalEntity` per cross-cutting §D.2.

**Read-only**. Esker procs return query result sets; the actual integration push is done by external Esker/Ventus connectors that call these endpoints and ship the rows downstream.

---

### 19. `RudiCompass` *(new)* — COMPASS reconciliation validation surface (`rudi.*`)

**Project**: `Services.RudiCompass.Api`.

**Scope**: A thin, RUDI-specific bounded context for the four `COMPASSValidate*` procs. These procs are validation lookups consumed by the COMPASS reconciliation system (RUDI integration) and have a distinct contract (always D365Company + an entity key) that doesn't fit cleanly into Customer/Vendor/Invoice. Keeping them in their own API preserves the COMPASS contract surface and lets RUDI evolve its validation logic without touching the master Customer/Vendor APIs.

**Alternative**: fold each into the corresponding master API as `/customers/{...}/compass-validate`, `/vendors/{...}/compass-validate`, etc. The trade-off is contract clarity vs. project count — recommend keeping as a separate API for v1 and consolidating later if RUDI's validation set never grows.

**Source procs**:

- `rudi.COMPASSValidateCustomer(@D365Company, @Vendor)` — note: `@Vendor` parameter name is misleading; per the proc body this validates a customer-vs-vendor relationship
- `rudi.COMPASSValidateCustomerInvoice(@D365Company, @Customer, @Invoice)`
- `rudi.COMPASSValidateVendorBankIdMop(@D365Company, @Vendor, @VendorBankID, @MoP)` — MoP = Method of Payment, e.g. `'Wire Trf'`
- `rudi.COMPASSValidateVendorInvoice(@D365Company, @Vendor, @Invoice)`

**Endpoints**:


| Logical Op                                                                            | HTTP | Endpoint                                                |
| ------------------------------------------------------------------------------------- | ---- | ------------------------------------------------------- |
| Validate customer-vendor pairing for COMPASS                                          | GET  | `/compass/customers/validate?legalEntity=...&vendor=...` |
| Validate customer invoice for COMPASS                                                 | GET  | `/compass/customers/{customerAccount}/invoices/{invoice}/validate?legalEntity=...` |
| Validate vendor bank-id + method-of-payment for COMPASS                               | GET  | `/compass/vendors/{vendorAccount}/bank-validate?legalEntity=...&bankId=...&mop=...` |
| Validate vendor invoice for COMPASS                                                   | GET  | `/compass/vendors/{vendorAccount}/invoices/{invoice}/validate?legalEntity=...` |

**Depends on**: Customer + Vendor + Invoice (read-only validation; no writes). RUDI/COMPASS is the only consumer.

---

## D. Shared cross-cutting concerns

These apply across **all** APIs; design them once and reuse.

1. **Source schema is `d365.*`**. Repositories query the D365 source tables directly — `d365.CustTable`, `d365.SalesTable`, `d365.CustInvoiceJour`, `d365.SalesLine`, `d365.MarkupTrans`, `d365.LogisticsPostalAddress`, `d365.DirPartyTable`, `d365.USVProgramTable`, etc. The legacy procs/views reference these tables unqualified (resolving to `dbo.*` in the SQL Server source DBs); when porting SQL, **rewrite all unqualified or `dbo.`-qualified table references to `d365.<TableName>`**. The integration-idb `dbo.*` base-table mirror views are NOT being ported — they exist only as a query-convenience mirror in the legacy stack and are unnecessary once the API queries `d365.*` directly. USV-prefixed staging views (`usv*`) are still in scope and ported into AlloyDB to support the consolidated endpoints.

   Boomi additionally couples to `d365.casedetailbase` / `d365.casedetail` (AX case-management tables not used elsewhere) — confirm these are present in the d365 schema at AlloyDB.
2. **D365 `dataAreaId` / `partition` filtering**. Many procs filter `WHERE DataAreaId = '40'`. The API should expose `legalEntity` as a parameter (or thread through claims) rather than hardcode. Applies uniformly to all 17 APIs.
3. **Hardcoded constants**. Surface as configuration:
  - `spGetWDNonSig` hardcodes vendor `'100687'`
  - `SalesforceCustomerV2` hardcodes default Salesforce owner `'0056e00000BuxsJ'` — these IDs differ between Salesforce sandboxes/prod, so a hardcoded value silently miswires ownership in non-prod
  - `SalesforceCustomerV2` responsibility-ID priority chain (`'USAF BC'` → `'USAF Car Dealer BC'` → `'Lubes BC'`) — encode in config or a lookup table
4. **Vendor-discriminator pattern**. Several procs are vendor-specific clones (`_Michelin`, `_Bridgestone`, `_ToyoTYMT`, `_FordLubes`, `_GoodyearEnduranceTrailer`). Modeling decision: single endpoint with a `vendor` enum parameter, branching inside the handler. Document the matrix per endpoint in the migration notes.
5. **Date/timezone serialization**.
  - **All APIs**: every `CREATEDDATETIME`, `INVOICEDATE`, `VALIDFROM`, etc. needs ISO-8601 string serialization per USV Stack. Build a shared date-conversion mapper in `Common.Data.<Project>` (each project will need it).
  - **SalesforceIntegration only**: Salesforce expects CST, not UTC. Every datetime in those views runs through `CONVERT(datetime, SWITCHOFFSET(col, DATEPART(TZOFFSET, col AT TIME ZONE 'Central Standard Time')))`. Postgres equivalent: `col AT TIME ZONE 'America/Chicago'`. **Must be preserved verbatim** — a UTC port silently drifts Salesforce records by 5–6 hours depending on DST.
6. **Read-vs-write split**. ~90% of the consolidated procs are reads and live in `Services.<Project>.Api/Queries/`. Notable writes (need INSERT/UPDATE inspection before scaffolding command-side):
  - `InvoiceMatching` (matching + return-data persistence)
  - `EdiInbound` (duplicate check inserts/marks?)
  - `Platform` (Azure queue management, if any updates)
   Most domain projects won't have a populated `Domain.<Project>/Commands/` folder initially; that's expected.
7. **Auth & identity**. All APIs share the same OIDC config (`login-dev.gcp.usventure.com`) — the `IdentityServerAuthentication` block in `appsettings.json` is identical across projects. Recommend a shared `Usv.Stack.Auth` helper or, at minimum, a documented snippet in `CLAUDE.md`.
8. **Connection-string convention**. USV Stack convention says `<Project>DbConnection`, but pointing 17 services at the same physical AlloyDB cluster with different keys is awkward. Either (a) use the same key everywhere via a shared constant, or (b) keep per-project keys but populate them from one secret. **Decision needed.**
9. `**COLLATE DATABASE_DEFAULT` joins** (boomi xref tables specifically). The xref tables use `nchar(50)` for `PersonnelNumber` while `HCMWORKER.PersonnelNumber` is collated differently, hence the explicit `COLLATE DATABASE_DEFAULT` on every join. In Postgres/AlloyDB this disappears (no per-column collation by default), so the repository SQL is cleaner — but the AlloyDB target should use `text` (not `char(N)`) to avoid trailing-space surprises during the wipe-and-reload.
10. **CDC / change-tracking signals**. The Salesforce-shaped views return per-table `*ModifiedDateTime` columns that Boomi uses for delta sync. Make sure the AlloyDB ports preserve these — losing one silently breaks one delta channel. Consider materialized views for heavy projections (`SalesforceCustomerV2` has ~50 columns, 14 joins, GROUP BY of 50 columns — likely the slowest endpoint in the project).
11. **No audit columns on truncate-and-reload tables**. The boomi xref tables don't have `created_by`/`created_on`/`last_updated_*`/`version`/`sort_order` per the USV Stack convention because they're truncate-and-reload, not business tables. Document this explicitly in the AlloyDB migration so reviewers don't try to add them.

---

## E. Master phasing

Front-load the smallest, most self-contained domains so the team validates the USV Stack template against real data before tackling the heavyweights. Adjusted from the per-source plans to slot SalesforceIntegration in early (it's read-only, view-based, and Atlas-independent — perfect for validating the template against a non-proc source).


| Phase | API                       | Why this slot                                                                                                   |
| ----- | ------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 0     | **`d365.*` schema available in AlloyDB** | Confirm with the data-platform team that the D365 source tables are already present in AlloyDB at the right schema/column shape. This is owned outside the API team (CDC/DMS pipeline from D365). Without it, every API project fails its first integration test. No code work for the API team in this phase, just a sign-off. |
| 1     | **Routes** (eta)          | 7 procs, no deps, isolated schema. Best smoke-test of the template.                                             |
| 2     | **Platform**              | 5 procs, no business deps.                                                                                      |
| 3     | **SalesforceIntegration** | 6 read-only endpoints, view-based, Atlas-independent. Validates template against view sources (no proc bodies). |
| 4     | **RudiCompass** *(new)*   | 4 read-only endpoints, single bounded context, Atlas-independent. Smallest new API — good template-validation candidate. |
| 5     | **TransferOrder**         | 3 procs — smallest ais domain.                                                                                  |
| 6     | **Warehouse**             | Foundational; many other domains call it.                                                                       |
| 7     | **Vendor**                | Foundational.                                                                                                   |
| 8     | **Customer**              | Foundational and large.                                                                                         |
| 9     | **Product**               | Foundational and large.                                                                                         |
| 10    | **Program**               | Depends on Customer + Product.                                                                                  |
| 11    | **Delivery**              | Depends on Customer + Warehouse.                                                                                |
| 12    | **PurchaseOrder**         | Depends on Customer + Vendor.                                                                                   |
| 13    | **Invoice**               | Depends on Customer + Product + Program.                                                                        |
| 14    | **Finance** *(new)*       | Depends on Customer + Vendor + Invoice. Esker outbound integrations cut over from direct DB access to API.      |
| 15    | **OrderStatus**           | Depends on Customer + Warehouse + Invoice.                                                                      |
| 16    | **VendorProgram**         | Depends on Vendor + Customer + Invoice + Product.                                                               |
| 17    | **InvoiceMatching**       | Depends on most of the above.                                                                                   |
| 18    | **EdiOutbound**           | Depends on OrderStatus + Customer + Invoice.                                                                    |
| 19    | **EdiInbound**            | Depends on Vendor + Customer + Invoice.                                                                         |


---

## F. Per-domain implementation checklist

For each API in §C, work through the same checklist. This is intentionally repetitive — the goal is uniformity across 19 projects so reviewers can context-switch cheaply.

1. **Triage source SQL**. Walk the relevant `*-idb/src/database/sqlserver/Scripts/sprocs/` and `views/` folder, applying the §A drop list. Flag `vN` ambiguities for source-team confirmation.
2. **Identify canonical procs/views** per the domain section in §C.
3. **Inspect for INSERT/UPDATE** statements. Anything that writes goes in `Domain.<Project>/Commands/`; everything else in `Queries/`.
4. **Port DDL to AlloyDB** for any tables/views the project owns (e.g. boomi xref DDL). Confirm parity with data-platform team for tables it only reads.
5. **Scaffold project** per USV Stack template: `Services.<Project>.Api`, `Domain.<Project>`, `Common.Data.<Project>`.
6. **Wire shared concerns** from §D: auth block, date mapper, connection-string key, `legalEntity` parameter threading.
7. **Implement endpoints** from the domain table in §C. Vendor-variant procs collapse into one handler with a `vendor` discriminator.
8. **Promote hardcoded constants** to `appsettings.json` (vendor `'100687'`, Salesforce owner ID, responsibility-ID priority chain, etc.).
9. **Write integration tests** against a real AlloyDB instance (per existing project convention — do not mock the DB).
10. **Document inter-domain calls** (e.g. InvoiceMatching → Delivery for `spRWADeliveryModesForAccount`) so consumers know to call the canonical API instead of duplicating logic.

---

## G. Inter-domain duplication to resolve

Procs that legitimately appear in two domains — pick a canonical home and document the cross-call:


| Source object                                                   | Canonical home                                       | Also called from             | Resolution                                                          |
| --------------------------------------------------------------- | ---------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------- |
| `spRWADeliveryModesForAccount`                                  | Delivery (`/delivery/modes/by-account/{accountNum}`) | InvoiceMatching              | InvoiceMatching consumers call the Delivery API                     |
| `spGetSalesOrdersByInvoiceNumbers`                              | Invoice (`/invoices/...`)                            | OrderStatus (semantically)   | Stays in Invoice; OrderStatus calls it for the invoice→SO direction |
| `spGetCCSurchargeProgramLookup`                                 | Program (rule-style lookup)                          | Customer (per-customer flag) | Stays in Program; Customer endpoint can wrap if needed              |
| `eta.spGetAccountInfoWithAccountNum` vs `ais.spGetAccountInfo*` | Both keep their own                                  | —                            | Field-level parity check needed; assume separate until confirmed    |
| `dbo.USVCustomerLookup` vs `ais.spCustomerLookup`               | Customer (`/customers`)                              | (both source DBs)            | **Hard duplicate** — same proc body, two homes. Implement once in Customer; drop the integration-side copy after cutover. |
| `dbo.USVCustomerLookupByCustRefAndGroup` vs `ais.spCustomerLookupByCustomerRefAndGroup` | Customer (`/customers`)            | (both source DBs)            | **Hard duplicate** — same as above. |
| `dbo.USVOrderStatusDetail` vs `ais.spOrderStatusDetail*`        | OrderStatus (`/order-status/detail`)                 | (both source DBs)            | **Hard duplicate** — single endpoint, one canonical implementation; drop integration-side copy. |
| `dbo.USVOrderStatusSummary` vs `ais.spOrderStatusSummary`       | OrderStatus (`/order-status/summary`)                | (both source DBs)            | **Hard duplicate** — same as above. |
| `dbo.USVOrderStatusSummaryByInvoiceAccount` vs `ais.USVOrderStatusSummaryByInvoiceAccount` | OrderStatus (`/order-status/summary/by-invoice-account`) | (both source DBs) | **Hard duplicate**, same name in both DBs. |
| `usvcustavailcredit` view                                       | Customer (`/customers/{accountNum}/available-credit`) AND Finance (`/finance/customers/{accountNum}/available-credit`) | (both endpoints) | Single view, two endpoint surfaces. The view lives once in AlloyDB; both APIs query it. |
| `usvcuststatement` / `usvcustinvoicejourstatement` views        | Finance (`/finance/customers/{accountNum}/statement`) | Customer (account view)     | Canonical home is Finance; Customer can link/embed the latest statement. |
| `USVCUSTOMERRESPONSIBILITIESEMPLENTITY` view                    | Customer + SalesforceIntegration (employee-responsible) | (both)                    | Single view, two API surfaces; same handling as `usvcustavailcredit`. |


---

## H. Coverage status

All four source DBs are now planned:

| Source DB | Planned APIs | Notes |
|---|---|---|
| `ais-idb` | 16 | Maps to OrderStatus, Invoice, InvoiceMatching, PurchaseOrder, TransferOrder, Customer, Vendor, VendorProgram, Product, Program, Warehouse, EdiInbound, EdiOutbound, Delivery, Routes, Platform |
| `boomi-idb` | +1 (SalesforceIntegration) | 5 views as endpoints; 3 xref tables ship as DDL only |
| `integration-idb` | +1 (Finance, partial), folds into 14 existing | 12 USV biz procs + 4 Esker procs split between Finance and existing domains; ~50 USV views absorbed as join inputs to existing endpoints; ~290 base-table views become AlloyDB schema (§J); 10 DBA procs out of scope |
| `rudi-idb` | +2 (Finance contributes, RudiCompass), folds into Customer/Vendor/Invoice/Delivery | 12 lookup procs distributed across existing domains; 4 COMPASSValidate procs become RudiCompass; 1 collateral view → Finance |

**Net new APIs from integration + rudi**: 2 (Finance, RudiCompass). **Net new endpoints**: ~24 (Finance ~12, RudiCompass 4, plus ~8 endpoints added to existing APIs).

---

## I. Open questions

1. `**vN` collapsing**: when there are e.g. `spOrderStatusDetailv3` through `v15`, is the **highest-numbered** version always the one in production? Or does the team have an authoritative "current" pointer (wrapper view, app-config setting)? This determines which proc body becomes canonical.
2. **Schema names in AlloyDB**: confirm `ais`, `eta`, `boomi`, `rudi`, `dbo` carry over verbatim, or if they're being renamed (the USV Stack examples used lowercase like `sales`/`ops`).
3. **Hardcoded constants** like `DataAreaId = '40'`, WDNonSig vendor `'100687'`, Salesforce owner `'0056e00000BuxsJ'` — promote to config? Pass through as parameter? Confirm.
4. **Domain count**: 19 projects is on the high end. If you'd prefer fewer-but-larger APIs (e.g. fold `TransferOrder` → `OrderStatus`, `Routes` → `Delivery`, `InvoiceMatching` → `Invoice`, `RudiCompass` → split across Customer/Vendor/Invoice), the map can collapse to ~12. Trade-off: smaller domains are easier to own & deploy independently but produce more shared-code duplication.
5. **API name for boomi**: `SalesforceIntegration`, `BoomiSync`, or `SalesforceSync`? Naming-convention preference?
6. **Salesforce Owner ID fallback** (`'0056e00000BuxsJ'`): which Salesforce environment is that ID valid in? Confirm whether to promote to per-environment config or leave as a shared default.
7. **Materialized-view strategy for `SalesforceCustomerV2`**: acceptable in AlloyDB, or do we need a different change-data-capture story (e.g. logical replication)?
8. **Inbound Salesforce → AX flows**: the boomi folder only covers AX → Salesforce projections. If Boomi also writes back to AX from Salesforce events, those procs/tables aren't in this folder — confirm whether a future API surface needs to cover inbound too.
9. **Boomi xref-load access path**: confirm Boomi will continue writing directly to AlloyDB (same model as today, just a different DB engine) and that no API/service intermediation is wanted for the xref load. If so, the AlloyDB migration needs to provision a Boomi-owned DB role with INSERT/TRUNCATE permissions on the `boomi.SalesforceXref*` tables.
10. **`USVCustomerLookup` consolidation** — confirm whether the `dbo.USV*` and `ais.sp*` versions of the duplicated procs (CustomerLookup, OrderStatusDetail, OrderStatusSummary, OrderStatusSummaryByInvoiceAccount, CustomerLookupByCustRefAndGroup) are byte-identical or have drifted. If they diverged, we need to know which copy is in production before consolidating.
11. **`rudi.GetVendorDetails` parameter naming** — the param is named `@CustomerAccount` but the proc body queries `dbo.VendTable` by `AccountNum`. Confirm with the rudi team this is just a misnomer (it's the vendor account) and not a deeper bug.
12. **`rudi.GetInvoicePostedDate` table-valued parameter** — uses `rudi.PostedDateInputTableType`. Need to confirm the AlloyDB target equivalent (Postgres composite/array type) and whether the API contract should accept a JSON array instead of mimicking the TVP shape.
13. **Esker schedule** — the four `Esker_*_AF` procs are likely called by an external Esker connector on a schedule. Confirm whether Esker calls them directly today (and will switch to the new `/finance/esker/*` API endpoints), or whether a scheduled job pushes results to Esker (in which case the API is internal-only).
14. **Quarantined Esker procs** — `Esker_company_AF` and `Esker_OutsidePmts_AF` are marked `-- !! QUARANTINED: DEPENDS ON EXCLUDED OBJECT !!` in the file headers (they reference `v_dirpartytable` which is excluded). Confirm whether `v_dirpartytable` is being un-excluded or if these endpoints should ship in a degraded state.
15. **`d365.*` schema readiness in AlloyDB** — confirm with the data-platform team that the D365 source tables (`d365.CustTable`, `d365.SalesLine`, `d365.CustInvoiceJour`, `d365.MarkupTrans`, `d365.DirPartyTable`, etc.) are present in AlloyDB at the expected schema/column shape, and that USV-prefixed AX-side tables (`USVProgramTable`, `USVAcquisitionTable`, etc.) live there too. The ~290 integration-idb mirror views are no longer being ported as a fallback (§J); this confirmation is now the only path.
16. **Schema name for ported USV views** — what AlloyDB schema do the ~60 in-scope `usv*` views land in? Options: keep them in their current schema namespace (`dbo` ports as `dbo`, or rename to `usv`/`integration`), or fold them per-API (each API's schema gets the views it needs). Recommend a single shared `usv` schema so cross-API joins remain possible.

---

## J. The integration-idb view inventory — what's in scope and what's not

`integration-idb` historically served two purposes: (1) a queryable mirror of the AX/D365 source schema, and (2) a home for USV business-logic projections. Now that API repositories will query the `d365.*` source schema directly (§D.1), purpose (1) drops out and only the USV business views remain in scope.

**The 364 views break down as**:

| Category | Count (approx) | Scope |
|---|---|---|
| AX/D365 base-table mirror views (`dbo.custtable`, `dbo.salesline`, `dbo.invoicejour`, `dbo.markuptrans`, `dbo.dirpartytable`, `dbo.inventtable`, etc. — simple `SELECT * FROM <ax_source>` projections) | ~290 | **OUT OF SCOPE**. Repositories query `d365.*` directly; these mirror views are not ported. |
| AX entity views (`*ENTITY`-suffixed: `PAYMENTTERMENTITY`, `INVENTWAREHOUSEPOSTALADDRESSENTITY`, etc.) | ~25 | **OUT OF SCOPE** for the same reason — they're entity-flavored mirrors of the same AX tables. If a specific API needs the entity-shaped projection, the repository SQL recreates it as a CTE/subquery against `d365.*`. |
| USV business views (`usv*`-prefixed) absorbed as join inputs to existing endpoints | ~50 | **IN SCOPE — port to AlloyDB**. Joined inside repository SQL of the appropriate domain (Customer, Program, VendorProgram, etc. — see per-domain "Additional join inputs" lists in §C). These have non-trivial USV business logic and don't simply mirror an AX table. |
| USV business views surfaced as new endpoints | ~10 | **IN SCOPE — port and expose**. `usvinboundqueuelog` → Platform; `usvcustavailcredit`/`usvcuststatement`/`usvcustinvoicejourstatement` → Customer + Finance; `vCustomerContactInfo_SalesForce` → SalesforceIntegration; `usvgeneralledgerhierarchy` → Finance; `vDuplicatePrograms`/`vProgramsWithNoItems`/`vProgramTablesWithZeroRecords` → Program data-quality. |

**Net porting work for views**: ~60 USV views (50 join inputs + ~10 surfaced as endpoints) need to be ported into AlloyDB so the consolidated APIs can JOIN against them or expose them as endpoints. The other ~300 are dropped.

**For SQL-porting reviewers**: when you encounter a legacy proc that does `JOIN dbo.custtable CT ON ...`, the rewritten repository SQL should be `JOIN d365.custtable CT ON ...` (no per-table mirror needed). When you encounter a legacy proc that does `JOIN usvprogramcustomer PC ON ...`, that view IS being ported — keep the join, just qualify the schema appropriately (likely `<api-schema>.usvprogramcustomer` or whatever AlloyDB convention the data team adopts).

