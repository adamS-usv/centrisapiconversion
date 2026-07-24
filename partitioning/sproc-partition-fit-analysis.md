# Partition ↔ Sproc-Input Fit Analysis

**Companion to** `phase-0-foundation.md`, `phase-2-masters.md`, `phase-3-dependent-reads.md`,
`phase-4-composite-finance.md`. **Profiled/analyzed:** 2026-06-04.

---

## 1. Purpose & method

The per-phase partition recommendations were derived from **data shape** — which column on each
large `d365.*` table has the cleanest multi-year spread, the highest `DataAreaId` cardinality, or
(failing a usable business date) the most uniform `RecId` distribution. See the decision framework
in `README.md`.

A partition key only reduces I/O if queries **filter on it** (partition pruning). This document
asks the complementary question the profiling pass did not: **do the stored procedures and views
that actually read these tables filter on the proposed partition key?** If they reach the table by
some other column, the partitions still store the data correctly but the planner must scan **every**
partition — and for point lookups that is *slower* than an unpartitioned B-tree.

**Method.** We grepped the four IDB repos — `ais-idb`, `boomi-idb`, `rudi-idb`, `integration-idb`
(`src/database/sqlserver/Scripts/{sprocs,views,functions}`) — for every partitioned table name
(catching `d365.x`, `dbo.x`, unqualified `x`, and `v_*` wrapper views), then read the JOIN/WHERE
regions to classify the predicate on the partition-key column. Parameter mappings were
cross-referenced against `SPROC_VIEW_API_MAPPING.md`.

**Two lenses** (both reported, per stakeholder direction):

- **Legacy** — the sproc bodies *as written today*.
- **Future API** — the consolidated REST endpoints in `SPROC_VIEW_API_MAPPING.md`, where search
  endpoints add `startDate`/`endDate` and every endpoint accepts `legalEntity` → `DataAreaId`
  (master plan §D.2).

**Verdict vocabulary** (per table, per lens):

| Verdict | Meaning |
|---|---|
| **PRUNES** | Partition-key column is filtered by an input parameter (sargable equality/range). |
| **PARTIAL** | Key filtered only in *some* consumers, or only as a join-equality / constant, not an input range. |
| **NO PRUNE** | Key never filtered; queries hit all partitions. |
| **UNUSED** | No reference found in the four repos (see caveat below). |

> **Scope caveat.** "UNUSED" / "no consumer" means *no reference in these four repos*. `ais-idb`
> alone has ~297 sproc files (many dated/backup/`_vN` variants). Tables may still be read by
> external consumers (Boomi flows, Esker, Ventus, ad-hoc reporting) or by future APIs. Treat
> UNUSED as "defer / confirm," not "delete."

---

## 2. Headline finding

**The access pattern and the partition key disagree almost everywhere.** Sprocs reach these tables
by **business keys and RecId/FK joins** — `INVOICEID`, `SALESID`, `CUSTACCOUNT`, `PURCHID`,
`INVENTTRANSID`, `RECID`, `PROGRAMID`, `INVOICEACCOUNT` — not by the proposed partition-key date
column. Two highest-traffic procs, verified directly:

`ais.spGetInvoiceData` (→ `GET /invoices`):
```sql
-- custinvoicejour  (recommended: RANGE invoicedate + LIST DataAreaId)
WHERE CIJ.INVOICEID = @InvoiceId --AND CIJ.DATAAREAID = @LegalEntity   -- date absent; DataAreaId commented out
-- custinvoicetrans (recommended: RANGE invoicedate + LIST DataAreaId)
WHERE CITR.INVOICEID = @InvoiceId AND CITR.DATAAREAID = @LegalEntity    -- DataAreaId ACTIVE; invoicedate still absent
```

`ais.spOrderStatusDetail` (→ `GET /order-status/detail`):
```sql
FROM SalesTable AS ST                                                  -- salestable: RANGE deliverydate + LIST DataAreaId
  JOIN SalesLine AS SL ON SL.SALESID = ST.SALESID                      -- salesline:  RANGE shippingdaterequested + LIST DataAreaId
  JOIN InventTransOrigin ITRANSORIGIN ON ITRANSORIGIN.INVENTTRANSID = SL.INVENTTRANSID
  LEFT JOIN InventTrans ITRANS ON ITRANS.INVENTTRANSORIGIN = ITRANSORIGIN.RECID AND ITRANS.STATUSISSUE <= 3
WHERE ST.CUSTACCOUNT = @CustAccount                                    -- no deliverydate, no shippingdate, no datephysical, no DataAreaId
```

