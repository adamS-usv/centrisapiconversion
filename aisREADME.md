# Project Atlas Phase 2 — API Domain Plan

This document captures the planned API structure for Project Atlas Phase 2, derived from analysis of the legacy stored procedures, views, and functions in `sql/`. The goal is to consolidate ~270 SQL files into a coherent set of REST APIs following the USV Stack architecture template, eliminating direct database access from consuming applications.

---

## A. Inventory triage (drop from canonical mapping)

These are dead-code variants the consolidation should ignore (only the latest non-dated, non-suffixed name survives):

- **Backup/snapshot suffixes**: `_BAK_`*, `_Bkup`, `_ORIG`, `_old`, `_New`, `_DEBUG`, `_DEBUG2`, `_TEST_*`
- **Author/review tags**: `_RK_`*, `_NickReview_*`, `_JimW`, `_DL_ReadyForDL`
- **Dated revisions** (e.g. `_07172024`, `_08082025`, `_01022026`, `_20260223`, `_Dec122022`, `_1106`, `_1014`, `_1013`, `_02262026`, `_03042026`, `_02032026`, `_2024_10_04`, `_01262025`)
- **Numeric versions**: `vN` where a higher version exists (e.g. `spOrderStatusDetailv3`–`v15` collapse to `v15` or whatever is current — recommend asking the source team which version is in production)
- **5001/5002 prefix** files appear to be Phase-1 migration stubs of the `ecoresinstancevalue` view; treat the un-prefixed `ais.v_ecoresinstancevalue` as canonical
- **0001 prefix** (`0001_ais.VendorLoyaltyReturnReasonCodes`) is a seed/init script — handled as ref-data, not an endpoint

**Vendor-specific variants** (`_Michelin`, `_Bridgestone`, `_ToyoTYMT`, `_GoodyearEnduranceTrailer`, `_FordLubes`) are NOT dead code — they encode different join/filter logic per vendor. These collapse into a single endpoint with a `vendor` discriminator parameter; the per-vendor branching moves into the handler/repository.

**Estimated canonical proc count after triage: ~145** (down from 270).

---

## B. Domain map

The schema is two-rooted: `ais.`* (the bulk — AX/D365 mirror data + integration plumbing) and `eta.*` (route/transit). The plan splits `ais` into 14 domains, `eta` is its own.

### 1. `OrderStatus` — Sales Orders & Order Status

**Scope**: Read-side queries for sales orders, order status detail/summary, backorders, holds, web order numbers, wave status. The single largest read domain.

**Source procs (canonical)**: `spGetSalesOrder`* (10), `spOrderStatusDetail` (collapse `v3`–`v15` to one), `spOrderStatusDetailTracking`, `spOrderStatusSummary`, `USVOrderStatusSummaryByInvoiceAccount(AndDateRange)`, `spBackorderSummary` (collapse `V2`/`V3`), `spGetExpiringBackOrders`, `spCheckSalesOrderHold`, `spGetWebOrderNumbers`, `spGetSalesOrderByPO`, `spGetSalesOrderByWaveId`, `spGetWhsSalesLine`, `spGetOrderDetailBySO`, `spGetOrderDetailTestNew`, `ais.GetOrderDetailForDiscountTire`

**Proposed endpoints (consolidated)**:


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


**Depends on**: Customer (account lookup), Warehouse, Invoice (joined data).

---

### 2. `Invoice` — Invoice Read & Lookup

**Scope**: Invoice retrieval by various keys, invoice metadata, invoice journal markups, FedEx invoice data, remainder calculations, line-code detail, summary roll-ups.

**Source procs**: `spGetInvoiceData(*)`, `spGetInvoiceDataByOrderAcctAndPONumber`, `spGetInvoiceDataWithInvoiceNumberAndCustomerAccount`, `spGetInvoiceDataByVendor_`* (Michelin variants → vendor parameter), `spGetInvoiceMetaData`, `spGetInvoiceCount`, `spGetInvoiceJournalMarkups`, `spGetInvoiceRemainder` (collapse v2–v4), `spGetFedExInvoiceData`, `ais.AllInvoicesSummary`, `ais.GetInvoiceDetailsByLineCode`, `spGetInvoiceAccountByProgramIdAndAccountNumber`, `spGetInvoiceAccountByProgramIdItemNumberAndCustomerAccount`, `spGetSalesOrdersByInvoiceNumbers` (cross-cuts with OrderStatus — keep here for the invoice→SO direction)

