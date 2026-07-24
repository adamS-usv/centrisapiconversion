# Project Atlas Phase 2 — Sproc/View → API Mapping

Per-object cheat sheet for developers porting consumers off direct SQL Server access. For each source object (sproc, view, function), this document shows the target REST API endpoint and how the legacy parameters map to API request parameters.

**For the architectural rationale**, see `MASTER_IMPLEMENTATION_PLAN.md`. This doc is the lookup table; the master plan is the design.

**Reading the tables**:
- **Source object**: name as it appears in the `*-idb/src/database/sqlserver/Scripts/` folders (drop the `.sql` extension).
- **Parameters**: declared parameters (with types) for procs; "(view)" for views.
- **Target API**: HTTP method + endpoint path. All endpoints are read (`GET`) unless noted.
- **API params**: how the legacy parameters map to the API contract (path/query/body). Every endpoint additionally accepts `legalEntity` (maps to `DataAreaId`) per master plan §D.2.
- **Notes**: consolidations, vendor variants, deprecated versions, status flags.

**Conventions**:
- "**HARD DUPLICATE**" = same proc body exists in two source DBs; consolidate to one canonical implementation.
- "**dropped**" = the proc/view is being removed per the §A triage rules in the master plan; do not port.
- "**join input**" = view is joined inside a repository SQL query, not exposed as its own endpoint.
- "**out of scope**" = the object is not being ported. For the ~290 `dbo.*` base-table mirror views in integration-idb: repositories query the `d365.*` source schema directly, so these mirror views are unnecessary — see master plan §D.1 / §J.

---

## Index of source databases

| § | Source DB | Schema(s) | Object count | API objects |
|---|---|---|---|---|
| A | `ais-idb` | `ais.*`, `eta.*` | ~270 procs + several views (~145 canonical) | All planned procs map below |
| B | `boomi-idb` | `boomi.*` | 5 views + 3 truncate procs + 3 xref-table DDL | 5 views surfaced; truncate procs DB-only |
| C | `integration-idb` | `dbo.*` | 26 procs + 364 views | 12 USV biz procs + 4 Esker + ~10 USV views surfaced + ~50 USV views ported as join inputs; 10 DBA procs out of scope; **~290 base-table mirror views OUT OF SCOPE** (repos query `d365.*` directly) |
| D | `rudi-idb` | `rudi.*` | 16 procs + 1 view | All 17 surface (12 fold into existing APIs, 4 → RudiCompass, 1 view → Finance) |

---

## A. `ais-idb` — `ais.*` and `eta.*`

Grouped by domain to match `MASTER_IMPLEMENTATION_PLAN.md` §C. Only canonical procs after triage are listed here; backup/dated/version-suffixed variants (~125 files) are dropped per §A of the master plan.

### A.1 — OrderStatus (`Services.OrderStatus.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetSalesOrder` (and ~9 variants) | various filter combos (customer, dates, invoice numbers, accounts list, PO, wave) | `GET /sales-orders` | unioned filters: `customer`, `startDate`, `endDate`, `salesOrigin`, `invoiceNumber`, `accountNumbers[]`, `po`, `waveId` | 10 procs collapse into one parameter-driven endpoint |
| `ais.spGetSalesOrderByPO` | `@PONumber` | `GET /sales-orders?po={@PONumber}` | `po` | folded into `/sales-orders` |
| `ais.spGetSalesOrderByWaveId` | `@WaveId` | `GET /sales-orders?waveId={@WaveId}` | `waveId` | folded into `/sales-orders` |
| `ais.spGetOrderDetailBySO` | `@SalesId` | `GET /sales-orders/{salesId}` | `salesId` (path) | |
| `ais.spGetOrderDetailTestNew` | (test variant) | `GET /sales-orders/{salesId}` | — | **dropped** — test variant; canonical is `spGetOrderDetailBySO` |
| `ais.GetOrderDetailForDiscountTire` | (Discount Tire-specific) | `GET /sales-orders/{salesId}?customer=discount-tire` | `customer` discriminator | folds into `/sales-orders/{salesId}` with customer-discriminator |
| `ais.spOrderStatusDetail` (collapse v3–v15) | `@CustAccount, @OrderNumber, @OrderType, @OrderStatus, @InvoiceNumber, @Warehouse, @PONumber` | `GET /order-status/detail` | `customer`, `orderNumber`, `orderType`, `orderStatus`, `invoiceNumber`, `warehouse`, `poNumber` | confirm with team which `vN` is in production (Open Q §I.1) |
| `ais.spOrderStatusDetailTracking` | `@CustAccount, @OrderNumber, ...` | `GET /order-status/{salesId}/tracking` | `salesId` (path) | |
| `ais.spOrderStatusSummary` | `@CustAccount, @OrderType, @OrderStatus, @Warehouse, @NumberOfRecords` | `GET /order-status/summary` | `customer`, `orderType`, `orderStatus`, `warehouse`, `topN` | |
| `ais.USVOrderStatusSummaryByInvoiceAccount` | `@InvoiceAccount, @OrderType, @OrderStatus, @Warehouse, @NumberOfRecords` | `GET /order-status/summary/by-invoice-account` | `invoiceAccount`, `orderType`, `orderStatus`, `warehouse`, `topN` | |
| `ais.USVOrderStatusSummaryByInvoiceAccountAndDateRange` | adds `@StartDate, @EndDate` | `GET /order-status/summary/by-invoice-account?startDate=...&endDate=...` | adds `startDate`, `endDate` | folds into above with optional date range |
| `ais.spBackorderSummary` (collapse V2/V3) | `@CustAccount` | `GET /backorders/summary?customer={@CustAccount}` | `customer` | confirm V2/V3 — V3 has the most params |
| `ais.spGetExpiringBackOrders` | `@CustAccount, @DaysToExpiry?` | `GET /backorders/expiring` | `customer`, `daysToExpiry` | |
| `ais.spCheckSalesOrderHold` | `@SalesId` | `GET /sales-orders/{salesId}/hold` | `salesId` (path) | |
| `ais.spGetWebOrderNumbers` | `@CustAccount` | `GET /sales-orders?customer={@CustAccount}&include=webOrderNumbers` | `customer`, `include` | could be a sub-endpoint if needed |
| `ais.spGetWhsSalesLine` | `@SalesId` | `GET /sales-orders/{salesId}/whs-lines` | `salesId` (path) | warehouse-flavored line view |

### A.2 — Invoice (`Services.Invoice.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetInvoiceData` (and variants) | various keys (invoice account, vendor, PO, invoice number, customer account, dates) | `GET /invoices` | unioned filters: `invoiceAccount`, `vendorAccount`, `po`, `invoiceNumber`, `customerAccount`, `startDate`, `endDate`, `vendor` | base `/invoices` search |
| `ais.spGetInvoiceDataByOrderAcctAndPONumber` | `@AccountNumber, @PONumber` | `GET /invoices?customerAccount=...&po=...` | folded |
| `ais.spGetInvoiceDataWithInvoiceNumberAndCustomerAccount` | `@InvoiceNumber, @CustomerAccount` | `GET /invoices?invoiceNumber=...&customerAccount=...` | folded |
| `ais.spGetInvoiceDataByVendor_Michelin` | Michelin-specific filter | `GET /invoices?vendor=michelin&...` | `vendor` discriminator | one of multiple `_<vendor>` clones — all collapse |
| `ais.spGetInvoiceMetaData` | `@InvoiceId` | `GET /invoices/{invoiceId}` | `invoiceId` (path) | |
| `ais.spGetInvoiceCount` | filters | `GET /invoices/count` | same filters as `/invoices` | |
| `ais.spGetInvoiceJournalMarkups` | `@InvoiceId` | `GET /invoices/{invoiceId}/markups` | `invoiceId` (path) | |
| `ais.spGetInvoiceRemainder` (collapse v2–v4) | `@InvoiceId` | `GET /invoices/{invoiceId}/remainder` | `invoiceId` (path) | |
| `ais.spGetFedExInvoiceData` | filters | `GET /invoices/fedex-export` | as needed | |
| `ais.AllInvoicesSummary` | `@InvoiceAccount, @Warehouse?, @NumberOfRecords?` | `GET /invoices/summary` | `invoiceAccount`, `warehouse`, `topN` | |
| `ais.GetInvoiceDetailsByLineCode` | `@StartDate DATE, @EndDate DATE, @LineCode VARCHAR(250), @NotInList NVARCHAR(MAX)` | `GET /invoices/{invoiceId}/lines/by-line-code` | `lineCode`, `startDate`, `endDate`, `notInList` | path-keyed by invoice; filters in query |
| `ais.spGetInvoiceAccountByProgramIdAndAccountNumber` | `@ProgramId, @AccountNumber` | `GET /invoices/account-resolution?programId=...&accountNumber=...` | `programId`, `accountNumber` | |
| `ais.spGetInvoiceAccountByProgramIdItemNumberAndCustomerAccount` | `@ProgramId, @ItemNumber, @CustomerAccount` | `GET /invoices/account-resolution?programId=...&itemNumber=...&customerAccount=...` | adds `itemNumber` | folded into above |
| `ais.spGetSalesOrdersByInvoiceNumbers` | `@InvoiceNumbers list` | `GET /invoices/sales-orders?invoiceNumbers=...` | `invoiceNumbers[]` | also referenced from OrderStatus — canonical home is Invoice |

### A.3 — InvoiceMatching (`Services.InvoiceMatching.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spRWAInvoiceMatchingService` (collapse v2–v9 + IBS variants) | matching context (claim id, customer, item, dates, ...) | `POST /invoice-matching/match` | matching context body | **POST** — stateful evaluation; confirm latest version with team |
| `ais.spRWAInvoiceData` (collapse v2–v9 + IBS variants) | claim context | `GET /invoice-matching/invoice-data` | claim context as query | |
| `ais.spRWAGetReturnOrderData` | `@ReturnId` | `GET /invoice-matching/return-orders/{returnId}` | `returnId` (path) | |
| `ais.spRWAReturnReasonType` | (no params, lookup) | `GET /invoice-matching/return-reason-types` | — | |
| `ais.spRWAItemsByItemGroup` | `@ItemGroup` | `GET /invoice-matching/items/by-item-group/{groupId}` | `groupId` (path) | |
| `ais.spRWADeliveryModesForAccount` | `@AccountNumber` | `GET /invoice-matching/delivery-modes/by-account/{accountNum}` *(also exposed as `/delivery/modes/by-account/{accountNum}` — canonical home is Delivery; InvoiceMatching consumers should call the Delivery API)* | `accountNum` (path) | inter-domain duplication — see master plan §G |