Fit by partition type:

| Type | # tables | Legacy verdict | Why |
|---|---:|---|---|
| **RANGE by date** | ~35 | mostly **NO PRUNE** | The date column rarely appears in a predicate. The main exception is the WHS EDI date-window procs. (`USVExtractARVentus`, previously an exception, is now decommissioned.) |
| **LIST by DataAreaId** | 11 | **PARTIAL** | The only dimension that aligns. Filtered in `rudi.*` and PO procs; **commented out** in many `ais.*` Invoice/OrderStatus procs. |
| **HASH by RecId** | ~20 | **NO PRUNE** | Tables entered via business/FK columns, never `RECID = <literal>`. HASH buys scan parallelism, not pruning. |

**Interpretation.** The design is implicitly optimized for the **future date-range + legal-entity
search APIs**, not the legacy point-lookup sprocs. That is a defensible bet — but it must be stated
explicitly, and the point-lookup regression must be mitigated (see §5).

---

## 3. Verdict matrix

Legend: **PK** = partition key/type. **Legacy** = verdict vs. current sprocs. **API** = verdict vs.
the consolidated endpoint contract in `SPROC_VIEW_API_MAPPING.md`. **DAI** = is `DataAreaId`
filtered on this table by any consumer? (`param` / `const` / `commented` / `no` / `—` n/a).

### Phase 0 — Foundation

| Table | PK | Type | Consumers (repo) | Legacy | API | DAI | Notes |
|---|---|---|---|---|---|---|---|
| `sysuserlog` | createddatetime | RANGE | none found | UNUSED | UNUSED | — | System log; no IDB consumer. Defer. |

### Phase 2 — Masters

| Table | PK | Type | Consumers (repo) | Legacy | API | DAI | Notes |
|---|---|---|---|---|---|---|---|
| `whsworkline` | modifieddatetime | RANGE | `sp856OutboundCombinedASNLookupBySalesId`, `spGetSalesOrderByWaveId` (ais) | PARTIAL | PARTIAL | no | sp856 filters `ModifiedDateTime >= @LoadModifiedDate AND < @LoadModifiedLTDate`; WaveId proc joins by `WORKID` only. |
| `whsworktable` | modifieddatetime | RANGE | `sp856…ASN…`, `spGetSalesOrderByWaveId` (ais) | PARTIAL | PARTIAL | no | Same split: date-window in sp856, none in WaveId proc. |
| `whsloadline` | modifieddatetime | RANGE | `sp856…ASN…`, `sp855OutboundLookupBySalesId` (ais) | PARTIAL | PARTIAL | no | sp856 filters `wll.ModifiedDateTime >= @LoadModifiedDate`; sp855 joins by `InventTransId`. |
| `whsloadtable` | modifieddatetime | RANGE | `sp856…ASN…` (ais) | **PRUNES** | PRUNES | no | Consistent `wlt.ModifiedDateTime >= @LoadModifiedDate AND < @LoadModifiedLTDate`. Best-fit RANGE table in the set. |
| `whsshipmenttable` | modifieddatetime | RANGE | none found | UNUSED | PARTIAL | — | Defer; future Warehouse/OrderStatus API may date-filter. |
| `whsworklinecyclecount` | RecId | HASH | none found | UNUSED | UNUSED | — | Defer. |
| `inventdim` | modifieddatetime | RANGE | `spGetPOLineDataForBoomi` (ais) + many joins | **NO PRUNE** | NO PRUNE | no | Always joined by `InventDimId`. **Column mismatch** — see §4. |
| `ecoresvalue` | modifieddatetime | RANGE | `spGetAllProductAttributes`, `spGetPirelliDeliveryReceipts` (ais) | **NO PRUNE** | NO PRUNE | no | Joined by `RECID` via `v_ecoresvalue`. Date never filtered. |
| `ecorestextvalue` | modifieddatetime | RANGE | `spGetAllProductAttributes` (commented) | NO PRUNE | NO PRUNE | no | Superseded by `v_ecoresvalue`; date never filtered. |
| `ecoresattributevalue` | RecId | HASH | `spGetAllProductAttributes`, `spGetPirelliDeliveryReceipts` (ais) | NO PRUNE | NO PRUNE | no | Filtered by `ATTRIBUTE`/`INSTANCEVALUE`, never `RECID`. |
| `ecoresinstancevalue` | RecId | HASH | `spGetAllProductAttributes` (ais) | NO PRUNE | NO PRUNE | no | Joined by `PRODUCT`/`ITEMID`, never `RECID`. |
| `usvexclusionprogramcustomerproducts` | RecId | HASH | `spGetExclusionsByAccountNumber` (ais) | NO PRUNE | NO PRUNE | no | Filtered by `INVOICEACCOUNT`. |
| `usvecoresprodtiresattributes` | RecId | HASH | none found (view-only) | UNUSED | UNUSED | — | 8 product-attribute catalogs; no IDB consumer. Defer. |
| `usvecoresprodpartsattributes` | RecId | HASH | none found | UNUSED | UNUSED | — | " |
| `usvecoresprodtubesattributes` | RecId | HASH | none found | UNUSED | UNUSED | — | " |
| `usvecoresprodlubeschemicalattributes` | RecId | HASH | none found | UNUSED | UNUSED | — | " |
| `usvecoresprodtiresaccessoriesattributes` | RecId | HASH | none found | UNUSED | UNUSED | — | " |
| `usvecoresprodmicsitemsattributes` | RecId | HASH | none found | UNUSED | UNUSED | — | " |
| `usvecoresprodexhuastattributes` | RecId | HASH | none found | UNUSED | UNUSED | — | " |
| `usvecoresprodtiresattributesext` | RecId | HASH | none found | UNUSED | UNUSED | — | " |

