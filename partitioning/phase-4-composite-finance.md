# Phase 4 - Composite + Finance - Partition Recommendations

**Scope:** OrderStatus (Sales) and Finance (GL, FX, Bank, Esker AR). Largest individual tables in the project.

**Source:** profiled from `d365.*` schema on Azure SQL `d365a1prdsynlinkusvprod2sql01.database.windows.net / primal` on 2026-06-04. Row counts from `sys.dm_db_partition_stats`; date column min/max from TABLESAMPLE.

**Summary:**
- Tables in scope: 41
- Partitioning recommended: 13 (8 RANGE, 4 RANGE+LIST, 1 HASH)
- No partitioning needed: 28

> **⚠️ Query-fit caveat:** These recommendations are profiled from **data shape**, not query access patterns. Per [`sproc-partition-fit-analysis.md`](sproc-partition-fit-analysis.md), current sprocs filter these tables by **business key** (InvoiceId/SalesId/RecId/AccountNum), not by the partition date column; `DataAreaId` LIST pruning fires only where `legalEntity`/`DataAreaId` is actually filtered (it is commented out in several `ais.*` procs). The date/RANGE design pays off for the **future date-range search APIs**, not legacy point lookups. Validate per table before authoring DDL.

## Tables to partition

Sorted by size (largest first).

| Table | Rows | Size (MB) | Partition column | Type | Interval | DataAreaIds | Rationale |
|---|---:|---:|---|---|---|---:|---|
| `d365.generaljournalaccountentry` | 475022861 | 431676.92 | `modifieddatetime` | RANGE | monthly | 1 | 475M rows / 431 GB; modifieddatetime 2020-10 to 2026-06; biggest GL table |
| `d365.salesline` | 75651260 | 187890.47 | `shippingdaterequested` | RANGE+LIST | monthly + LIST(DataAreaId) | 3 | 75M rows / 187 GB; shippingdaterequested 2019-2026 clean (use this over shippingdateconfirmed which has 1900-01-01 entries); 3 DataAreaIds |
| `d365.salestable` | 59872716 | 110389.58 | `deliverydate` | RANGE+LIST | monthly + LIST(DataAreaId) | 3 | 59M rows / 110 GB; deliverydate 2019-2026; sales order header - partner of salesline |
| `d365.generaljournalentry` | 153010212 | 109012.57 | `accountingdate` | RANGE+LIST | monthly + LIST(DataAreaId) | 1 | 153M rows / 109 GB; accountingdate 2016-2026 - 10-year span; finance API filters by date AND legal entity |
| `d365.usvsalescommissionresptable` | 48530978 | 28231.41 | `invoicedate` | RANGE | monthly | 1 | 48M rows / 28 GB; invoicedate 2023-2026 |
| `d365.ledgerjournaltable` | 27696168 | 24628.89 | `createddatetime` | RANGE | quarterly | 9 | 27M rows / 24 GB; createddatetime mixed (some 1900) but spans to 2026; 9 DataAreaIds |
| `d365.whssalesline` | 34782528 | 20411.25 | `modifieddatetime` | RANGE | monthly | 1 | 34M rows / 20 GB; modifieddatetime 2023-2026 |
| `d365.subledgerjournalaccountentrydistribution` | 42583392 | 19821.84 | `createddatetime` | RANGE | monthly | 1 | 42M rows / 19 GB; createddatetime 2021-2026 |
| `d365.usvcuststatement` | 31938815 | 19514.40 | `transdate` | RANGE | monthly | 1 | 31M rows / 19 GB; transdate 2023-2026 |
| `d365.ledgertransvoucherlink` | 37065117 | 16616.34 | `transdate` | RANGE+LIST | quarterly + LIST(DataAreaId) | 12 | 37M rows / 16 GB; transdate 2017-2026; 12 DataAreaIds |
| `d365.tmssalestable` | 29892286 | 16570.37 | `modifieddatetime` | RANGE | monthly | 1 | 29M rows / 16 GB; modifieddatetime 2023-2026 |
| `d365.usvcustinvoicejourstatement` | 19966754 | 12568.24 | `invoicedate` | RANGE | monthly | 1 | 19M rows / 12 GB; invoicedate 2023-2026 |
| `d365.ledgerentryjournal` | 14876537 | 5881.91 | `RecId` | HASH | 8 partitions | 1 | 14M rows; all audit columns 1900-01-01; HASH by RecId |

## No partitioning needed (28 tables)

These tables are small enough (under 10M rows AND under 5 GB) or zero-row that PostgreSQL/AlloyDB single-table storage with a B-tree index on `DataAreaId` + business key is sufficient. Listed by descending row count for sanity check.

<details><summary>Show full list</summary>

| Table | Rows | Size (MB) |
|---|---:|---:|
| `d365.spectrans` | 2827763 | 2099.05 |
| `d365.salesjournalautosummary` | 790800 | 398.54 |
| `d365.usvsalestrackingnumbers` | 662902 | 498.43 |
| `d365.casedetailbase` | 46418 | 28.03 |
| `d365.casedetail` | 23209 | 10.97 |
| `d365.dimensionfinancialtag` | 9450 | 4.36 |
| `d365.usvcustavailcredit` | 8674 | 7.43 |
| `d365.ledgerfiscalcalendarperiod` | 5376 | 1.70 |
| `d365.exchangerate` | 2647 | 1.21 |
| `d365.mainaccount` | 798 | 0.70 |
| `d365.ledgerjournalname` | 509 | 0.52 |
| `d365.bankaccounttable` | 326 | 0.32 |
| `d365.salesagreementheader` | 289 | 0.26 |
| `d365.fiscalcalendarperiod` | 224 | 0.26 |
| `d365.usvgeneralledgerhierarchy` | 130 | 0.20 |
| `d365.mainaccountcategory` | 107 | 0.20 |
| `d365.bankgroup` | 52 | 0.20 |
| `d365.ledger` | 37 | 0.20 |
| `d365.casecategoryhierarchydetail` | 18 | 0.07 |
| `d365.fiscalcalendaryear` | 16 | 0.07 |
| `d365.usvfndcategory` | 12 | 0.07 |
| `d365.exchangeratecurrencypair` | 10 | 0.07 |
| `d365.exchangeratetype` | 6 | 0.07 |
| `d365.usvopenar` | 0 | 0 |
| `d365.usvpnccusttransdataentity` | 0 | 0 |
| `d365.esker_usvopenar` | 0 | 0 |
| `d365.financialdimensionvalueentityfinancialtagview` | 0 | 0 |
| `d365.v_dirpartytable` | 0 | 0 |

</details>