### A.4 — PurchaseOrder (`Services.PurchaseOrder.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spPurchaseOrderLookupByPO` | `@PONumber` | `GET /purchase-orders/{poNumber}` | `poNumber` (path) | |
| `ais.spGetPurchaseOrderDetails` | `@PONumber` | `GET /purchase-orders/{poNumber}` | same as above | folded |
| `ais.spDuplicatePoCheck` | `@CustomerAccount, @PO, @ItemId?` | `GET /purchase-orders/duplicate-check` | `customer`, `po`, `itemId` | |
| `ais.spGetDuplicatePoCheckForSegmentID` | `@SegmentId, @PO, ...` | `GET /purchase-orders/duplicate-check?segment={@SegmentId}` | adds `segment` | folded |
| `ais.spEDIPurchOrderCreateDetails` | `@PONumber` | `GET /purchase-orders/{poNumber}/edi-line-data` | `poNumber` (path) | |
| `ais.spGetPOFormatValidationForCustomer` | `@CustomerAccount` | `GET /purchase-orders/format-validation/{customerAccount}` | `customerAccount` (path) | |
| `ais.spGetPOLineDataForBoomi` | `@PONumber` | `GET /purchase-orders/{poNumber}/boomi-export` | `poNumber` (path) | |
| `ais.spGetSupplierOnOrderByVendorId` | `@VendorId` | `GET /purchase-orders/supplier-on-order/{vendorId}` | `vendorId` (path) | |
| `ais.spTPNADuplicateCheck` | TPNA-specific dedup | `GET /purchase-orders/duplicate-check?mode=tpna` | `mode=tpna` | TPNA-flavored dedup; folded into duplicate-check |

### A.5 — TransferOrder (`Services.TransferOrder.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetTransferOrderDetails` | `@TransferId` | `GET /transfer-orders/{transferId}` | `transferId` (path) | |
| `ais.spGetTransferOrderTransportNote` | `@TransferId` | `GET /transfer-orders/{transferId}/transport-note` | `transferId` (path) | |
| `ais.spGetVendorReturnOrderDeatils` *(typo preserved in source)* | `@ReturnId` | `GET /vendor-return-orders/{returnId}` | `returnId` (path) | fix typo at the API layer |