**Proposed endpoints**:


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


**Depends on**: Customer, Product, Program.

---

### 3. `InvoiceMatching` — RWA Invoice Matching (returns processing)

**Scope**: The Returns Work-Ahead matching engine. Most complex logic in the codebase — return-reason resolution, program-rule eligibility, IBS path vs. non-IBS path, fractional quantity handling, discontinue/acquisition overrides, misc-charge inclusion. Kept separate from `Invoice` because it's a transactional decision engine, not lookup.

**Source procs**: `spRWAInvoiceMatchingService` (collapse v2–v9 + IBS variants — confirm latest with team), `spRWAInvoiceData` (collapse v2–v9 + IBS variants), `spRWAGetReturnOrderData`, `spRWAReturnReasonType`, `spRWAItemsByItemGroup`, `spRWADeliveryModesForAccount`

**Proposed endpoints**:


| Logical Op                                 | HTTP | Endpoint                                                   |
| ------------------------------------------ | ---- | ---------------------------------------------------------- |
| Match candidate invoice for a return claim | POST | `/invoice-matching/match`                                  |
| Fetch RWA invoice data for a claim context | GET  | `/invoice-matching/invoice-data`                           |
| Get return order data                      | GET  | `/invoice-matching/return-orders/{returnId}`               |
| Lookup return reason types                 | GET  | `/invoice-matching/return-reason-types`                    |
| Items by item group                        | GET  | `/invoice-matching/items/by-item-group/{groupId}`          |
| Delivery modes available for account       | GET  | `/invoice-matching/delivery-modes/by-account/{accountNum}` |


**POST for matching** because it's a stateful evaluation, not a query. Depends on Program, Product, Customer, Vendor, Warehouse.

---

### 4. `PurchaseOrder` — POs (read + EDI-side create-prep)

**Scope**: PO lookup, duplicate-PO checks, PO line data prep for downstream systems, format validation, supplier-on-order.