### Phase 3 — Dependent reads

| Table | PK | Type | Consumers (repo) | Legacy | API | DAI | Notes |
|---|---|---|---|---|---|---|---|
| `inventtrans` | datephysical | RANGE | `spOrderStatusDetail`, `spGetInvoiceRemainder*`, +~25 (ais) | **NO PRUNE** | NO PRUNE | rare | Joined by `INVENTTRANSORIGIN`/`STATUSISSUE`; `datephysical` never filtered. |
| `inventsum` | RecId | HASH | few (ais) | NO PRUNE | NO PRUNE | no | Accessed by `ITEMID` + dimensions, never `RECID`. |
| `inventtransorigin` | RecId | HASH | `spOrderStatusDetail`, `spGetInvoiceRemainder*` (ais) | NO PRUNE* | NO PRUNE* | no | Entered by `INVENTTRANSID`; child `inventtrans` joins by `RECID` → *partition-wise join only*, no standalone prune. |
| `inventtransoriginsalesline` | RecId | HASH | minimal (ais) | NO PRUNE | NO PRUNE | no | Joined by FK, not `RECID`. |
| `vendtrans` | transdate | RANGE+LIST | `COMPASSValidateVendorInvoice` (rudi) | **NO PRUNE** | PARTIAL | param | `WHERE vt.DATAAREAID=@D365Company AND vt.ACCOUNTNUM=@Vendor AND vt.INVOICE=@Invoice` — DataAreaId prunes LIST; `transdate` absent. |
| `custinvoicetrans` | invoicedate | RANGE+LIST | `spGetInvoiceData`, `spGetInvoiceRemainderv4` (ais) | PARTIAL | PRUNES | param | DataAreaId active (`=@LegalEntity`); `invoicedate` only as join-equality to `custinvoicejour`, not a param range. |
| `custtrans` | modifieddatetime | LIST+RANGE | `COMPASSValidateCustomerInvoice` (rudi) [`USVExtractARVentus` DECOMMISSIONED] | PARTIAL | PARTIAL | param | DataAreaId filtered (param in rudi). Date col switched to `modifieddatetime` 2026-07-24 (verified clean); the old Ventus `createddatetime` mismatch is moot — consumer retired. |
| `custinvoicejour` | invoicedate | RANGE+LIST | `spGetInvoiceData`, `spRWAInvoiceData*`, `spOrderStatusDetail` (ais) | **NO PRUNE** | PRUNES | commented | Lookup by `INVOICEID`/`RECID`; DataAreaId commented out; `invoicedate` absent. Future `/invoices?startDate&endDate&legalEntity` prunes. |
| `vendsettlement` | transdate | RANGE+LIST | none found (Ventus uses `custsettlement`) | UNUSED | PARTIAL | — | Defer; future Finance API. |
| `taxtrans` | transdate | RANGE | none found | UNUSED | PARTIAL | — | Joined by `Voucher` inside `spGetInvoiceData` tax subqueries — confirm; `transdate` not filtered. |
| `custsettlement` | transdate | RANGE | none active [`USVExtractARVentus` DECOMMISSIONED] | UNUSED | PARTIAL | — | Sole consumer retired 2026-07-24; no active date/DataAreaId filter. Defer / confirm against future Finance API. |
| `vendinvoicejour` | invoicedate | RANGE+LIST | none found | UNUSED | PRUNES | — | Defer; future vendor Invoice API. |
| `taxjournaltrans` | transdate | RANGE | none found | UNUSED | PARTIAL | — | Defer. |
| `purchline` | deliverydate | RANGE+LIST | `spGetPurchaseOrderDetails`, `spEDIPurchOrderCreateDetails`, `sp810Inbound…` (ais) | NO PRUNE (date) / **PRUNES (DAI)** | PARTIAL | param | `WHERE PL.PURCHID=@PurchId AND PL.DATAAREAID=@LegalEntity` — LIST prunes; `deliverydate` never filtered. |
| `markuptrans` | transdate | RANGE | `spGetInvoiceData`, `spOrderStatusDetail` (ais) | **NO PRUNE** | NO PRUNE | commented | Joined by `TRANSRECID`/`MARKUPCODE`; `transdate` never filtered. |
| `custconfirmjour` | confirmdate | RANGE | none found | UNUSED | PARTIAL | — | Defer. |
| `reqitemtable` | RecId | HASH | none found | UNUSED | UNUSED | — | Defer. |
| `purchlinehistory` | deliverydate | RANGE | none found | UNUSED | PARTIAL | — | Defer. |
| `custinvoicesaleslink` | invoicedate | RANGE | none found | UNUSED | PARTIAL | — | Defer. |
| `vendinvoicetrans` | invoicedate | RANGE | none found | UNUSED | PARTIAL | — | Defer. |
| `vendpackingsliptrans` | accountingdate | RANGE | none found | UNUSED | PARTIAL | — | Defer. |
| `inventtransferline` | createddatetime | RANGE | `spGetTransferOrderDetails`, `…TransportNote` (ais) | **NO PRUNE** | NO PRUNE | param | `WHERE ... TRANSFERID=@InventTransferId AND DATAAREAID=@LegalEntity`; `createddatetime` not filtered. (DataAreaId not the chosen key here.) |
| `custinteresttrans` | transdate | RANGE | none found | UNUSED | PARTIAL | — | Defer. |
| `inventtransfertable` | createddatetime | RANGE | `spGetTransferOrderDetails`, `…TransportNote` (ais) | **NO PRUNE** | NO PRUNE | param | `WHERE TRANSFERID=@InventTransferId AND DATAAREAID=@LegalEntity`; `createddatetime` not filtered. |
| `vendinvoiceinfoline` | RecId | HASH | none found | UNUSED | UNUSED | — | Defer. |
| `inventvaluereporttmpline` | transdate | RANGE | none found | UNUSED | UNUSED | — | Temp-line table; README already flags "consider not partitioning." Defer. |
| `usvsspprogramcustomer` | RecId | HASH | `spGetSSPItemsByAccountNumber`, `spRWAInvoiceMatchingService_SSPReturnDays` (ais) | NO PRUNE | NO PRUNE | no | Filtered by `CUSTACCOUNT`/`PROGRAMID`, never `RECID`. |
| `usvsspprogramproducts` | RecId | HASH | `spGetSSPItemsByAccountNumber`, `spRWA…SSPReturnDays` (ais) | NO PRUNE | NO PRUNE | no | Joined by `INVOICEACCOUNT`/`PROGRAMID`, never `RECID`. |
| `inventjournaltrans` | transdate | RANGE | none found | UNUSED | PARTIAL | — | Defer. |