### A.6 — Customer (`Services.Customer.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spCustomerLookup` | `@CustomerRef` | `GET /customers?customerRef={@CustomerRef}` | `customerRef` | **HARD DUPLICATE** of `dbo.USVCustomerLookup` |
| `ais.spCustomerLookupByCustomerRef` | `@CustomerRef` | `GET /customers?customerRef={@CustomerRef}` | same as above | folded |
| `ais.spCustomerLookupByCustomerRefAndGroup` | `@CustomerRef, @ProgramGroup` | `GET /customers?customerRef={@CustomerRef}&programGroup={@ProgramGroup}` | adds `programGroup` | **HARD DUPLICATE** of `dbo.USVCustomerLookupByCustRefAndGroup` |
| `ais.spGetAccountInfo` (and ~12 variants by IBS#/Nav#/InvoiceAccount/OrgNum/AMI dealer code/like-program) | various single-key lookups | `GET /customers/account-info` | unioned: `ibs`, `nav`, `accountNum`, `invoiceAccount`, `orgNum`, `ibsAccount+orgNum`, `invoiceAccounts[]+orgNum`, `amiDealerCode`, `likeProgram` | 12 procs collapse into one parameter-driven endpoint |
| `ais.spGetCustomersByCreatedDateTime` | `@Since DATETIME` | `GET /customers/created-since?since=...` | `since` | ISO-8601 |
| `ais.spGetCustomersByProgramId` | `@ProgramId` | `GET /customers/by-program/{programId}` | `programId` (path) | |
| `ais.spGetCustomerDataFor1P` | (full export) | `GET /customers/1p-export` | — | |
| `ais.spGetCreditCardCustomers` | (lookup) | `GET /customers/credit-card` | — | |
| `ais.spGetChildAccountsByInvoiceAccountAndAccountNum` | `@InvoiceAccount, @AccountNum` | `GET /customers/{invoiceAccount}/children?accountNum=...` | `invoiceAccount` (path), `accountNum` | |
| `ais.spGetCustomerRefByProgramAndAccount` | `@ProgramId, @AccountNum` | `GET /customers/customer-ref?programId=...&accountNum=...` | `programId`, `accountNum` | |
| `ais.spGetCustStoreCodeXRefs` | (filters) | `GET /customers/store-code-xrefs?source=cust` | `source=cust` | source-discriminated union of 4 procs |
| `ais.spGetDiscountTireStoreCodeXRefs` | (filters) | `GET /customers/store-code-xrefs?source=discount-tire` | `source=discount-tire` | folded |
| `ais.spGetTireRackStoreCodeXRefs` | (filters) | `GET /customers/store-code-xrefs?source=tire-rack` | `source=tire-rack` | folded |
| `ais.spGetTireRackTWStoreCodeXRefs` | (filters) | `GET /customers/store-code-xrefs?source=tire-rack-tw` | `source=tire-rack-tw` | folded |
| `ais.spGetMavisAccountsByIBSAccountNum` | `@IBSAccountNum` | `GET /customers/account-info?ibs={@IBSAccountNum}&consumer=mavis` | `ibs`, `consumer=mavis` | folded into account-info with consumer discriminator |
| `ais.spGetPostalAddressByRole` | `@AccountNum, @Role` | `GET /customers/{accountNum}/addresses/by-role?role=...` | `accountNum` (path), `role` | |
| `ais.spGetPrimaryPostalAddress` | `@AccountNum` | `GET /customers/{accountNum}/addresses/primary` | `accountNum` (path) | |
| `ais.spCCSurchargeProgramLookup` | `@AccountNum` | `GET /customers/{accountNum}/cc-surcharge-program` | `accountNum` (path) | also referenced from Program — canonical home is Program; Customer wraps |

### A.7 — Vendor (`Services.Vendor.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spFindVendorMFG3CodeForAccount` | `@MFG3Code` | `GET /vendors?mfg3Code=...` | `mfg3Code` | |
| `ais.spFindVendorWithIBSAccount` | `@IBSAccount` | `GET /vendors?ibsAccount=...` | `ibsAccount` | folded |
| `ais.spGetYourAccountNumForVendor` | `@VendorAccount, @CustomerAccount` | `GET /vendors/{vendorAccount}/your-account-number?customer=...` | `vendorAccount` (path), `customer` | |
| `ais.spGetPaymentTermsByVendorAccount` | `@VendorAccount` | `GET /vendors/{vendorAccount}/payment-terms` | `vendorAccount` (path) | |
| `ais.spGetVendorWarehouseExternalCodes` | `@VendorAccount` | `GET /vendors/{vendorAccount}/warehouse-external-codes` | `vendorAccount` (path) | |
| `ais.spVendorExternalCodeLookupByCodeClassId` | `@CodeClassId` | `GET /vendors/external-codes/{codeClassId}` | `codeClassId` (path) | |
| `ais.sp810InboundLookupVendorCommissionCode` | `@VendorAccount` | `GET /vendors/{vendorAccount}/commission-code` | `vendorAccount` (path) | |
| `ais.sp810InboundLookupItemNumberForVendor` | `@VendorAccount, @ItemId` | `GET /vendors/{vendorAccount}/items?itemId=...` | `vendorAccount` (path), `itemId` | |
| `ais.sp810InboundGetVendorItemForPoNumberAndItemId` | `@VendorAccount, @PONumber, @ItemId` | `GET /vendors/{vendorAccount}/items?po=...&itemId=...` | adds `po` | folded |
| `ais.VendorLoyaltyReturnReasonCodes` | (lookup) | `GET /vendors/loyalty-return-reason-codes` | — | |
| `ais.spGetWDNonSig` | (no params — vendor `'100687'` hardcoded) | `GET /vendors/wd-non-signatory` | — | **flag for parameterization** — promote `'100687'` to config |

### A.8 — VendorProgram (`Services.VendorProgram.Api`)

#### SSP

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetSSPDataByVendorAccount` (and variants) | `@VendorAccount, @StartDate?, @EndDate?, dealer?, invoiceIdList?, ediMode?` | `GET /vendor-programs/ssp/data` | unioned filters | |
| `ais.spGetSSPDataByVendorAccountForEDI` | adds EDI mode | `GET /vendor-programs/ssp/data?ediMode=true` | `ediMode=true` | folded |
| `ais.spGetSSPDataByVendorAccountAndInvoiceIDListForEDI` | `@VendorAccount, @InvoiceIDList, EDI` | `GET /vendor-programs/ssp/data?invoiceIds=...&ediMode=true` | adds `invoiceIds[]` | folded |
| `ais.spGetSSPItemsByAccountNumber` | `@AccountNumber` | `GET /vendor-programs/ssp/items?account=...` | `account` | |
| `ais.spGetSSPItemsByAccountNumberAndItemId` | `@AccountNumber, @ItemId` | adds `itemId` | folded |
| `ais.spGetSSPReturnDataByVendorAccount` | `@VendorAccount` | `GET /vendor-programs/ssp/returns?vendor=...` | `vendor` | |
| `ais.spGetSSPReturnDataByVendorAccountForEDI` | + EDI | `GET /vendor-programs/ssp/returns?vendor=...&ediMode=true` | adds `ediMode` | folded |
| `ais.spGetSSPAccountsFor1P` | (export) | `GET /vendor-programs/ssp/accounts/1p-export` | — | |
| `ais.sp810LookupSspClaimNumberExists` (or `ais.spLookupSspClaimNumberExists`) | `@ClaimNumber` | `GET /vendor-programs/ssp/claims/{claimNumber}/exists` | `claimNumber` (path) | |

#### TPNA

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetTPNAData` | `@VendorAccount, @StartDate, @EndDate` | `GET /vendor-programs/tpna/data` | `vendor`, `startDate`, `endDate` | |
| `ais.spGetTPNAHistory` | filters | `GET /vendor-programs/tpna/history` | filters as query | |
| `ais.spGetMigratedTPNAHistory` | filters | `GET /vendor-programs/tpna/history?includeMigrated=true` | adds `includeMigrated` | folded |
| `ais.spGetTPNAEligibilityByAccountNumber` | `@AccountNumber` | `GET /vendor-programs/tpna/eligibility/{accountNumber}` | `accountNumber` (path) | |
| `ais.spGetTPNAProgramsByVendAccount` | `@VendorAccount` | `GET /vendor-programs/tpna/programs/{vendorAccount}` | `vendorAccount` (path) | |
| `ais.spGetTPNASSPDataByVendorAccount` (and `ForEDI`) | `@VendorAccount, ediMode?` | `GET /vendor-programs/tpna/ssp-data` | `vendor`, `ediMode` | |
| `ais.spGetTPNAVendorAccountByCustomerAccount` | `@CustomerAccount` | `GET /vendor-programs/tpna/vendor-account-by-customer/{customerAccount}` | `customerAccount` (path) | |
| `ais.sp810InboundGetTPNAData` | (810 inbound flow) | `GET /vendor-programs/tpna/data?source=edi-810` | `source=edi-810` | folded |
| `ais.sp810LookupTPNAClaimNumberExists` (or `ais.spLookupTPNAClaimNumberExists`) | `@ClaimNumber` | `GET /vendor-programs/tpna/claims/{claimNumber}/exists` | `claimNumber` (path) | |

#### CMP

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetCMPDataByVendorAccount` (and variants) | `@VendorAccount, dates` | `GET /vendor-programs/cmp/data` | filters as query | |
| `ais.spGetCMPReturnDataByVendorAccount` | `@VendorAccount` | `GET /vendor-programs/cmp/returns` | `vendor` | |
| `ais.spGetCMPDataForFordLubes` | (Ford Lubes vendor variant) | `GET /vendor-programs/cmp/data?vendor=ford-lubes` | `vendor` discriminator | folded |

#### Sellout / DirectSales

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetSelloutDataBridgestone` | (Bridgestone vendor variant) | `GET /vendor-programs/sellout/data?vendor=bridgestone` | `vendor` discriminator | sole sellout proc today |
| `ais.spGetDirectSalesDataByCat3` | `@Cat3` | `GET /vendor-programs/direct-sales?cat3=...` | `cat3` | |
| `ais.spGetDirectSalesDataByCat4` | `@Cat4` | `GET /vendor-programs/direct-sales?cat4=...` | `cat4` | folded |
| `ais.spGetDirectSalesDataByVendor` | `@VendorAccount` | `GET /vendor-programs/direct-sales?vendor=...` | `vendor` | folded |
| `ais.spGetDirectSales_GoodyearEnduranceTrailer` | (Goodyear Endurance Trailer vendor variant) | `GET /vendor-programs/direct-sales?vendor=goodyear-endurance-trailer` | `vendor` discriminator | folded |

### A.9 — Product (`Services.Product.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetProductAttibutes` *(typo preserved)* | filters (brand, price-group, marketing-line, catalog-code) | `GET /products/attributes` | unioned filters | |
| `ais.spGetAllProductAttributes` | (all) | `GET /products/attributes` (no filters) | — | folded |
| `ais.spGetAllProductExclusionsByWarehouse` | `@Warehouse` | `GET /products/exclusions?warehouse=...` | `warehouse` | |
| `ais.spGetExclusionsByAccountNumber` | `@AccountNumber` | `GET /products/exclusions?account=...` | `account` | folded |
| `ais.spGetProductGroupExclusionsByAccountNumber` | `@AccountNumber, @ProductGroup` | `GET /products/exclusions?account=...&productGroup=...` | adds `productGroup` | folded |
| `ais.spGetAllInclusions` | (all) | `GET /products/inclusions` | — | |
| `ais.spGetAllItemGroups` | (all) | `GET /products/item-groups` | — | |
| `ais.spGetItemBarcodes` | `@ItemId` | `GET /products/{itemId}/barcodes` | `itemId` (path) | |
| `ais.spFindCustomerProductNumber` | `@CustomerAccount, @ItemId` | `GET /products/customer-product-number?customer=...&itemId=...` | `customer`, `itemId` | |
| `ais.spGetTireDetailsByItemId` | `@ItemId` | `GET /products/tires/{itemId}` | `itemId` (path) | |
| `ais.spGetTireProgramsWithFees` | (lookup) | `GET /products/tires/programs` | — | |
| `ais.spGetCorePrices` | filters | `GET /products/prices/core` | as needed | |
| `ais.spGetMapPrices` | filters | `GET /products/prices/map` | as needed | |
| `ais.spGetCatalogCodes` | (lookup) | `GET /products/catalog-codes` | — | |
| `ais.spGetBrandsFromProductAttributes` | (lookup) | `GET /products/brands` | — | |
| `ais.spGetPriceGroupFromProductAttributes` (and variants) | filters | `GET /products/price-groups` | as needed | |
| `ais.spGetPriceGroupAndBrandCodesFromProductAttributes` | filters | `GET /products/price-groups?include=brand-codes` | adds `include` | folded |
| `ais.spGetPriceGroupAndMarketingLineFromProductAttributes` | filters | `GET /products/price-groups?include=marketing-line` | adds `include` | folded |
| `ais.spGetPriceGroupItemIdFromProductAttributes` | filters | `GET /products/price-groups/items` | as needed | |
| `ais.spGetProductAttributeItemsForPriceGroup` (and `List`) | `@PriceGroup` (single or list) | `GET /products/price-groups/items?priceGroups=...` | `priceGroups[]` | folded |
| `ais.spGetProductAttributesFor1P` | (export) | `GET /products/attributes/1p-export` | — | |
| `ais.spGetProductDetailsFor1P` | (export) | `GET /products/1p-export` | — | |
| `ais.spGetGoodyearCooperPartNumber` | `@PartNumber` | `GET /products/goodyear-cooper-xref?partNumber=...` | `partNumber` | |
| `ais.spGetRequireRating` | `@ItemId` | `GET /products/{itemId}/require-rating` | `itemId` (path) | |
| `ais.spGetItemIdsAndWarehouses` | (lookup) | `GET /products/item-warehouses` | — | |
| `ais.v_ecoresinstancevalue` (view) | (view) | `GET /products/ecores-instance-values` | — | legacy product hierarchy view exposed as ref-data |

### A.10 — Program (`Services.Program.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spFindWithInProgramRule` | `@ReasonCode, @CustomerAccount, @InvoiceDate, @ClaimDate, @ProgramId` | `POST /programs/rules/within-program/evaluate` | body fields | **POST** — decision call |
| `ais.spItemOnProgram` | `@ProgramId, @ItemId` | `GET /programs/{programId}/items/{itemId}` | both path | |
| `ais.spGetAllProgramItemsForAccount` | `@ProgramId, @AccountNum` | `GET /programs/{programId}/items/by-account/{accountNum}` | both path | |
| `ais.spGetAccountsForProgram` | `@ProgramId` | `GET /programs/{programId}/accounts` | path | |
| `ais.spGetProgramIdByItemId` | `@ItemId` | `GET /programs/by-item/{itemId}` | path | |
| `ais.spGetProgramsByRelatedProgramIdAndCustomerAccount` | `@RelatedProgramId, @CustomerAccount` | `GET /programs/related?relatedProgramId=...&customer=...` | both query | |
| `ais.spGetProgramCustomerAccountsForVendor` | `@VendorAccount` | `GET /programs/by-vendor/{vendorAccount}` | path | |
| `ais.spGetCampaignEndDateByCampaignId` | `@CampaignId` | `GET /programs/campaigns/{campaignId}/end-date` | path | |
| `ais.spGetIgnoreReturnsPORequirement` | `@ReasonCodeId` | `GET /programs/return-rules/ignore-po-requirement/{reasonCodeId}` | path | |
| `ais.spGetCCSurchargeProgramLookup` | `@AccountNum` | `GET /customers/{accountNum}/cc-surcharge-program` | path | canonical home is Program; Customer surfaces it |

### A.11 — Warehouse (`Services.Warehouse.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetWarehouseList` | (all) | `GET /warehouses` | — | |
| `ais.spGetWarehouseListForAccount` | `@AccountNum` | `GET /warehouses?account=...` | `account` | folded |
| `ais.spGetWarehouseByAccountInfo` | `@AccountInfo` | `GET /warehouses/by-account?account=...` | `account` | |
| `ais.spGetWarehouseByAccountInfoAndWarehouseId` | adds `@WarehouseId` | `GET /warehouses/by-account?account=...&warehouseId=...` | adds `warehouseId` | folded |
| `ais.spGetWarehouseByAccountInfoForGoodYearReplenish` | + replenish-mode | `GET /warehouses/by-account?account=...&replenishMode=goodyear` | adds `replenishMode` | folded |
| `ais.spGetWarehouseForAccountAndPurchId` | `@AccountNum, @PurchId` | `GET /warehouses/by-account?account=...&purchId=...` | adds `purchId` | folded |
| `ais.spGetPrimaryWarehouseByCustomerAccount` | `@CustomerAccount` | `GET /warehouses/primary/{customerAccount}` | path | |
| `ais.spGetSecondaryWarehouses` | `@CustomerAccount` | `GET /warehouses/secondary/{customerAccount}` | path | |
| `ais.spGetWarehouseBackups` | `@AccountNum` | `GET /warehouses/backups?account=...` | `account` | |
| `ais.spGetWarehouseBackupsFromPrimaryWarehouse` | `@PrimaryWarehouse` | `GET /warehouses/backups?primaryWarehouse=...` | `primaryWarehouse` | folded |
| `ais.spFindWarehouseData` | `@WarehouseId` | `GET /warehouses/{warehouseId}/location` | path | |
| `ais.spIsIBSWarehouse` | `@WarehouseId` | `GET /warehouses/{warehouseId}/is-ibs` | path | returns boolean |
| `ais.spWarehouseLocationData` | `@WarehouseId` | `GET /warehouses/{warehouseId}/location` | path | |
| `ais.spGetInventLocationRecord` | `@LocationId` | `GET /warehouses/invent-location/{locationId}` | path | |
| `ais.spGetWarehouseCodesForPartner` | `@Partner` | `GET /warehouses?partner=...` | `partner` | folded into `/warehouses` |

### A.12 — EdiInbound (`Services.EdiInbound.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.sp810InboundCheckForDuplicate3Way` | payload context | `POST /edi/inbound/810/duplicate-check` | body `{mode: "3way", ...}` | mode-discriminated POST |
| `ais.sp810InboundCheckForDuplicateMisc` | payload | `POST /edi/inbound/810/duplicate-check` | body `{mode: "misc", ...}` | folded |
| `ais.sp810InboundCheckForDuplicatePassThru` | payload | `POST /edi/inbound/810/duplicate-check` | body `{mode: "passthru", ...}` | folded |
| `ais.sp810InboundCheckForDuplicateSsp` | payload | `POST /edi/inbound/810/duplicate-check` | body `{mode: "ssp", ...}` | folded |
| `ais.sp810InboundCheckForDuplicateTpna` | payload | `POST /edi/inbound/810/duplicate-check` | body `{mode: "tpna", ...}` | folded |
| `ais.sp810InboundLookupInvoiceExists` | `@InvoiceNumber` | `GET /edi/inbound/810/invoice-exists?invoiceNumber=...` | `invoiceNumber` | |
| `ais.sp810InboundLookupCustomerRefForProgram` | `@ProgramId, @AccountNum` | `GET /edi/inbound/810/customer-ref?programId=...&account=...` | `programId`, `account` | |
| `ais.sp810GetAccountBankData` | `@AccountNum` | `GET /edi/inbound/810/bank-data/{accountNum}` | path | |
| `ais.spCheckForRecentDistroDuplicateMessage` | `@MsgId, @WindowMins?` | `GET /edi/inbound/distro/duplicate-check?msgId=...&windowMins=...` | `msgId`, `windowMins` | |
| `ais.spGetTradingPartnerCrossRefFor810` | (lookup) | `GET /edi/inbound/810/trading-partners` | — | |

### A.13 — EdiOutbound (`Services.EdiOutbound.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.sp810OutboundLookupBySalesId` | `@SalesId` | `GET /edi/outbound/810/{salesId}` | path | |
| `ais.sp810OutboundLookupMarkupsBySalesId` | `@SalesId` | `GET /edi/outbound/810/{salesId}?include=markups` | adds `include=markups` | folded |
| `ais.sp810OutboundLookupRestockFeesBySalesId` | `@SalesId` | `GET /edi/outbound/810/{salesId}?include=restock-fees` | adds `include=restock-fees` | folded |
| `ais.sp850OutboundLookupByAccountAndDate` | `@Account, @Date` | `GET /edi/outbound/850?account=...&date=...` | `account`, `date` | |
| `ais.sp850OutboundLookupByPONumbers` | `@PONumbers list` | `GET /edi/outbound/850?poNumbers=...` | `poNumbers[]` | folded |
| `ais.sp850OutboundLookupBySalesId` | `@SalesId` | `GET /edi/outbound/850?salesId=...` | `salesId` | folded |
| `ais.sp850OutboundLookupBySalesIDList` | `@SalesIds list` | `GET /edi/outbound/850?salesIds=...` | `salesIds[]` | folded |
| `ais.sp855OutboundLookupBySalesId` | `@SalesId` | `GET /edi/outbound/855/{salesId}` | path | |
| `ais.sp855OutboundLookupConfirmDocNum` | `@SalesId` | `GET /edi/outbound/855/{salesId}/confirm-doc-num` | path | |
| `ais.sp855OutboundLookupInvoiceAccountBySalesId` | `@SalesId` | `GET /edi/outbound/855/{salesId}/invoice-account` | path | |
| `ais.sp856OutboundLookupBySalesId` | `@SalesId` | `GET /edi/outbound/856/{salesId}` | path | |
| `ais.sp856OutboundCombinedASNLookupBySalesId` | `@SalesId` | `GET /edi/outbound/856/{salesId}?combinedAsn=true` | adds `combinedAsn` | folded |

### A.14 — Delivery (`Services.Delivery.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetDeliveryModes` | (lookup) | `GET /delivery/modes` | — | |
| `ais.spRWADeliveryModesForAccount` | `@AccountNum` | `GET /delivery/modes/by-account/{accountNum}` | path | inter-domain dup with InvoiceMatching — see master plan §G |
| `ais.spGetContinentalDeliveryReceipts` | `@StartDate, @EndDate` | `GET /delivery/receipts?vendor=continental&...` | `vendor=continental`, dates | |
| `ais.spGetPirelliDeliveryReceipts` | dates | `GET /delivery/receipts?vendor=pirelli&...` | `vendor=pirelli`, dates | folded |
| `ais.spGetYokohamaDeliveryReceipts` | dates | `GET /delivery/receipts?vendor=yokohama&...` | `vendor=yokohama`, dates | folded |
| `ais.spGetGoodyearEComFreightTracking` | filters | `GET /delivery/freight-tracking/goodyear-ecom` | as needed | |
| `ais.spFindTrackingNum` | `@TrackingNum` | `GET /delivery/tracking?number=...` | `number` | |
| `ais.spGetMasterRouteCodeFromRouteId` | `@RouteId` | `GET /delivery/routes/{routeId}/master-code` | path | |
| `ais.spGetTruckRouteNamesForAccounts` | `@AccountNumbers list` | `GET /delivery/routes/truck-names?accounts=...` | `accounts[]` | |

### A.15 — Routes / `eta.*` (`Services.Routes.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `eta.spGetAllRoutes` | (all) | `GET /eta/routes` | — | |
| `eta.spGetAccountInfoWithAccountNum` | `@AccountNum` | `GET /eta/customers/account-info?accountNum=...` | `accountNum` | parallel to ais.spGetAccountInfo — confirm parity (Open Q §I) |
| `eta.spGetConnectingWarehouses` | filters | `GET /eta/warehouses/connecting` | as needed | |
| `eta.spGetCustomerTransferRoutesForWarehouse` | `@WarehouseId` | `GET /eta/transfer-routes/by-warehouse/{warehouseId}` | path | |
| `eta.spGetRouteNamesForAccounts` | `@Accounts list` | `GET /eta/routes/names-by-account?accounts=...` | `accounts[]` | |
| `eta.spGetRouteNamesForAccountsAndWarehouse` | + `@WarehouseId` | adds `warehouseId` | folded |
| `eta.spGetTransferRoutesForWarehouses` | `@Warehouses list` | `GET /eta/transfer-routes?warehouses=...` | `warehouses[]` | |

### A.16 — Platform (`Services.Platform.Api`)

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `ais.spGetAzureOutboundInfo` | (lookup) | `GET /integration/azure/outbound/info` | — | |
| `ais.spGetAzureOutboundRequests` | filters | `GET /integration/azure/outbound/requests` | as needed | |
| `ais.spGetAzureOutBoundRequestErrors` | filters | `GET /integration/azure/outbound/errors` | as needed | |
| `ais.spGetAzureQueueErrors` | filters | `GET /integration/azure/queue/errors` | as needed | |
| `ais.spGetHolidays` | (ref data) | `GET /reference/holidays` | — | |

---

## B. `boomi-idb` — `boomi.*`

All 5 views become `Services.SalesforceIntegration.Api` endpoints. The 3 truncate procs and 3 xref tables are infrastructure (DDL ports + DB-direct Boomi access), not API.

| Source object | Type | Parameters | Target API | API params | Notes |
|---|---|---|---|---|---|
| `boomi.SalesforceCustomerV2` | view | (modified-since via `WHERE`-clause filter) | `GET /salesforce/customers` | `customerAccount`, `modifiedSince`, paging | heavy view (~50 cols, 14 joins) — recommend materialized view |
| `boomi.SalesforceCustomerV2` (single record) | view | (filter to one customer) | `GET /salesforce/customers/{customerAccount}` | `customerAccount` (path) | same view, path-keyed |
| `boomi.SalesforceCaseDetail` | view | (case id, status, modified-since) | `GET /salesforce/cases` | `caseId`, `status`, `modifiedSince` | |
| `boomi.SalesforceWarehouse` | view | (warehouse id, modified-since) | `GET /salesforce/warehouses` | `warehouseId`, `modifiedSince` | |
| `boomi.SalesforceEmployeeResponsible` | view | (customer, responsibility id) | `GET /salesforce/employee-responsible` | `customerAccount`, `responsibilityId` | |
| `boomi.FlexInventCheck_DefaultWarehouse` | view | (customer) | `GET /salesforce/flex-invent-check/default-warehouse` | `customerAccount` | |
| `boomi.SalesforceXrefCustomer` | table | — | **NO API** | — | DDL ported to AlloyDB; Boomi populates via direct INSERT/TRUNCATE |
| `boomi.SalesforceXrefProgram` | table | — | **NO API** | — | same |
| `boomi.SalesforceXrefUser` | table | — | **NO API** | — | same; joined inside `SalesforceCustomerV2` to resolve owner Salesforce IDs |
| `boomi.usp_Truncate_SalesforceXrefCustomer` | proc | — | **NO API** | — | Boomi-managed; remains as DB object |
| `boomi.usp_Truncate_SalesforceXrefProgram` | proc | — | **NO API** | — | same |
| `boomi.usp_Truncate_SalesforceXrefUser` | proc | — | **NO API** | — | same |

---

## C. `integration-idb` — `dbo.*`

Sub-sections by treatment: USV business procs (12), Esker outbound procs (4), DBA/utility procs (10, no API), USV views surfaced as endpoints (~10), USV views ported as join inputs (~50), and the ~290 base-table mirror views that are out of scope (repositories will query `d365.*` directly).

### C.1 — USV business procs → existing/new APIs

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `dbo.USVCustomerLookup` | `@CustomerRef NVARCHAR(20)` | `GET /customers?customerRef={@CustomerRef}` | `customerRef` | **HARD DUPLICATE** of `ais.spCustomerLookup` |
| `dbo.USVCustomerLookupByCustRefAndGroup` | `@CustomerRef NVARCHAR(20), @ProgramGroup NVARCHAR(30)` | `GET /customers?customerRef=...&programGroup=...` | `customerRef`, `programGroup` | **HARD DUPLICATE** of `ais.spCustomerLookupByCustomerRefAndGroup` |
| `dbo.USVCustomerLookupByOrgNumAndSegment` | `@OrgNum NVARCHAR(25), @SegmentId NVARCHAR(20)` | `GET /customers?orgNum=...&segmentId=...` | `orgNum`, `segmentId` | new filter combo on `/customers` |
| `dbo.USVCustomerLookupByAltOrgNum` | `@OrgNum NVARCHAR(25), @AltOrgNum NVARCHAR(25), @SegmentId NVARCHAR(20)` | `GET /customers?orgNum=...&altOrgNum=...&segmentId=...` | `orgNum`, `altOrgNum`, `segmentId` | new filter combo on `/customers` |
| `dbo.USVOrderStatusDetail` | `@CustAccount NVARCHAR(20), @OrderNumber NVARCHAR(20), @OrderType INT, @OrderStatus INT = 1, @InvoiceNumber NVARCHAR(20) = '', @Warehouse NVARCHAR(10) = '', @PONumber NVARCHAR(30) = ''` | `GET /order-status/detail` | `customer`, `orderNumber`, `orderType`, `orderStatus`, `invoiceNumber`, `warehouse`, `poNumber` | **HARD DUPLICATE** of `ais.spOrderStatusDetail` |
| `dbo.USVOrderStatusSummary` | `@CustAccount NVARCHAR(20), @OrderType INT, @OrderStatus INT = 1, @Warehouse NVARCHAR(10) = '', @NumberOfRecords INT = 10` | `GET /order-status/summary` | `customer`, `orderType`, `orderStatus`, `warehouse`, `topN` | **HARD DUPLICATE** of `ais.spOrderStatusSummary` |
| `dbo.USVOrderStatusSummaryByInvoiceAccount` | `@InvoiceAccount NVARCHAR(20), @OrderType INT, @OrderStatus INT = 1, @Warehouse NVARCHAR(10) = '', @NumberOfRecords INT = 10` | `GET /order-status/summary/by-invoice-account` | `invoiceAccount`, `orderType`, `orderStatus`, `warehouse`, `topN` | **HARD DUPLICATE** of `ais.USVOrderStatusSummaryByInvoiceAccount` |
| `dbo.USVCancelledOrderDetail` | `@CustAccount NVARCHAR(20), @OrderNumber NVARCHAR(20)` | `GET /order-status/cancelled/{salesId}?customer=...` | `salesId` (path), `customer` | **new endpoint** in OrderStatus |
| `dbo.USVContinentalWarehouses` | `@CustomerAccount NVARCHAR(20)` | `GET /delivery/receipts/continental/warehouses-by-account/{accountNum}` | `accountNum` (path) | **new endpoint** in Delivery; Continental-vendor-specific warehouse list |
| `dbo.USVGetAllWarehouseData` | (no params) | `GET /warehouses/all-with-address` | — | **new endpoint** in Warehouse — returns warehouse + address + phone |
| `dbo.USVGetWarehouseDataByExternalCode` | `@ExternalWarehouseCode NVARCHAR(50)` | `GET /warehouses/by-external-code/{externalCode}` | `externalCode` (path) | **new endpoint** in Warehouse |
| `dbo.USVExtractARVentus` | `@date DATETIME = NULL` (defaults to "yesterday before 5pm, today after") | `GET /finance/ventus/ar-extract?date=...` | `date` (optional) | **new endpoint** in Finance — Ventus AR cash-receipts extract |

### C.2 — Esker outbound procs → Finance API

| Source proc | Parameters | Target API | API params | Notes |
|---|---|---|---|---|
| `dbo.Esker_company_AF` | (no params) | `GET /finance/esker/companies` | — | **QUARANTINED in source** (depends on excluded `v_dirpartytable`) — see Open Q §I.14 |
| `dbo.Esker_Contacts_AF` | `@startdate DATETIME, @enddate DATETIME` | `GET /finance/esker/contacts?start=...&end=...` | `start`, `end` | |
| `dbo.Esker_OutsidePmts_AF` | `@startdate DATETIME, @enddate DATETIME` | `GET /finance/esker/outside-payments?start=...&end=...` | `start`, `end` | **QUARANTINED in source** — same as `Esker_company_AF` |
| `dbo.Esker_WriteOff_AF` | `@startdate DATETIME, @enddate DATETIME` | `GET /finance/esker/write-offs?start=...&end=...` | `start`, `end` | |

### C.3 — DBA / utility procs → no API

These remain as SQL Server / AlloyDB-side maintenance objects. Migrate as-is or replace with AlloyDB-native equivalents; **no API surface**.

| Source proc | Purpose | Treatment |
|---|---|---|
| `dbo.AzureSQLMaintenance` | Index/stats maintenance | DBA — no API; replace with AlloyDB autovacuum/autoanalyze |
| `dbo.CommandExecute` | Ola Hallengren helper | DBA — no API; not needed in AlloyDB |
| `dbo.DatabaseIntegrityCheck` | Ola Hallengren CHECKDB wrapper | DBA — no API; replace with AlloyDB-native checks |
| `dbo.MERGECDC` | CDC merge utility | DBA — no API; AlloyDB CDC story TBD |
| `dbo.SetTableStatus` | DBA/CDC helper | DBA — no API |
| `dbo.sp_dbRolesUsersMap` | Security utility | DBA — no API |
| `dbo.sp_WhoIsActive` | Adam Machanic's diagnostic | DBA — no API; replace with `pg_stat_activity` |
| `dbo.spApplyIndexes` | Index application utility | DBA — no API |
| `dbo.usv_row_counts` | Row count diagnostic | DBA — no API |
| `dbo.usv_RowCounts` | Row count diagnostic | DBA — no API |

### C.4 — Views surfaced as new endpoints

These ~10 views have business meaning and become API endpoints (in addition to the 5 boomi Salesforce views in §B).

| Source view | Target API | API params | Notes |
|---|---|---|---|
| `dbo.USVOpenAR` | `GET /finance/ar/open` | — | open AR rollup |
| `dbo.Esker_USVOpenAR` | `GET /finance/ar/open?scope=esker` | `scope=esker` | Esker-flavored variant of OpenAR; folded into `/finance/ar/open` with discriminator |
| `dbo.usvcustavailcredit` | `GET /customers/{accountNum}/available-credit` AND `GET /finance/customers/{accountNum}/available-credit` | `accountNum` (path) | one view, two endpoints |
| `dbo.usvcuststatement` | `GET /finance/customers/{accountNum}/statement?scope=summary` | `accountNum` (path), `scope` | summary statement |
| `dbo.usvcustinvoicejourstatement` | `GET /finance/customers/{accountNum}/statement?scope=invoice-jour` | `accountNum` (path), `scope` | detailed invoice-journal statement |
| `dbo.USVPNCCUSTTRANSDATAENTITY` | `GET /finance/pnc/customer-transactions` | filters | PNC bank integration |
| `dbo.usvgeneralledgerhierarchy` | `GET /finance/gl/hierarchy` | — | |
| `dbo.usvinboundqueuelog` | `GET /integration/inbound/queue-log` | filters | new Platform endpoint |
| `dbo.usvibsparameters` | `GET /integration/ibs/parameters` | — | new Platform endpoint |
| `dbo.vCustomerContactInfo_SalesForce` | `GET /salesforce/customers/{customerAccount}/contacts` | `customerAccount` (path) | new SalesforceIntegration endpoint |
| `dbo.vDuplicatePrograms` | `GET /programs/data-quality/duplicates` | — | new Program data-quality endpoint |
| `dbo.vProgramsWithNoItems` | `GET /programs/data-quality/no-items` | — | folded under `/programs/data-quality/{check}` |
| `dbo.vProgramTablesWithZeroRecords` | `GET /programs/data-quality/zero-records` | — | folded under `/programs/data-quality/{check}` |

### C.5 — Views as join inputs (no direct API)

These ~50 views are joined inside repository SQL of existing endpoints. They are not exposed as their own endpoints, but they are still the AlloyDB target schema for the appropriate domain. Listed here so consumers know which API endpoint embeds the view's data.

| Source view | Embedded in API | Domain |
|---|---|---|
| `dbo.USVAISCustomerLookupByOrgNumSegmentStagingView` | `GET /customers?orgNum=...` | Customer |
| `dbo.USVCUSTOMERRESPONSIBILITIESEMPLENTITY` | `GET /customers/...` AND `GET /salesforce/employee-responsible` | Customer + SalesforceIntegration |
| `dbo.USVDIRPARTYCONTACTV3ENTITY` | `GET /customers/{accountNum}/addresses/*` | Customer |
| `dbo.USVDIRPARTYPOSTALADDRESSSTAGINGVIEW` | `GET /customers/{accountNum}/addresses/*` | Customer |
| `dbo.USVLOGISTICSCONTACTINFOSTAGINGVIEW` | `GET /customers/{accountNum}/addresses/*` | Customer |
| `dbo.USVLOGISTICSPOSTALADDRESSENTITY` | `GET /customers/{accountNum}/addresses/*` | Customer |
| `dbo.USVLOGISTICSPOSTALADDRESSSTAGINGVIEW` | `GET /customers/{accountNum}/addresses/*` | Customer |
| `dbo.vwDimCustomerContacts` | `GET /customers/...` | Customer |
| `dbo.usvitemchargestable` | `GET /products/...` AND `GET /invoices/...` | Product + Invoice |
| `dbo.usvecoresprodtiresattributes`, `usvecoresprodtiresattributesext`, `usvecoresprodtiresaccessoriesattributes`, `usvecoresprodtubesattributes`, `usvecoresprodlubeschemicalattributes`, `usvecoresprodpartsattributes`, `usvecoresprodexhuastattributes`, `usvecoresprodmicsitemsattributes` | `GET /products/attributes`, `/products/tires/...` | Product |
| `dbo.usvfndcategory` | `GET /products/catalog-codes` | Product |
| `dbo.usvproductexclusionbywhs` | `GET /products/exclusions?warehouse=...` | Product |
| `dbo.usvproductfirstreceiptdate` | `GET /products/...` | Product |
| `dbo.usvprogramtable`, `USVPROGRAMTABLEENTITY` | `GET /programs/...` | Program |
| `dbo.usvprogramcustomer`, `USVPROGRAMCUSTOMERENTITY` | `GET /programs/.../accounts` | Program |
| `dbo.usvprogramproducts`, `USVPROGRAMPRODUCTSTABLEENTITY` | `GET /programs/.../items` | Program |
| `dbo.usvprogramcustprodexclusiontable`, `USVPROGRAMCUSTPRODEXCLUSIONTABLEENTITY` | `GET /products/exclusions?account=...&productGroup=...` | Program |
| `dbo.usvprogramreasoncode` | `POST /programs/rules/within-program/evaluate` | Program |
| `dbo.usvexclusionprogramcustomerproducts` | `GET /products/exclusions` | Program |
| `dbo.usvacquisitiontable` | `GET /programs/...` | Program |
| `dbo.usvsspprogramcustomer` | `GET /vendor-programs/ssp/...` | VendorProgram |
| `dbo.usvsspprogramproducts` | `GET /vendor-programs/ssp/items` | VendorProgram |
| `dbo.usvtpnaonlinecusteligibility` | `GET /vendor-programs/tpna/eligibility/{accountNumber}` | VendorProgram |
| `dbo.usvtpnaonlinedeliveryreceiptreturnheader` | `GET /vendor-programs/tpna/data` | VendorProgram |
| `dbo.usvtpnaonlinedeliveryreceiptreturnline` | `GET /vendor-programs/tpna/data` | VendorProgram |
| `dbo.usvtpnaonlinedeliveryreceiptvendornumseq` | `GET /vendor-programs/tpna/data` | VendorProgram |
| `dbo.usvtpnabatchduplicatetable` | `POST /edi/inbound/810/duplicate-check` (mode=tpna) | EdiInbound |
| `dbo.usvibsinvoicematchdata` | `POST /invoice-matching/match` | InvoiceMatching |
| `dbo.usvreturnsparameters` | `POST /invoice-matching/match` | InvoiceMatching |
| `dbo.usvwarrantyclaimtable` | `POST /invoice-matching/match` | InvoiceMatching |
| `dbo.usvvendorcredittable`, `usvvendorcreditline`, `usvvendorcreditreturntable`, `usvvendorcreditreturnline`, `USVVENDORCREDITRETURNHEADERLINESENTITY` | `POST /invoice-matching/match` AND `GET /vendors/...` | InvoiceMatching + Vendor |
| `dbo.usvsalescommissionresptable` | `GET /vendors/{vendorAccount}/commission-code` | Vendor |
| `dbo.VENDVENDOREXTERNALCODEENTITY` | `GET /vendors/external-codes/{codeClassId}` | Vendor |
| `dbo.usvwarehousepostaladdress` | `GET /warehouses/{warehouseId}/location`, `GET /warehouses/all-with-address` | Warehouse |
| `dbo.usvwarehousetransfersupplywarehouse` | `GET /transfer-orders/...` | TransferOrder |
| `dbo.usvroutetable`, `usvrouteline`, `usvroutedeliveryschedule`, `USVROUTETABLECUSTVIEW` | `GET /delivery/routes/*` | Delivery |
| `dbo.usvsalestrackingnumbers` | `GET /delivery/tracking?number=...` | Delivery |
| `dbo.usvwhsloadlineworkertransaction` | (warehouse operations — not yet exposed) | Warehouse |

### C.6 — Base-table mirror views (OUT OF SCOPE)

The remaining ~290 `dbo.*` views are simple `SELECT * FROM <ax_source_table>` projections of the AX/D365 source schema. They were a query-convenience mirror in the legacy SQL Server stack; they are **NOT being ported**. Repositories query the `d365.*` source schema directly in AlloyDB.

Representative examples (full list in `integration-idb/src/database/sqlserver/Scripts/views/`):

`dbo.custtable`, `dbo.salestable`, `dbo.salesline`, `dbo.custinvoicejour`, `dbo.custinvoicetrans`, `dbo.markuptable`, `dbo.markuptrans`, `dbo.purchtable`, `dbo.purchline`, `dbo.vendtable`, `dbo.vendinvoicejour`, `dbo.vendinvoicetrans`, `dbo.inventtable`, `dbo.inventdim`, `dbo.inventlocation`, `dbo.dirpartytable`, `dbo.dirpartylocation`, `dbo.logisticspostaladdress`, `dbo.hcmworker`, `dbo.hcmposition`, `dbo.dimensionattribute*`, `dbo.ledger*`, `dbo.fiscalcalendar*`, `dbo.ecores*` (~25 ecores variants), `dbo.whs*` (~15 warehouse-extension variants), the ~25 `*ENTITY`-suffixed AX entity views, and many more.

**Repository SQL rewrite rule**: when porting a legacy proc that does `JOIN dbo.custtable CT ON ...` (or unqualified `JOIN custtable CT ON ...`), the rewritten repository SQL becomes `JOIN d365.custtable CT ON ...`. No mirror view in the API schema. See master plan §D.1 / §J.

**No API endpoints** for any object in this category — they have no business semantics beyond "snapshot of an AX table."

---

## D. `rudi-idb` — `rudi.*`

All 16 procs and the single view are surfaced. 12 fold into existing APIs (Customer, Vendor, Delivery, Invoice, Finance), 4 COMPASSValidate procs become the new RudiCompass API, and the collateral view becomes a Finance endpoint.

| Source object | Type | Parameters | Target API | API params | Notes |
|---|---|---|---|---|---|
| `rudi.COMPASSValidateCustomer` | proc | `@D365Company VARCHAR(5), @Vendor VARCHAR(10)` | `GET /compass/customers/validate?legalEntity={@D365Company}&vendor={@Vendor}` | `legalEntity`, `vendor` | RudiCompass |
| `rudi.COMPASSValidateCustomerInvoice` | proc | `@D365Company VARCHAR(5), @Customer VARCHAR(10), @Invoice VARCHAR(20)` | `GET /compass/customers/{customer}/invoices/{invoice}/validate?legalEntity=...` | path: `customer`, `invoice`; query: `legalEntity` | RudiCompass |
| `rudi.COMPASSValidateVendorBankIdMop` | proc | `@D365Company VARCHAR(5), @Vendor VARCHAR(10), @VendorBankID VARCHAR(10), @MoP VARCHAR(10)` | `GET /compass/vendors/{vendor}/bank-validate?legalEntity=...&bankId=...&mop=...` | path: `vendor`; query: `legalEntity`, `bankId`, `mop` | RudiCompass; MoP example: `'Wire Trf'` |
| `rudi.COMPASSValidateVendorInvoice` | proc | `@D365Company VARCHAR(5), @Vendor VARCHAR(10), @Invoice VARCHAR(20)` | `GET /compass/vendors/{vendor}/invoices/{invoice}/validate?legalEntity=...` | path: `vendor`, `invoice`; query: `legalEntity` | RudiCompass |
| `rudi.GetAccountDeliverySettings` | proc | `@Company nvarchar(4), @CustomerAccount nvarchar(20)` | `GET /delivery/customers/{accountNum}/settings?legalEntity={@Company}` | path: `accountNum`; query: `legalEntity` | Delivery — drives FTP/email/EDI routing decisions |
| `rudi.GetAllInactiveCustomerAccounts` | proc | `@Company nvarchar(4)` | `GET /customers/inactive?legalEntity={@Company}` | `legalEntity` | Customer |
| `rudi.GetCustomerAccountAvailableCredit` | proc | `@Company nvarchar(4), @CustomerAccount nvarchar(20)` | `GET /customers/{accountNum}/available-credit?legalEntity={@Company}` AND `GET /finance/customers/{accountNum}/available-credit?legalEntity={@Company}` | path: `accountNum`; query: `legalEntity` | Customer + Finance (same backing data) |
| `rudi.GetCustomerOpenTransactions` | proc | `@Company nvarchar(4), @CustomerAccount nvarchar(20), @DueDateFrom datetime, @DueDateTo datetime` | `GET /finance/customers/{accountNum}/open-transactions?legalEntity={@Company}&dueDateFrom=...&dueDateTo=...` | path: `accountNum`; query: `legalEntity`, `dueDateFrom`, `dueDateTo` | Finance |
| `rudi.GetFinancialDimensions` | proc | `@Company nvarchar(4)` | `GET /finance/dimensions?legalEntity={@Company}` | `legalEntity` | Finance — returns MainAccount + others as `(DimensionType, Value, Name)` rows |
| `rudi.GetInvoicePostedDate` | proc | `@InvoiceType nvarchar(2) /* AR/AP/CC */, @PostedDateInput rudi.PostedDateInputTableType READONLY` | `POST /invoices/posted-dates` | body: `{invoiceType: "AR"\|"AP"\|"CC", invoiceKeys: [...]}` | Invoice — **POST** because of TVP; see Open Q §I.12 |
| `rudi.GetVendorBlockedStatus` | proc | `@Company nvarchar(4), @VendorAccount nvarchar(20)` | `GET /vendors/{vendorAccount}/blocked-status?legalEntity={@Company}` | path: `vendorAccount`; query: `legalEntity` | Vendor |
| `rudi.GetVendorDefaultBankAccount` | proc | `@DataAreaID NVARCHAR(5), @AccountNum NVARCHAR(20)` | `GET /vendors/{vendorAccount}/bank-account/default?legalEntity={@DataAreaID}` | path: `vendorAccount`; query: `legalEntity` | Vendor |
| `rudi.GetVendorDetails` | proc | `@Company nvarchar(4), @CustomerAccount nvarchar(20)` *(param mis-named — it's the vendor account)* | `GET /vendors/{vendorAccount}?legalEntity={@Company}` | path: `vendorAccount`; query: `legalEntity` | Vendor — see Open Q §I.11 |
| `rudi.GetVendorPaymentMethod` | proc | `@Company nvarchar(4), @VendorAccount nvarchar(20)` | `GET /vendors/{vendorAccount}/payment-method?legalEntity={@Company}` | path: `vendorAccount`; query: `legalEntity` | Vendor |
| `rudi.GetVendorRemainingBalance` | proc | `@D365Company VARCHAR(20), @MAINACCOUNT VARCHAR(5), @DEPARTMENT VARCHAR(3), @LOCATION VARCHAR(4), @CUSTOMER VARCHAR(6)` | `GET /finance/vendors/remaining-balance?legalEntity=...&mainAccount=...&department=...&location=...&customer=...` | all query | Finance |
| `rudi.GetVoucherPostedDate` | proc | `@Company nvarchar(4), @VoucherNumber nvarchar(20)` | `GET /finance/vouchers/{voucherNumber}/posted-date?legalEntity={@Company}` | path: `voucherNumber`; query: `legalEntity` | Finance |
| `rudi.OUTSTANDINGFIRMFIXEDCOLLATERALDETAIL` | view | (view, no params) | `GET /finance/collateral/firm-fixed-outstanding` | optional: `accountNum`, `dateRange` | Finance |

---

## E. Hard-duplicate consolidation summary

These objects appear in two source DBs with identical (or near-identical) bodies. **Consolidate to one canonical implementation** in the target API; drop the duplicate source after cutover.

| Pair | Target API | Action |
|---|---|---|
| `ais.spCustomerLookup` ⇔ `dbo.USVCustomerLookup` | `GET /customers?customerRef=...` | Implement once; drop dbo copy |
| `ais.spCustomerLookupByCustomerRefAndGroup` ⇔ `dbo.USVCustomerLookupByCustRefAndGroup` | `GET /customers?customerRef=...&programGroup=...` | Implement once; drop dbo copy |
| `ais.spOrderStatusDetail` (and v3-v15) ⇔ `dbo.USVOrderStatusDetail` | `GET /order-status/detail` | Implement once from highest-confirmed `vN`; drop dbo copy |
| `ais.spOrderStatusSummary` ⇔ `dbo.USVOrderStatusSummary` | `GET /order-status/summary` | Implement once; drop dbo copy |
| `ais.USVOrderStatusSummaryByInvoiceAccount` ⇔ `dbo.USVOrderStatusSummaryByInvoiceAccount` | `GET /order-status/summary/by-invoice-account` | Implement once; drop dbo copy |
| `rudi.GetCustomerAccountAvailableCredit` ⇔ `dbo.usvcustavailcredit` view | `GET /customers/{accountNum}/available-credit` | Different shapes (proc vs. view); implement once over the view, deprecate the proc |

**Before consolidating**, confirm the bodies are byte-identical (or document any drift) — see Open Q §I.10.

---

## F. Reverse index — by API endpoint

Listed in alphabetical order by endpoint path. Use this to look up "what source procs/views does endpoint X cover?".

| API endpoint | Source objects |
|---|---|
| `GET /backorders/expiring` | `ais.spGetExpiringBackOrders` |
| `GET /backorders/summary` | `ais.spBackorderSummary` (V3 canonical) |
| `GET /compass/customers/{customer}/invoices/{invoice}/validate` | `rudi.COMPASSValidateCustomerInvoice` |
| `GET /compass/customers/validate` | `rudi.COMPASSValidateCustomer` |
| `GET /compass/vendors/{vendor}/bank-validate` | `rudi.COMPASSValidateVendorBankIdMop` |
| `GET /compass/vendors/{vendor}/invoices/{invoice}/validate` | `rudi.COMPASSValidateVendorInvoice` |
| `GET /customers` | `ais.spCustomerLookup`, `ais.spCustomerLookupByCustomerRef`, `ais.spCustomerLookupByCustomerRefAndGroup`, `dbo.USVCustomerLookup`, `dbo.USVCustomerLookupByCustRefAndGroup`, `dbo.USVCustomerLookupByOrgNumAndSegment`, `dbo.USVCustomerLookupByAltOrgNum` |
| `GET /customers/account-info` | `ais.spGetAccountInfo*` (12 variants), `ais.spGetMavisAccountsByIBSAccountNum` |
| `GET /customers/{accountNum}/addresses/by-role` | `ais.spGetPostalAddressByRole` |
| `GET /customers/{accountNum}/addresses/primary` | `ais.spGetPrimaryPostalAddress` |
| `GET /customers/{accountNum}/available-credit` | `rudi.GetCustomerAccountAvailableCredit`, `dbo.usvcustavailcredit` view |
| `GET /customers/{accountNum}/cc-surcharge-program` | `ais.spCCSurchargeProgramLookup` (canonical home is Program) |
| `GET /customers/by-program/{programId}` | `ais.spGetCustomersByProgramId` |
| `GET /customers/created-since` | `ais.spGetCustomersByCreatedDateTime` |
| `GET /customers/credit-card` | `ais.spGetCreditCardCustomers` |
| `GET /customers/customer-ref` | `ais.spGetCustomerRefByProgramAndAccount` |
| `GET /customers/inactive` | `rudi.GetAllInactiveCustomerAccounts` |
| `GET /customers/{invoiceAccount}/children` | `ais.spGetChildAccountsByInvoiceAccountAndAccountNum` |
| `GET /customers/store-code-xrefs` | `ais.spGetCustStoreCodeXRefs`, `ais.spGetDiscountTireStoreCodeXRefs`, `ais.spGetTireRackStoreCodeXRefs`, `ais.spGetTireRackTWStoreCodeXRefs` |
| `GET /customers/1p-export` | `ais.spGetCustomerDataFor1P` |
| `GET /delivery/customers/{accountNum}/settings` | `rudi.GetAccountDeliverySettings` |
| `GET /delivery/freight-tracking/goodyear-ecom` | `ais.spGetGoodyearEComFreightTracking` |
| `GET /delivery/modes` | `ais.spGetDeliveryModes` |
| `GET /delivery/modes/by-account/{accountNum}` | `ais.spRWADeliveryModesForAccount` |
| `GET /delivery/receipts` | `ais.spGetContinentalDeliveryReceipts`, `ais.spGetPirelliDeliveryReceipts`, `ais.spGetYokohamaDeliveryReceipts` |
| `GET /delivery/receipts/continental/warehouses-by-account/{accountNum}` | `dbo.USVContinentalWarehouses` |
| `GET /delivery/routes/{routeId}/master-code` | `ais.spGetMasterRouteCodeFromRouteId` |
| `GET /delivery/routes/truck-names` | `ais.spGetTruckRouteNamesForAccounts` |
| `GET /delivery/tracking` | `ais.spFindTrackingNum`, `dbo.usvsalestrackingnumbers` view |
| `POST /edi/inbound/810/duplicate-check` | `ais.sp810InboundCheckForDuplicate{3Way,Misc,PassThru,Ssp,Tpna}`, `dbo.usvtpnabatchduplicatetable` view |
| `GET /edi/inbound/810/bank-data/{accountNum}` | `ais.sp810GetAccountBankData` |
| `GET /edi/inbound/810/customer-ref` | `ais.sp810InboundLookupCustomerRefForProgram` |
| `GET /edi/inbound/810/invoice-exists` | `ais.sp810InboundLookupInvoiceExists` |
| `GET /edi/inbound/810/trading-partners` | `ais.spGetTradingPartnerCrossRefFor810` |
| `GET /edi/inbound/distro/duplicate-check` | `ais.spCheckForRecentDistroDuplicateMessage` |
| `GET /edi/outbound/810/{salesId}` | `ais.sp810OutboundLookupBySalesId`, `ais.sp810OutboundLookupMarkupsBySalesId`, `ais.sp810OutboundLookupRestockFeesBySalesId` |
| `GET /edi/outbound/850` | `ais.sp850OutboundLookupBy{AccountAndDate,PONumbers,SalesId,SalesIDList}` |
| `GET /edi/outbound/855/{salesId}` | `ais.sp855OutboundLookupBySalesId` |
| `GET /edi/outbound/855/{salesId}/confirm-doc-num` | `ais.sp855OutboundLookupConfirmDocNum` |
| `GET /edi/outbound/855/{salesId}/invoice-account` | `ais.sp855OutboundLookupInvoiceAccountBySalesId` |
| `GET /edi/outbound/856/{salesId}` | `ais.sp856OutboundLookupBySalesId`, `ais.sp856OutboundCombinedASNLookupBySalesId` |
| `GET /eta/customers/account-info` | `eta.spGetAccountInfoWithAccountNum` |
| `GET /eta/routes` | `eta.spGetAllRoutes` |
| `GET /eta/routes/names-by-account` | `eta.spGetRouteNamesForAccounts`, `eta.spGetRouteNamesForAccountsAndWarehouse` |
| `GET /eta/transfer-routes` | `eta.spGetTransferRoutesForWarehouses` |
| `GET /eta/transfer-routes/by-warehouse/{warehouseId}` | `eta.spGetCustomerTransferRoutesForWarehouse` |
| `GET /eta/warehouses/connecting` | `eta.spGetConnectingWarehouses` |
| `GET /finance/ar/open` | `dbo.USVOpenAR`, `dbo.Esker_USVOpenAR` (with `?scope=esker`) |
| `GET /finance/collateral/firm-fixed-outstanding` | `rudi.OUTSTANDINGFIRMFIXEDCOLLATERALDETAIL` view |
| `GET /finance/customers/{accountNum}/available-credit` | `rudi.GetCustomerAccountAvailableCredit`, `dbo.usvcustavailcredit` view |
| `GET /finance/customers/{accountNum}/open-transactions` | `rudi.GetCustomerOpenTransactions` |
| `GET /finance/customers/{accountNum}/statement` | `dbo.usvcuststatement`, `dbo.usvcustinvoicejourstatement` (via `?scope=`) |
| `GET /finance/dimensions` | `rudi.GetFinancialDimensions` |
| `GET /finance/esker/companies` | `dbo.Esker_company_AF` *(quarantined)* |
| `GET /finance/esker/contacts` | `dbo.Esker_Contacts_AF` |
| `GET /finance/esker/outside-payments` | `dbo.Esker_OutsidePmts_AF` *(quarantined)* |
| `GET /finance/esker/write-offs` | `dbo.Esker_WriteOff_AF` |
| `GET /finance/gl/hierarchy` | `dbo.usvgeneralledgerhierarchy` view |
| `GET /finance/pnc/customer-transactions` | `dbo.USVPNCCUSTTRANSDATAENTITY` view |
| `GET /finance/ventus/ar-extract` | `dbo.USVExtractARVentus` |
| `GET /finance/vendors/remaining-balance` | `rudi.GetVendorRemainingBalance` |
| `GET /finance/vouchers/{voucherNumber}/posted-date` | `rudi.GetVoucherPostedDate` |
| `GET /integration/azure/outbound/info` | `ais.spGetAzureOutboundInfo` |
| `GET /integration/azure/outbound/requests` | `ais.spGetAzureOutboundRequests` |
| `GET /integration/azure/outbound/errors` | `ais.spGetAzureOutBoundRequestErrors` |
| `GET /integration/azure/queue/errors` | `ais.spGetAzureQueueErrors` |
| `GET /integration/ibs/parameters` | `dbo.usvibsparameters` view |
| `GET /integration/inbound/queue-log` | `dbo.usvinboundqueuelog` view |
| `GET /invoices` | `ais.spGetInvoiceData*`, `ais.spGetInvoiceDataByVendor_Michelin` (and other vendor variants) |
| `GET /invoices/{invoiceId}` | `ais.spGetInvoiceMetaData` |
| `GET /invoices/{invoiceId}/lines/by-line-code` | `ais.GetInvoiceDetailsByLineCode` |
| `GET /invoices/{invoiceId}/markups` | `ais.spGetInvoiceJournalMarkups` |
| `GET /invoices/{invoiceId}/remainder` | `ais.spGetInvoiceRemainder` (v4 canonical) |
| `GET /invoices/account-resolution` | `ais.spGetInvoiceAccountByProgramIdAndAccountNumber`, `ais.spGetInvoiceAccountByProgramIdItemNumberAndCustomerAccount` |
| `GET /invoices/count` | `ais.spGetInvoiceCount` |
| `GET /invoices/fedex-export` | `ais.spGetFedExInvoiceData` |
| `POST /invoices/posted-dates` | `rudi.GetInvoicePostedDate` |
| `GET /invoices/sales-orders` | `ais.spGetSalesOrdersByInvoiceNumbers` |
| `GET /invoices/summary` | `ais.AllInvoicesSummary` |
| `POST /invoice-matching/match` | `ais.spRWAInvoiceMatchingService` |
| `GET /invoice-matching/invoice-data` | `ais.spRWAInvoiceData` |
| `GET /invoice-matching/return-orders/{returnId}` | `ais.spRWAGetReturnOrderData` |
| `GET /invoice-matching/return-reason-types` | `ais.spRWAReturnReasonType` |
| `GET /invoice-matching/items/by-item-group/{groupId}` | `ais.spRWAItemsByItemGroup` |
| `GET /order-status/cancelled/{salesId}` | `dbo.USVCancelledOrderDetail` |
| `GET /order-status/detail` | `ais.spOrderStatusDetail` (v15 canonical), `dbo.USVOrderStatusDetail` (duplicate) |
| `GET /order-status/{salesId}/tracking` | `ais.spOrderStatusDetailTracking` |
| `GET /order-status/summary` | `ais.spOrderStatusSummary`, `dbo.USVOrderStatusSummary` (duplicate) |
| `GET /order-status/summary/by-invoice-account` | `ais.USVOrderStatusSummaryByInvoiceAccount`, `ais.USVOrderStatusSummaryByInvoiceAccountAndDateRange`, `dbo.USVOrderStatusSummaryByInvoiceAccount` (duplicate) |
| `GET /products/...` | (see §A.9 for the full list of 19 endpoints) |
| `GET /programs/...` | (see §A.10) |
| `GET /programs/data-quality/{check}` | `dbo.vDuplicatePrograms`, `dbo.vProgramsWithNoItems`, `dbo.vProgramTablesWithZeroRecords` |
| `GET /purchase-orders/...` | (see §A.4) |
| `GET /reference/holidays` | `ais.spGetHolidays` |
| `GET /sales-orders` | `ais.spGetSalesOrder*` (10 variants), `ais.spGetSalesOrderByPO`, `ais.spGetSalesOrderByWaveId` |
| `GET /sales-orders/{salesId}` | `ais.spGetOrderDetailBySO`, `ais.GetOrderDetailForDiscountTire` (with discriminator) |
| `GET /sales-orders/{salesId}/hold` | `ais.spCheckSalesOrderHold` |
| `GET /sales-orders/{salesId}/whs-lines` | `ais.spGetWhsSalesLine` |
| `GET /salesforce/cases` | `boomi.SalesforceCaseDetail` view |
| `GET /salesforce/customers` | `boomi.SalesforceCustomerV2` view |
| `GET /salesforce/customers/{customerAccount}` | `boomi.SalesforceCustomerV2` view (path-keyed) |
| `GET /salesforce/customers/{customerAccount}/contacts` | `dbo.vCustomerContactInfo_SalesForce` view |
| `GET /salesforce/employee-responsible` | `boomi.SalesforceEmployeeResponsible` view, `dbo.USVCUSTOMERRESPONSIBILITIESEMPLENTITY` view |
| `GET /salesforce/flex-invent-check/default-warehouse` | `boomi.FlexInventCheck_DefaultWarehouse` view |
| `GET /salesforce/warehouses` | `boomi.SalesforceWarehouse` view |
| `GET /transfer-orders/{transferId}` | `ais.spGetTransferOrderDetails` |
| `GET /transfer-orders/{transferId}/transport-note` | `ais.spGetTransferOrderTransportNote` |
| `GET /vendor-programs/...` | (see §A.8 for the full list of 16 endpoints) |
| `GET /vendor-return-orders/{returnId}` | `ais.spGetVendorReturnOrderDeatils` *(typo preserved in source)* |
| `GET /vendors` | `ais.spFindVendorMFG3CodeForAccount`, `ais.spFindVendorWithIBSAccount` |
| `GET /vendors/{vendorAccount}` | `rudi.GetVendorDetails` |
| `GET /vendors/{vendorAccount}/bank-account/default` | `rudi.GetVendorDefaultBankAccount` |
| `GET /vendors/{vendorAccount}/blocked-status` | `rudi.GetVendorBlockedStatus` |
| `GET /vendors/{vendorAccount}/commission-code` | `ais.sp810InboundLookupVendorCommissionCode`, `dbo.usvsalescommissionresptable` view |
| `GET /vendors/{vendorAccount}/items` | `ais.sp810InboundLookupItemNumberForVendor`, `ais.sp810InboundGetVendorItemForPoNumberAndItemId` |
| `GET /vendors/{vendorAccount}/payment-method` | `rudi.GetVendorPaymentMethod` |
| `GET /vendors/{vendorAccount}/payment-terms` | `ais.spGetPaymentTermsByVendorAccount` |
| `GET /vendors/{vendorAccount}/warehouse-external-codes` | `ais.spGetVendorWarehouseExternalCodes` |
| `GET /vendors/{vendorAccount}/your-account-number` | `ais.spGetYourAccountNumForVendor` |
| `GET /vendors/external-codes/{codeClassId}` | `ais.spVendorExternalCodeLookupByCodeClassId`, `dbo.VENDVENDOREXTERNALCODEENTITY` view |
| `GET /vendors/loyalty-return-reason-codes` | `ais.VendorLoyaltyReturnReasonCodes` |
| `GET /vendors/wd-non-signatory` | `ais.spGetWDNonSig` (vendor `'100687'` hardcoded — flag for parameterization) |
| `GET /warehouses` | `ais.spGetWarehouseList`, `ais.spGetWarehouseListForAccount`, `ais.spGetWarehouseCodesForPartner` |
| `GET /warehouses/all-with-address` | `dbo.USVGetAllWarehouseData` |
| `GET /warehouses/backups` | `ais.spGetWarehouseBackups`, `ais.spGetWarehouseBackupsFromPrimaryWarehouse` |
| `GET /warehouses/by-account` | `ais.spGetWarehouseByAccountInfo*` (and replenish-mode variant), `ais.spGetWarehouseForAccountAndPurchId` |
| `GET /warehouses/by-external-code/{externalCode}` | `dbo.USVGetWarehouseDataByExternalCode` |
| `GET /warehouses/invent-location/{locationId}` | `ais.spGetInventLocationRecord` |
| `GET /warehouses/{warehouseId}/is-ibs` | `ais.spIsIBSWarehouse` |
| `GET /warehouses/{warehouseId}/location` | `ais.spFindWarehouseData`, `ais.spWarehouseLocationData`, `dbo.usvwarehousepostaladdress` view |
| `GET /warehouses/primary/{customerAccount}` | `ais.spGetPrimaryWarehouseByCustomerAccount` |
| `GET /warehouses/secondary/{customerAccount}` | `ais.spGetSecondaryWarehouses` |

---

## G. Migration usage

**For developers**: when you find a call to a SQL Server proc/view in your codebase, search this doc for the source object name (e.g. `dbo.USVOrderStatusDetail`) and replace the DB call with the corresponding API request. For consolidated endpoints, the legacy parameter set maps to the API's filter set as described in the "API params" column.

**For API implementers**: when scaffolding a new API, find your domain in `MASTER_IMPLEMENTATION_PLAN.md` §C, then use this doc to enumerate the source procs/views your API consolidates and to identify which legacy parameters need to map onto the unified endpoint contract.

**For data-platform / DBA**: the API repositories will query the `d365.*` source schema directly in AlloyDB — no per-API mirror layer. Confirm the D365 source tables listed in §C.6 are present in AlloyDB at the expected schema/column shape (CDC pipeline, DMS replication, etc.) before any API project starts implementation. The ~290 integration-idb mirror views are NOT being ported — see Open Question §I.15 in the master plan.
