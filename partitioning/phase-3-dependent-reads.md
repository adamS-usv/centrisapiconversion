# Phase 3 - Dependent reads - Partition Recommendations

**Scope:** Program, Delivery, PurchaseOrder, Invoice, TransferOrder. Heaviest concentration of date-range query workloads.

**Source:** profiled from `d365.*` schema on Azure SQL `d365a1prdsynlinkusvprod2sql01.database.windows.net / primal` on 2026-06-04. Row counts from `sys.dm_db_partition_stats`; date column min/max from TABLESAMPLE.

**Summary:**
- Tables in scope: 59
- Partitioning recommended: 29 (15 RANGE, 7 RANGE+LIST, 7 HASH)
- No partitioning needed: 30

> **⚠️ Query-fit caveat:** These recommendations are profiled from **data shape**, not query access patterns. Per [`sproc-partition-fit-analysis.md`](sproc-partition-fit-analysis.md), current sprocs filter these tables by **business key** (InvoiceId/SalesId/RecId/AccountNum), not by the partition date column; `DataAreaId` LIST pruning fires only where `legalEntity`/`DataAreaId` is actually filtered (it is commented out in several `ais.*` procs). The date/RANGE design pays off for the **future date-range search APIs**, not legacy point lookups. Validate per table before authoring DDL.

## Tables to partition

Sorted by size (largest first).

| Table | Rows | Size (MB) | Partition column | Type | Interval | DataAreaIds | Rationale |
|---|---:|---:|---|---|---|---:|---|
| `d365.inventtrans` | 495226162 | 373685.94 | `datephysical` | RANGE | monthly | 1 | 495M rows / 373 GB; datephysical 1900-2026 (default partition for migrated 1900 rows + monthly post-2019) |
| `d365.inventsum` | 399078046 | 329429.82 | `RecId` | HASH | 16 partitions | 1 | 399M rows / 329 GB; inventory snapshot, no business date; HASH for parallel reads |
| `d365.vendtrans` | 179939436 | 169215.48 | `transdate` | RANGE+LIST | quarterly + LIST(DataAreaId) | 8 | 179M rows / 169 GB; transdate 2019-2026; 8 DataAreaIds |
| `d365.custinvoicetrans` | 103941126 | 138014.41 | `invoicedate` | RANGE+LIST | monthly + LIST(DataAreaId) | 5 | 103M rows / 138 GB; invoicedate 2019-2026; 5 DataAreaIds - invoice queries always filter both |
| `d365.inventtransorigin` | 238538449 | 132268.30 | `RecId` | HASH | 8 partitions | 1 | 238M rows / 132 GB; both audit columns 1900-01-01; _fivetran_synced only 6 weeks; HASH by RecId |
| `d365.custtrans` | 134756602 | 126006.80 | `transdate` | RANGE+LIST | monthly + LIST(DataAreaId) | 8 | 134M rows / 126 GB; transdate 2019-2026; 8 DataAreaIds; heavy date-range query pattern |
| `d365.custinvoicejour` | 90748712 | 125455.43 | `invoicedate` | RANGE+LIST | monthly + LIST(DataAreaId) | 6 | 90M rows / 125 GB; invoicedate 2019-2026; 6 DataAreaIds; primary table for Invoice API |
| `d365.vendsettlement` | 227009580 | 125283.79 | `transdate` | RANGE+LIST | quarterly + LIST(DataAreaId) | 16 | 227M rows / 125 GB; transdate 2019-2026; 16 DataAreaIds - composite partition for legal-entity isolation |
| `d365.taxtrans` | 114310054 | 110083.88 | `transdate` | RANGE | quarterly | 5 | 114M rows / 110 GB; transdate 2019-2026; 5 DataAreaIds |
| `d365.custsettlement` | 84237485 | 84485.11 | `transdate` | RANGE | quarterly | 7 | 84M rows / 84 GB; transdate 2019-2026; 7 DataAreaIds |
| `d365.vendinvoicejour` | 51546512 | 62295.68 | `invoicedate` | RANGE+LIST | monthly + LIST(DataAreaId) | 17 | 51M rows / 62 GB; 17 DataAreaIds - heaviest multi-entity table |
| `d365.taxjournaltrans` | 52095178 | 39325.65 | `transdate` | RANGE | quarterly | 4 | 52M rows / 39 GB; transdate 2019-2026; 4 DataAreaIds |
| `d365.purchline` | 20041706 | 34061.03 | `deliverydate` | RANGE+LIST | quarterly + LIST(DataAreaId) | 1 | 20M rows / 34 GB; deliverydate 1900-2029; PO line queries filter delivery window |
| `d365.markuptrans` | 26929460 | 28769.93 | `transdate` | RANGE | quarterly | 1 | 26M rows / 28 GB; transdate mostly post-2019 (some 1900 migrated rows -> default partition) |
| `d365.custconfirmjour` | 57136818 | 26550.23 | `confirmdate` | RANGE | monthly | 1 | 57M rows / 26 GB; confirmdate 2023-2026 (D365 cutover); single DataAreaId |
| `d365.reqitemtable` | 24638073 | 25787.24 | `RecId` | HASH | 4 partitions | 1 | 24M rows; audit cols 1900-01-01; no business date |
| `d365.purchlinehistory` | 22494194 | 24801.41 | `deliverydate` | RANGE | quarterly | 1 | 22M rows / 24 GB; deliverydate spans 1900-2029 (planned future + migrated past) - quarterly with default partition |
| `d365.custinvoicesaleslink` | 30252727 | 23917.43 | `invoicedate` | RANGE | quarterly | 5 | 30M rows / 23 GB; invoicedate 2019-2026; 5 DataAreaIds |
| `d365.vendinvoicetrans` | 18431214 | 21831.23 | `invoicedate` | RANGE | quarterly | 2 | 18M rows / 21 GB; invoicedate 2023-2026; 2 DataAreaIds |
| `d365.vendpackingsliptrans` | 18454338 | 16352.75 | `accountingdate` | RANGE | quarterly | 2 | 18M rows / 16 GB; accountingdate 2023-2026 |
| `d365.inventtransoriginsalesline` | 36614473 | 16186.60 | `RecId` | HASH | 8 partitions | 1 | 36M rows; audit cols 1900-01-01; HASH by RecId |
| `d365.inventtransferline` | 12815994 | 15238.14 | `createddatetime` | RANGE | quarterly | 1 | 12M rows / 15 GB; createddatetime 2023-2026 |
| `d365.custinteresttrans` | 6535250 | 6948.60 | `transdate` | RANGE | quarterly | 3 | 6.5M rows / 6.9 GB; transdate 2019-2026; 3 DataAreaIds |
| `d365.inventtransfertable` | 8951000 | 6883.45 | `createddatetime` | RANGE | quarterly | 1 | 8.9M rows / 6.8 GB; createddatetime 2023-2026 |
| `d365.vendinvoiceinfoline` | 5529502 | 6210.31 | `RecId` | HASH | 4 partitions | 2 | 5.5M rows; audit cols 1900-01-01 |
| `d365.inventvaluereporttmpline` | 8706506 | 5738.52 | `transdate` | RANGE | quarterly | 2 | 8.7M rows; transdate 2023-2026; temp-line table - consider whether to partition at all (TBD with API team) |
| `d365.usvsspprogramcustomer` | 9382436 | 5694.10 | `RecId` | HASH | 4 partitions | 1 | 9M rows; both audit cols 1900-01-01 |
| `d365.usvsspprogramproducts` | 9235126 | 5549.79 | `RecId` | HASH | 4 partitions | 1 | 9M rows; both audit cols 1900-01-01 |
| `d365.inventjournaltrans` | 6220930 | 4954.77 | `transdate` | RANGE | quarterly | 2 | 6.2M rows; transdate 2023-2026 |