### Phase 4 — Composite + Finance

| Table | PK | Type | Consumers (repo) | Legacy | API | DAI | Notes |
|---|---|---|---|---|---|---|---|
| `generaljournalaccountentry` | modifieddatetime | RANGE | `GetVendorRemainingBalance` (rudi) | **NO PRUNE** | NO PRUNE | no | Joined from `generaljournalentry` by `RecId`; `modifieddatetime` never filtered. |
| `salesline` | shippingdaterequested | RANGE+LIST | ~40 procs (ais OrderStatus/Invoice/Sales) | **NO PRUNE** | PARTIAL | commented | Joined by `SALESID`/`INVENTTRANSID`; date never filtered; `DATAAREAID` mostly commented out. |
| `salestable` | deliverydate | RANGE+LIST | ~30 procs (ais) | **NO PRUNE** | PARTIAL | commented | `WHERE ST.CUSTACCOUNT=@CustAccount` or `ST.SALESID=…`; `deliverydate` never filtered. |
| `generaljournalentry` | accountingdate | RANGE+LIST | `GetVendorRemainingBalance` (rudi) | **NO PRUNE** | PARTIAL | indirect | Joined `gjae.GeneralJournalEntry=gje.recid`, filtered via `Ledger.Name=@D365Company`; `accountingdate` absent. |
| `usvsalescommissionresptable` | invoicedate | RANGE | (view → Vendor commission-code API) | UNUSED | PARTIAL | — | Surfaced as join input; `invoicedate` not filtered by consumers. |
| `ledgerjournaltable` | createddatetime | RANGE | none found | UNUSED | PARTIAL | — | Defer. |
| `whssalesline` | modifieddatetime | RANGE | `spGetSalesOrderDetails`, `spGetWhsSalesLine` (ais) | PARTIAL | PARTIAL | param(join) | Joined by `INVENTTRANSID`+`DATAAREAID`; `modifieddatetime` selected, not filtered. |
| `subledgerjournalaccountentrydistribution` | createddatetime | RANGE | none found | UNUSED | PARTIAL | — | Defer. |
| `usvcuststatement` | transdate | RANGE | (view → `/finance/customers/{acct}/statement`) | UNUSED | PARTIAL | — | Statement API path-keyed by account; add date range to prune. |
| `ledgertransvoucherlink` | transdate | RANGE+LIST | none found (rudi `GetVoucherPostedDate` → confirm) | UNUSED | PARTIAL | — | Defer / confirm voucher-lookup path. |
| `tmssalestable` | modifieddatetime | RANGE | `spGetSalesOrderDetails`, `spGetSSPDataByVendorAccount` (ais) | NO PRUNE | NO PRUNE | join | Joined by `SALESID`+`DATAAREAID`; `modifieddatetime` not filtered. |
| `usvcustinvoicejourstatement` | invoicedate | RANGE | (view → statement API, `?scope=invoice-jour`) | UNUSED | PARTIAL | — | Path-keyed by account; add date range to prune. |
| `ledgerentryjournal` | RecId | HASH | none found | UNUSED | UNUSED | — | Defer. |