**Source procs**: `spPurchaseOrderLookupByPO`, `spGetPurchaseOrderDetails`, `spDuplicatePoCheck`, `spGetDuplicatePoCheckForSegmentID`, `spEDIPurchOrderCreateDetails`, `spGetPOFormatValidationForCustomer`, `spGetPOLineDataForBoomi`, `spGetSupplierOnOrderByVendorId`, `spTPNADuplicateCheck` (TPNA-specific dup check — could go in EdiInbound; placing here as it's a PO-keyed dedup)

**Proposed endpoints**:


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

**Proposed endpoints**:


| Logical Op                        | HTTP | Endpoint                                       |
| --------------------------------- | ---- | ---------------------------------------------- |
| Get transfer order detail         | GET  | `/transfer-orders/{transferId}`                |
| Get transfer order transport note | GET  | `/transfer-orders/{transferId}/transport-note` |
| Get vendor return order details   | GET  | `/vendor-return-orders/{returnId}`             |


Could be folded into `OrderStatus` to keep domain count down — recommend keeping separate; transfer orders have a distinct state machine.

---

### 6. `Customer` — Customer/Account Master & Cross-References

**Scope**: Customer master pulls, account info by various IBS/Nav/Invoice/Org keys, child accounts, customer→store-code cross-refs (Discount Tire, Tire Rack, Tire Rack TW, Mavis, Cust generic), 1P customer exports, postal addresses.

**Source procs**: `spCustomerLookup`, `spCustomerLookupByCustomerRef`, `spCustomerLookupByCustomerRefAndGroup`, `spGetAccountInfo`* (~12 — by IBS, by Nav, by InvoiceAccount, by InvoiceAccount+OrgNum, by AccountNum, by AMI dealer code, by Like-CustomerID-for-Like-Program, etc.), `spGetCustomersByCreatedDateTime`, `spGetCustomersByProgramId`, `spGetCustomerDataFor1P`, `spGetCreditCardCustomers`, `spGetChildAccountsByInvoiceAccountAndAccountNum`, `spGetCustomerRefByProgramAndAccount`, `spGetCustStoreCodeXRefs`, `spGetDiscountTireStoreCodeXRefs`, `spGetTireRackStoreCodeXRefs`, `spGetTireRackTWStoreCodeXRefs`, `spGetMavisAccountsByIBSAccountNum`, `spGetPostalAddressByRole`, `spGetPrimaryPostalAddress`, `spCCSurchargeProgramLookup`

**Proposed endpoints**:


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


This is the most heavily consolidated domain — ~25 procs collapse into ~12 endpoints driven by parameter unions.

---

### 7. `Vendor` — Vendor Master & Vendor-side Lookups

**Scope**: Vendor master fetch, vendor item/PO/MFG3 lookups, payment terms, vendor warehouse external codes, "your account number" reverse-resolution, commission codes, vendor loyalty return reason codes.

**Source procs**: `spFindVendorMFG3CodeForAccount`, `spFindVendorWithIBSAccount`, `spGetYourAccountNumForVendor`, `spGetPaymentTermsByVendorAccount`, `spGetVendorWarehouseExternalCodes`, `spVendorExternalCodeLookupByCodeClassId`, `sp810InboundLookupVendorCommissionCode`, `sp810InboundLookupItemNumberForVendor`, `sp810InboundGetVendorItemForPoNumberAndItemId`, `ais.VendorLoyaltyReturnReasonCodes`, `spGetWDNonSig`

**Proposed endpoints**:


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


Note `spGetWDNonSig` hardcodes vendor `'100687'` — surface this as a config-driven endpoint and flag for the team.

---

### 8. `VendorProgram` — SSP / TPNA / CMP / Sellout / DirectSales

**Scope**: Vendor program reporting & claim data — the quarterly/monthly extracts vendors consume. Highly parameterized per vendor; strong overlap in shape but different join paths.

**Source procs**:

- SSP: `spGetSSPDataByVendorAccount(*)`, `spGetSSPDataByVendorAccountForEDI`, `spGetSSPDataByVendorAccountAndInvoiceIDListForEDI`, `spGetSSPItemsByAccountNumber(AndItemId)`, `spGetSSPReturnDataByVendorAccount(ForEDI)`, `spGetSSPAccountsFor1P`, `spLookupSspClaimNumberExists`
- TPNA: `spGetTPNAData`, `spGetTPNAHistory`, `spGetMigratedTPNAHistory`, `spGetTPNAEligibilityByAccountNumber`, `spGetTPNAProgramsByVendAccount`, `spGetTPNASSPDataByVendorAccount(ForEDI)`, `spGetTPNAVendorAccountByCustomerAccount`, `sp810InboundGetTPNAData`, `spLookupTPNAClaimNumberExists`
- CMP: `spGetCMPDataByVendorAccount(*)`, `spGetCMPReturnDataByVendorAccount`, `spGetCMPDataForFordLubes` (vendor variant)
- Sellout: `spGetSelloutDataBridgestone` (vendor variant)
- DirectSales: `spGetDirectSalesDataByCat3`, `spGetDirectSalesDataByCat4`, `spGetDirectSalesDataByVendor`, `spGetDirectSales_GoodyearEnduranceTrailer` (vendor variant)

**Proposed endpoints** (program-typed sub-resources):


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


This is the second-largest domain (~30 procs → ~16 endpoints). Flagging as a candidate to split if it grows: `VendorProgram.Ssp`, `VendorProgram.Tpna`, `VendorProgram.Cmp`. For Phase-2 v1 keep as one bounded context.

---

### 9. `Product` — Items, Tires, Attributes, Pricing

**Scope**: Product attribute search, tire details, item barcodes, item groups, customer product-number resolution, core/MAP/price-group pricing, brand catalog, price-group ↔ item mapping, 1P product export, ratings, inclusions/exclusions, Goodyear-Cooper part xref.

**Source procs**: `spGetProductAttibutes` (typo preserved), `spGetAllProductAttributes`, `spGetAllProductExclusionsByWarehouse`, `spGetExclusionsByAccountNumber`, `spGetProductGroupExclusionsByAccountNumber`, `spGetAllInclusions`, `spGetAllItemGroups`, `spGetItemBarcodes`, `spFindCustomerProductNumber`, `spGetTireDetailsByItemId`, `spGetTireProgramsWithFees`, `spGetCorePrices`, `spGetMapPrices`, `spGetCatalogCodes`, `spGetBrandsFromProductAttributes`, `spGetPriceGroupFromProductAttributes(*)`, `spGetPriceGroupAndBrandCodesFromProductAttributes`, `spGetPriceGroupAndMarketingLineFromProductAttributes`, `spGetPriceGroupItemIdFromProductAttributes`, `spGetProductAttributeItemsForPriceGroup(List)`, `spGetProductAttributesFor1P`, `spGetProductDetailsFor1P`, `spGetGoodyearCooperPartNumber`, `spGetRequireRating`, `spGetItemIdsAndWarehouses`, `ais.v_ecoresinstancevalue` (legacy product hierarchy view — exposed as ref-data endpoint)

**Proposed endpoints**:


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


---

### 10. `Program` — USV Program Rules & Eligibility

**Scope**: USV program metadata, eligibility/rule evaluation (program reason-code rules, item-on-program checks), program→customer/account rollups, campaign metadata.

**Source procs**: `spFindWithInProgramRule`, `spItemOnProgram`, `spGetAllProgramItemsForAccount`, `spGetAccountsForProgram`, `spGetProgramIdByItemId`, `spGetProgramsByRelatedProgramIdAndCustomerAccount`, `spGetProgramCustomerAccountsForVendor`, `spGetCampaignEndDateByCampaignId`, `spGetIgnoreReturnsPORequirement`, `spGetCCSurchargeProgramLookup` (lives between Program & Customer — placing here)

**Proposed endpoints**:


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

---

### 11. `Warehouse` — Warehouse / Inventory Location Master

**Scope**: Warehouse list, primary/secondary/backup warehouses for an account, IBS-warehouse predicate, location data, vendor warehouse external codes (cross-cuts Vendor — kept there).

**Source procs**: `spGetWarehouseList`, `spGetWarehouseListForAccount`, `spGetWarehouseByAccountInfo(AndWarehouseId|ForGoodYearReplenish)`, `spGetWarehouseForAccountAndPurchId`, `spGetPrimaryWarehouseByCustomerAccount`, `spGetSecondaryWarehouses`, `spGetWarehouseBackups`, `spGetWarehouseBackupsFromPrimaryWarehouse`, `spFindWarehouseData`, `spIsIBSWarehouse`, `spWarehouseLocationData`, `spGetInventLocationRecord`, `spGetWarehouseCodesForPartner`

**Proposed endpoints**:


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


---

### 12. `EdiInbound` — 810 Inbound (vendor invoices) + Distro dedup

**Scope**: Inbound EDI 810 processing — duplicate checks across `3Way`/`Misc`/`PassThru`/`Ssp`/`Tpna` modes, invoice-existence pre-check, customer-ref-for-program lookup, bank account fetch, distro-message dedup. Most of these are integration-time guards and look-asides; the API exposes them so the EDI engine doesn't talk to the DB directly.

**Source procs**: `sp810InboundCheckForDuplicate3Way`, `sp810InboundCheckForDuplicateMisc`, `sp810InboundCheckForDuplicatePassThru`, `sp810InboundCheckForDuplicateSsp`, `sp810InboundCheckForDuplicateTpna`, `sp810InboundLookupInvoiceExists`, `sp810InboundLookupCustomerRefForProgram`, `sp810GetAccountBankData`, `spCheckForRecentDistroDuplicateMessage`, `spGetTradingPartnerCrossRefFor810`

**Proposed endpoints**:


| Logical Op                                                                            | HTTP | Endpoint                                  |
| ------------------------------------------------------------------------------------- | ---- | ----------------------------------------- |
| 810 duplicate check (filters: mode = `3way`/`misc`/`passthru`/`ssp`/`tpna` + payload) | POST | `/edi/inbound/810/duplicate-check`        |
| 810 invoice-exists                                                                    | GET  | `/edi/inbound/810/invoice-exists`         |
| 810 customer-ref for program                                                          | GET  | `/edi/inbound/810/customer-ref`           |
| 810 account bank data                                                                 | GET  | `/edi/inbound/810/bank-data/{accountNum}` |
| Trading partner xref for 810                                                          | GET  | `/edi/inbound/810/trading-partners`       |
| Distro recent-duplicate check (filters: msgId, dupe-window-mins)                      | GET  | `/edi/inbound/distro/duplicate-check`     |


POST for duplicate-check because the request carries enough payload that GET is awkward, and the call has integration-side significance.

---

### 13. `EdiOutbound` — 810/850/855/856 Outbound

**Scope**: Outbound EDI payload assembly. Each transaction set has 1–4 lookup procs that pull the data needed to build the EDI document.

**Source procs**:

- 810 out: `sp810OutboundLookupBySalesId`, `sp810OutboundLookupMarkupsBySalesId`, `sp810OutboundLookupRestockFeesBySalesId`
- 850 out: `sp850OutboundLookupByAccountAndDate`, `sp850OutboundLookupByPONumbers`, `sp850OutboundLookupBySalesId`, `sp850OutboundLookupBySalesIDList`
- 855 out: `sp855OutboundLookupBySalesId`, `sp855OutboundLookupConfirmDocNum`, `sp855OutboundLookupInvoiceAccountBySalesId`
- 856 out: `sp856OutboundLookupBySalesId`, `sp856OutboundCombinedASNLookupBySalesId`

**Proposed endpoints** (transaction-set-typed sub-resources):


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

**Scope**: Delivery modes globally and by account, vendor-specific delivery receipts (Continental, Pirelli, Yokohama), Goodyear eCom freight tracking, FedEx/tracking-number lookup, master route code lookup, truck route names, WD non-sig data view.

**Source procs**: `spGetDeliveryModes`, `spRWADeliveryModesForAccount` *(noting this also appears in InvoiceMatching — original lives there; the by-account variant could be referenced from this domain too — recommend canonical home is Delivery, InvoiceMatching calls it)*, `spGetContinentalDeliveryReceipts`, `spGetPirelliDeliveryReceipts`, `spGetYokohamaDeliveryReceipts`, `spGetGoodyearEComFreightTracking`, `spFindTrackingNum`, `spGetMasterRouteCodeFromRouteId`, `spGetTruckRouteNamesForAccounts`

**Proposed endpoints**:


| Logical Op                                                                              | HTTP | Endpoint                                   |
| --------------------------------------------------------------------------------------- | ---- | ------------------------------------------ |
| List delivery modes                                                                     | GET  | `/delivery/modes`                          |
| Delivery modes for account                                                              | GET  | `/delivery/modes/by-account/{accountNum}`  |
| Vendor delivery receipts (filters: vendor = `continental`/`pirelli`/`yokohama` + dates) | GET  | `/delivery/receipts`                       |
| Goodyear eCom freight tracking                                                          | GET  | `/delivery/freight-tracking/goodyear-ecom` |
| Find tracking number                                                                    | GET  | `/delivery/tracking`                       |
| Master route code from route id                                                         | GET  | `/delivery/routes/{routeId}/master-code`   |
| Truck route names for accounts                                                          | GET  | `/delivery/routes/truck-names`             |


Re-decision: since `spRWADeliveryModesForAccount` was modeled in InvoiceMatching, keep it there *and* expose the same data here. They're literally the same proc — pick one home (recommend Delivery) and have InvoiceMatching consumers call this API instead. Track this as an inter-domain refactor.

---

### 15. `Routes` — ETA Schema (eta.*)

**Scope**: ETA route master & connectivity for transfer routing.

**Source procs**: `eta.spGetAllRoutes`, `eta.spGetAccountInfoWithAccountNum`, `eta.spGetConnectingWarehouses`, `eta.spGetCustomerTransferRoutesForWarehouse`, `eta.spGetRouteNamesForAccounts`, `eta.spGetRouteNamesForAccountsAndWarehouse`, `eta.spGetTransferRoutesForWarehouses`

**Proposed endpoints**:


| Logical Op                                                           | HTTP | Endpoint                                          |
| -------------------------------------------------------------------- | ---- | ------------------------------------------------- |
| List all routes                                                      | GET  | `/eta/routes`                                     |
| Route names for accounts (filters: account list, optional warehouse) | GET  | `/eta/routes/names-by-account`                    |
| Connecting warehouses                                                | GET  | `/eta/warehouses/connecting`                      |
| Customer transfer routes for warehouse                               | GET  | `/eta/transfer-routes/by-warehouse/{warehouseId}` |
| Transfer routes for warehouses                                       | GET  | `/eta/transfer-routes`                            |
| Account info (eta-side)                                              | GET  | `/eta/customers/account-info`                     |


Lives in `eta` schema — separate API project per the USV Stack template. Note the duplication of "account info" between `ais.spGetAccountInfoWithAccountNum` and `eta.spGetAccountInfoWithAccountNum` is intentional in the legacy schema; recommend they remain separate APIs but flag for the data-team to confirm field-level parity.

---

### 16. `Platform` — Azure Outbound / Queue Plumbing + Reference Data

**Scope**: Operational visibility into the Azure outbound integration table (the queue metadata layer that supports EDI/Boomi) plus pure reference data (holidays). Merged from earlier `Integration` + `ReferenceData` proposals — too small to warrant separate projects.

**Source procs**: `spGetAzureOutboundInfo`, `spGetAzureOutboundRequests`, `spGetAzureOutBoundRequestErrors`, `spGetAzureQueueErrors`, `spGetHolidays`

**Proposed endpoints**:


| Logical Op                        | HTTP | Endpoint                               |
| --------------------------------- | ---- | -------------------------------------- |
| Azure outbound info               | GET  | `/integration/azure/outbound/info`     |
| Azure outbound requests (filters) | GET  | `/integration/azure/outbound/requests` |
| Azure outbound request errors     | GET  | `/integration/azure/outbound/errors`   |
| Azure queue errors                | GET  | `/integration/azure/queue/errors`      |
| Holidays list                     | GET  | `/reference/holidays`                  |


---

## C. Final domain count: **16 APIs**


| #   | Domain          | Project name                   | Endpoints | Procs (canonical) |
| --- | --------------- | ------------------------------ | --------- | ----------------- |
| 1   | OrderStatus     | `Services.OrderStatus.Api`     | ~9        | ~20               |
| 2   | Invoice         | `Services.Invoice.Api`         | ~9        | ~15               |
| 3   | InvoiceMatching | `Services.InvoiceMatching.Api` | ~6        | ~6 (dense)        |
| 4   | PurchaseOrder   | `Services.PurchaseOrder.Api`   | ~6        | ~9                |
| 5   | TransferOrder   | `Services.TransferOrder.Api`   | 3         | 3                 |
| 6   | Customer        | `Services.Customer.Api`        | ~12       | ~25               |
| 7   | Vendor          | `Services.Vendor.Api`          | ~9        | ~11               |
| 8   | VendorProgram   | `Services.VendorProgram.Api`   | ~16       | ~30               |
| 9   | Product         | `Services.Product.Api`         | ~19       | ~25               |
| 10  | Program         | `Services.Program.Api`         | ~9        | ~10               |
| 11  | Warehouse       | `Services.Warehouse.Api`       | ~8        | ~13               |
| 12  | EdiInbound      | `Services.EdiInbound.Api`      | ~6        | ~10               |
| 13  | EdiOutbound     | `Services.EdiOutbound.Api`     | ~6        | ~13               |
| 14  | Delivery        | `Services.Delivery.Api`        | ~7        | ~9                |
| 15  | Routes (ETA)    | `Services.Routes.Api`          | ~6        | 7                 |
| 16  | Platform        | `Services.Platform.Api`        | ~5        | ~5                |


Total: **~135 endpoints across 16 projects** consolidating ~211 canonical procs (which is ~145 after triage; some procs map to multiple endpoints, others are folded into a single multi-filter endpoint).

---

## D. Cross-cutting concerns

1. **Legacy table coupling**. Almost every proc reads from D365/AX tables (`CustTable`, `SalesTable`, `CustInvoiceJour`, `SalesLine`, `MarkupTrans`, `LogisticsPostalAddress`, `v_dirpartytable`, `USVProgramTable`, etc.) plus USV-prefixed staging tables. The AlloyDB target schema needs to mirror or replace these. **Recommend confirming with the data-platform team**: are these tables already in AlloyDB at parity, or do we need a translation layer? This determines whether repository SQL is a near-direct port or a rewrite.
2. **D365 dataAreaId / `partition` filtering**. Many procs filter `WHERE DataAreaId = '40'`. The API should expose `legalEntity` as a parameter (or thread through claims) rather than hardcode.
3. **Hardcoded vendor accounts** (e.g. `spGetWDNonSig`'s `'100687'`). Surface as configuration; flag in migration notes.
4. **Vendor-discriminator pattern**. Several procs are vendor-specific clones (`_Michelin`, `_Bridgestone`, `_ToyoTYMT`, `_FordLubes`, `_GoodyearEnduranceTrailer`). Modeling decision per the prompt's consolidation rule: single endpoint with a `vendor` enum parameter, branching inside the handler. Document the matrix per endpoint in the migration notes.
5. **Date strings in DTOs (per USV Stack)**. Every `CREATEDDATETIME`, `INVOICEDATE`, `VALIDFROM`, etc. needs ISO-8601 string serialization. Build a shared date-conversion mapper in `Common.Data.<Project>` (each project will need it).
6. **Read-vs-write split**. ~90% of these procs are reads (queries) and will live in `Services.<Project>.Api/Queries/`. The notable writes:
  - `InvoiceMatching` (matching + return-data persistence)
  - `EdiInbound` (duplicate check inserts/marks?)
  - `Platform` (Azure queue management, if any updates)
   Need to inspect those handful of procs for INSERT/UPDATE statements before scaffolding write-side commands. The samples reviewed are all SELECT-only, so we may end up with a near-fully-read codebase — that's fine, but it means most domain projects won't have a `Domain.<Project>/Commands/` folder populated initially.
7. **Auth & identity**. All APIs share the same OIDC config (`login-dev.gcp.usventure.com`) — the `IdentityServerAuthentication` block in `appsettings.json` is identical across projects. Strongly recommend a shared `Usv.Stack.Auth` helper or, at minimum, a documented snippet in `CLAUDE.md`.
8. **One AlloyDB cluster, 16 connection strings or 1?** The USV Stack convention says `<Project>DbConnection`, but pointing 16 services at the same physical cluster with different keys is awkward. Either (a) use the same key everywhere via a shared constant, or (b) keep per-project keys but populate them from one secret. Worth a decision.

---

## E. Recommended phasing

If you scaffold in this order, you front-load the smallest, most self-contained domains so the team can validate the USV Stack template against real data before tackling the heavyweights:

1. **Routes** (eta) — 7 procs, no dependencies, isolated schema. Best smoke-test of the template.
2. **Platform** — 5 procs, no business deps.
3. **TransferOrder** — 3 procs.
4. **Warehouse** — foundational, many other domains call it.
5. **Vendor** — foundational.
6. **Customer** — foundational and large.
7. **Product** — foundational and large.
8. **Program** — depends on Customer + Product.
9. **Delivery** — depends on Customer + Warehouse.
10. **PurchaseOrder** — depends on Customer + Vendor.
11. **Invoice** — depends on Customer + Product + Program.
12. **OrderStatus** — depends on Customer + Warehouse + Invoice.
13. **VendorProgram** — depends on Vendor + Customer + Invoice + Product.
14. **InvoiceMatching** — depends on most of the above.
15. **EdiOutbound** — depends on OrderStatus + Customer + Invoice.
16. **EdiInbound** — depends on Vendor + Customer + Invoice.

---

## F. Open questions

1. `**vN` collapsing**: when there are e.g. `spOrderStatusDetailv3` through `v15`, is the **highest-numbered** version always the one in production? Or does the team have an authoritative "current" pointer somewhere (e.g. a wrapper view, an app-config setting)? This determines which proc body becomes the canonical source for the consolidated endpoint.
2. **Schema in AlloyDB**: confirm the schema names (`ais`, `eta`) carry over verbatim, or if they're being renamed (the prompt's example used lowercase like `sales`/`ops`).
3. **Hardcoded constants** like `DataAreaId = '40'` and the WDNonSig vendor `'100687'` — promote to config? Pass through as parameter? Confirm.
4. **Domain count**: 16 projects is on the high end. If you'd prefer fewer-but-larger APIs (e.g. fold `TransferOrder` → `OrderStatus`, `Routes` → `Delivery`, `InvoiceMatching` → `Invoice`), the map can collapse to ~10. Trade-off: smaller domains are easier to own & deploy independently but produce more shared-code duplication.