## No partitioning needed (30 tables)

These tables are small enough (under 10M rows AND under 5 GB) or zero-row that PostgreSQL/AlloyDB single-table storage with a B-tree index on `DataAreaId` + business key is sufficient. Listed by descending row count for sanity check.

<details><summary>Show full list</summary>

| Table | Rows | Size (MB) |
|---|---:|---:|
| `d365.custtransopen` | 2944118 | 3468.21 |
| `d365.vendpackingslipjour` | 2590442 | 1429.29 |
| `d365.inventjournaltable` | 2075652 | 1043.69 |
| `d365.vendpackingslipversion` | 1295336 | 1014.21 |
| `d365.vendtransopen` | 1139225 | 1617.13 |
| `d365.vendinvoiceinfotable` | 787332 | 955.44 |
| `d365.purchtablehistory` | 746848 | 770.56 |
| `d365.custinterestjour` | 595348 | 294.40 |
| `d365.purchtable` | 579200 | 856.86 |
| `d365.purchtableversion` | 514190 | 262.78 |
| `d365.usvprogramcustprodexclusiontable` | 25116 | 7.09 |
| `d365.intercompanypurchsalesreference` | 6010 | 3.56 |
| `d365.taxtable` | 1516 | 1.07 |
| `d365.paymterm` | 1004 | 0.63 |
| `d365.agreementheader` | 289 | 0.34 |
| `d365.usvprogramreasoncode` | 287 | 0.26 |
| `d365.paymday` | 255 | 0.27 |
| `d365.taxonitem` | 242 | 0.26 |
| `d365.taxdata` | 230 | 0.26 |
| `d365.purchparameters` | 74 | 0.21 |
| `d365.markuptable` | 48 | 0.20 |
| `d365.idttaxlogparameters` | 24 | 0.07 |
| `d365.vduplicateprograms` | 0 | 0 |
| `d365.taxgstreliefgroupheading_my` | 0 | 0.00 |
| `d365.usvprogramtableentity` | 0 | 0 |
| `d365.paymenttermentity` | 0 | 0 |
| `d365.vprogramtableswithzerorecords` | 0 | 0 |
| `d365.vprogramswithnoitems` | 0 | 0 |
| `d365.usvprogramcustprodexclusiontableentity` | 0 | 0 |
| `d365.usvprogramproductstableentity` | 0 | 0 |

</details>