---

## 4. Specific mismatches (act before authoring DDL)

1. **`custtrans` / `custsettlement` — RESOLVED (2026-07-24).** This mismatch hinged on
   `dbo.USVExtractARVentus`, which filtered **`createddatetime`** rather than `transdate`.
   **`USVExtractARVentus` is decommissioned / no longer used**, so that constraint is gone.
   `custtrans` is now partitioned `LIST(dataareaid) → RANGE(modifieddatetime)` (verified clean:
   min 2019-02-01, 0 pre-2000/null rows). `custsettlement` loses its only date-filtering consumer
   and is now effectively UNUSED — see its row above (defer / confirm against future Finance API).

2. **`inventdim` — RANGE on a join-only table.** Partitioned by `modifieddatetime` but universally
   joined by `inventdimid` (`JOIN InventDim ID ON PL.InventDimId = ID.InventDimId`). No query filters
   the date. A date range never prunes; consider HASH by `inventdimid`/`RecId` (for parallelism) or
   no partition.

3. **`ecoresvalue` / `ecorestextvalue` — RANGE on a RecId-lookup table.** Joined by `RECID` through
   `v_ecoresvalue`. `modifieddatetime` is never a predicate. HASH by `RecId` would at least align
   with the access pattern (and matches the sibling `ecores*` HASH choices).

4. **HASH-by-RecId program/exclusion tables.** `usvexclusionprogramcustomerproducts`,
   `usvsspprogramcustomer`, `usvsspprogramproducts` are filtered by `INVOICEACCOUNT` / `CUSTACCOUNT` /
   `PROGRAMID` — never `RecId`. HASH gives parallel scan only. If point-lookup latency matters,
   consider HASH/LIST by the actual lookup column, or leave unpartitioned (`usvexclusion…` is the only
   one >5 GB).

5. **DataAreaId filtering is commented out** in `ais.spGetInvoiceData`, `spOrderStatusDetail`,
   `spGetInvoiceData`'s markup subqueries, etc. (`--AND CIJ.DATAAREAID = @LegalEntity`). The LIST
   sub-partition on `custinvoicejour` / `salesline` / `salestable` cannot prune until those filters
   are re-enabled in the ported repository SQL.

6. **No-consumer tables (defer).** `sysuserlog`, `vendinvoicejour`, `vendinvoicetrans`,
   `vendpackingsliptrans`, `custinvoicesaleslink`, `custinteresttrans`, `ledgertransvoucherlink`,
   `ledgerjournaltable`, `subledgerjournalaccountentrydistribution`, `taxtrans`, `taxjournaltrans`,
   `custconfirmjour`, `purchlinehistory`, `reqitemtable`, `inventjournaltrans`,
   `inventvaluereporttmpline`, `whsshipmenttable`, `whsworklinecyclecount`, `vendinvoiceinfoline`,
   `ledgerentryjournal`, `vendsettlement`, and the 8 `usvecoresprod*attributes`. No reference in the
   four repos — confirm against external/Boomi/Esker/Ventus consumers and the future API list before
   committing partition DDL.

---

## 5. Recommendations

1. **Adopt the future-API access pattern as the design basis, and say so.** The date-RANGE +
   `DataAreaId`-LIST scheme pays off for the consolidated **search** endpoints
   (`/invoices?startDate&endDate&legalEntity`, `/sales-orders?startDate&endDate`,
   `/order-status/summary/by-invoice-account?startDate&endDate`, the Esker/Ventus/COMPASS date-range
   extracts). It does **not** help the point-lookup endpoints. Make this explicit in the phase docs
   (caveat note added) so reviewers don't assume legacy sprocs benefit.

2. **Protect point lookups.** For tables that are date/RANGE-partitioned yet dominated by
   point-lookup access — `custinvoicejour` (`InvoiceId`/`RecId`), `salestable`/`salesline`
   (`SalesId`/`InventTransId`), `purchline` (`PurchId`), `vendtrans` (`AccountNum`+`Invoice`) — ensure
   **each partition carries a local B-tree on the business key**, and quantify the all-partition probe
   cost (N partitions × index probe) versus today's single B-tree. If a point-lookup endpoint is the
   dominant traffic, weigh HASH-by-business-key or no partition instead of date RANGE.

3. **Standardize `DataAreaId` filtering.** When porting repository SQL, *enable* the
   `legalEntity` → `DataAreaId` predicate (master plan §D.2) on the LIST tables so sub-partition
   pruning fires. Audit for the commented-out `--AND x.DATAAREAID = @LegalEntity` lines flagged above.

4. **Fix the column-choice mismatches in §4** (`custtrans`/`custsettlement` → `createddatetime`;
   `inventdim`, `ecoresvalue`, `ecorestextvalue` → HASH or none).

5. **Defer the no-consumer tables** (§4.6) until an API consumer is confirmed, or partition them HASH
   purely for parallel vacuum/maintenance rather than pruning.

6. **HASH partition-wise joins.** For `inventtransorigin` (HASH by `RecId`) joined from `inventtrans`
   on `RecId`, note the benefit is a parallel partition-wise join, not standalone pruning — fine to
   keep, but don't expect I/O reduction on point access.

---

## 6. Open questions for API / data-platform owners

- **Production `vN`.** Several procs have many versions (`spOrderStatusDetail` v3–v15,
  `spGetInvoiceRemainder` v2–v4, `spRWAInvoiceMatchingService` v2–v9). The predicate set — and thus
  some verdicts — depends on which is live. Confirm (master plan Open Q §I.1).
- **External consumers.** Do Boomi flows, Esker, Ventus, or reporting tools add date/`DataAreaId`
  filters not visible in these four repos? This determines whether the "UNUSED/defer" tables actually
  benefit from partitioning.
- **`taxtrans` / `ledgertransvoucherlink` lookup paths.** Confirm whether the tax subqueries in
  `spGetInvoiceData` and `rudi.GetVoucherPostedDate` reach these by `Voucher`/`RecId` (no prune) so we
  can finalize their verdicts.
