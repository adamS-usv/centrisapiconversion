# Phase 2 - Masters - Partition Recommendations

**Scope:** Customer, Vendor, Warehouse, Product. Mix of master data and high-volume warehouse work tables.

**Source:** profiled from `d365.*` schema on Azure SQL `d365a1prdsynlinkusvprod2sql01.database.windows.net / primal` on 2026-06-04. Row counts from `sys.dm_db_partition_stats`; date column min/max from TABLESAMPLE. Partition *type* synced to composite DDL 2026-08-10.

**Summary:**
- Tables in scope: 111
- Partitioning recommended: 20 (8 LIST+RANGE, 12 HASH)
- No partitioning needed: 91

> **⚠️ Query-fit caveat:** These recommendations are profiled from **data shape**, not query access patterns. Per [`sproc-partition-fit-analysis.md`](sproc-partition-fit-analysis.md), current sprocs filter these tables by **business key** (InvoiceId/SalesId/RecId/AccountNum), not by the partition date column; `DataAreaId` LIST pruning fires only where `legalEntity`/`DataAreaId` is actually filtered (it is commented out in several `ais.*` procs). The date/RANGE design pays off for the **future date-range search APIs**, not legacy point lookups. Validate per table before authoring DDL.

> **Composite rule (2026-07-24):** Every date-partitioned table is **`LIST(dataareaid) → RANGE(<date>)`** — legal entity first, date second — matching [`create-partitions.sql`](create-partitions.sql) / [`MASTER_PARTITION_LIST.md`](MASTER_PARTITION_LIST.md). HASH tables (no usable date) stay `HASH(recid)`.

## Tables to partition

Sorted by size (largest first).

| Table | Rows | Size (MB) | Partition column | Type | Interval | DataAreaIds | Rationale |
|---|---:|---:|---|---|---|---:|---|
| `d365.whsworkline` | 528223972 | 445547.46 | `modifieddatetime` | LIST+RANGE | LIST(DataAreaId) + monthly | 1 | 528M rows / 445 GB; D365 WHS module live 2023-02 onward; high CDC churn; composite LIST(dataareaid) → RANGE(date) |
| `d365.inventdim` | 328020488 | 142929.09 | `modifieddatetime` | LIST+RANGE | LIST(DataAreaId) + quarterly | 2 | 328M rows; dimension rows only updated since 2025-06 - short window, quarterly is enough; composite LIST(dataareaid) → RANGE(date) |
| `d365.whsworktable` | 239883244 | 136953.52 | `modifieddatetime` | LIST+RANGE | LIST(DataAreaId) + monthly | 1 | 239M rows / 136 GB; companion of whsworkline; same WHS-2023 timeline; composite LIST(dataareaid) → RANGE(date) |
| `d365.usvexclusionprogramcustomerproducts` | 151290470 | 75468.07 | `RecId` | HASH | 8 partitions | 1 | 151M rows / 75 GB; both audit columns 1900-01-01; no business date - uniform spread by RecId |
| `d365.whsloadline` | 45912598 | 58259.95 | `modifieddatetime` | LIST+RANGE | LIST(DataAreaId) + monthly | 1 | 45M rows / 58 GB; WHS-2023+; composite LIST(dataareaid) → RANGE(date) |
| `d365.whsloadtable` | 55828568 | 47756.11 | `modifieddatetime` | LIST+RANGE | LIST(DataAreaId) + monthly | 1 | 55M rows / 47 GB; WHS-2023+; composite LIST(dataareaid) → RANGE(date) |
| `d365.ecoresvalue` | 82913822 | 43290.38 | `modifieddatetime` | LIST+RANGE | LIST(DataAreaId) + quarterly | 1 | 82M rows / 43 GB; attribute catalog churns post-2023, quarterly windows are fine; composite LIST(dataareaid) → RANGE(date) |
| `d365.whsshipmenttable` | 65611292 | 43067.12 | `modifieddatetime` | LIST+RANGE | LIST(DataAreaId) + monthly | 1 | 65M rows / 43 GB; shipment header, WHS-2023+; composite LIST(dataareaid) → RANGE(date) |
| `d365.ecoresattributevalue` | 82901292 | 34353.06 | `RecId` | HASH | 8 partitions | 1 | 82M rows / 34 GB; audit columns all 1900-01-01; catalog with single DataAreaId - HASH by RecId |
| `d365.ecorestextvalue` | 78921867 | 29782.20 | `modifieddatetime` | LIST+RANGE | LIST(DataAreaId) + quarterly | 1 | 78M rows / 29 GB; modifieddatetime 2023-02+ usable; composite LIST(dataareaid) → RANGE(date) |
| `d365.ecoresinstancevalue` | 64779387 | 25902.88 | `RecId` | HASH | 8 partitions | 1 | 64M rows / 26 GB; both audit columns 1900-01-01; HASH by RecId |
| `d365.usvecoresprodtiresattributes` | 17711428 | 10830.63 | `RecId` | HASH | 4 partitions | 1 | 17M rows; same pattern |
| `d365.whsworklinecyclecount` | 10978940 | 8709.35 | `RecId` | HASH | 4 partitions | 1 | 10M rows; both audit cols 1900-01-01; HASH by RecId |
| `d365.usvecoresprodpartsattributes` | 17711428 | 7253.57 | `RecId` | HASH | 4 partitions | 1 | 17M rows; product attribute catalog, no usable dates; HASH by RecId |
| `d365.usvecoresprodtubesattributes` | 8855714 | 6868.69 | `RecId` | HASH | 4 partitions | 1 | 8.8M rows; product attribute catalog |
| `d365.usvecoresprodlubeschemicalattributes` | 17711428 | 6405.35 | `RecId` | HASH | 4 partitions | 1 | 17M rows; same pattern |
| `d365.usvecoresprodtiresaccessoriesattributes` | 8855714 | 6360.93 | `RecId` | HASH | 4 partitions | 1 | 8.8M rows; product attribute catalog |
| `d365.usvecoresprodmicsitemsattributes` | 8855714 | 6208.07 | `RecId` | HASH | 4 partitions | 1 | 8.8M rows; product attribute catalog |
| `d365.usvecoresprodexhuastattributes` | 8855714 | 6078.67 | `RecId` | HASH | 4 partitions | 1 | 8.8M rows; product attribute catalog |
| `d365.usvecoresprodtiresattributesext` | 8855714 | 5231.87 | `RecId` | HASH | 4 partitions | 1 | 8.8M rows; product attribute catalog |

## No partitioning needed (91 tables)

These tables are small enough (under 10M rows AND under 5 GB) or zero-row that PostgreSQL/AlloyDB single-table storage with a B-tree index on `DataAreaId` + business key is sufficient. Listed by descending row count for sanity check.

<details><summary>Show full list</summary>

| Table | Rows | Size (MB) |
|---|---:|---:|
| `d365.custaging` | 3245691 | 2748.67 |
| `d365.ecoresbooleanvalue` | 2004637 | 848.59 |
| `d365.usvproductfirstreceiptdate` | 1846616 | 897.23 |
| `d365.wmslocation` | 1640834 | 704.89 |
| `d365.pricediscadmtrans` | 1491095 | 2160.66 |
| `d365.ecoresfloatvalue` | 813898 | 367.52 |
| `d365.pricedisctable` | 783176 | 886.30 |
| `d365.ecoresintvalue` | 655967 | 290.38 |
| `d365.ecoresdatetimevalue` | 517094 | 220.09 |
| `d365.custvendexternalitem` | 475791 | 288.14 |
| `d365.inventtablemodule` | 466053 | 446.90 |
| `d365.custtable` | 360986 | 691.73 |
| `d365.inventtable` | 310702 | 467.95 |
| `d365.mcrholdcodetrans` | 205735 | 144.84 |
| `d365.ecoresproductcategory` | 204706 | 79.41 |
| `d365.custdefaultlocation` | 171968 | 63.32 |
| `d365.pdsapprovedvendorlist` | 169743 | 83.81 |
| `d365.whsecoresproducttransportationcodes` | 156356 | 55.37 |
| `d365.ecoresproducttranslation` | 155369 | 68.96 |
| `d365.ecoresdistinctproduct` | 155369 | 53.62 |
| `d365.ecoresproduct` | 155369 | 69.89 |
| `d365.inventiteminventsetup` | 155352 | 148.38 |
| `d365.inventitempurchsetup` | 155352 | 117.11 |
| `d365.inventitemsalessetup` | 155352 | 127.33 |
| `d365.mcrinventtable` | 155351 | 71.91 |
| `d365.inventmodelgroupitem` | 155351 | 69.13 |
| `d365.inventitemgroupitem` | 155350 | 58.53 |
| `d365.inventitembarcode` | 150686 | 91.90 |
| `d365.ecoresstoragedimensiongroupproduct` | 144561 | 51.08 |
| `d365.ecoresproductinstancevalue` | 141950 | 52.06 |
| `d365.usvitemchargestable` | 138199 | 63.30 |
| `d365.retailcusttable` | 136065 | 79.50 |
| `d365.whscusttable` | 128816 | 63.43 |
| `d365.mcrcusttable` | 127118 | 65.11 |
| `d365.custbankaccount` | 77162 | 25.39 |
| `d365.ecoresproductimage` | 58665 | 21.20 |
| `d365.vendbankaccount` | 47674 | 19.35 |
| `d365.vendtable` | 43768 | 36.79 |
| `d365.bom` | 24638 | 11.67 |
| `d365.usvwarehousepostaladdress` | 22100 | 14.70 |
| `d365.whsworkuserwarehouse` | 15717 | 8.35 |
| `d365.whsworkuser` | 11578 | 13.80 |
| `d365.whsworker` | 10783 | 5.36 |
| `d365.usvwarehousetransfersupplywarehouse` | 6192 | 2.35 |
| `d365.pricediscadmtable` | 5269 | 3.78 |
| `d365.ecoresproductrelationtable` | 4702 | 1.58 |
| `d365.bomversion` | 4018 | 3.86 |
| `d365.bomtable` | 3178 | 2.44 |
| `d365.whslocationprofile` | 1480 | 1.26 |
| `d365.inventlocation` | 1050 | 0.84 |
| `d365.credmancreditlimitcustgroupline` | 784 | 0.45 |
| `d365.vendgroup` | 751 | 0.45 |
| `d365.mcrpickingwbwarehouseinfo` | 525 | 0.32 |
| `d365.inventlocationlogisticslocationrole` | 389 | 0.26 |
| `d365.inventlocationlogisticslocation` | 389 | 0.26 |
| `d365.vendpaymmodetable` | 306 | 0.38 |
| `d365.credmancreditlimitcustgroup` | 253 | 0.33 |
| `d365.ecoresattribute` | 153 | 0.20 |
| `d365.custpaymmodetable` | 148 | 0.20 |
| `d365.ecoresattributetype` | 131 | 0.20 |
| `d365.inventsite` | 113 | 0.20 |
| `d365.usvproductexclusionbywhs` | 101 | 0.26 |
| `d365.custgroup` | 82 | 0.21 |
| `d365.inventitemgroup` | 81 | 0.20 |
| `d365.custparameters` | 74 | 0.26 |
| `d365.whsparameters` | 70 | 0.20 |
| `d365.whsworkclasstable` | 27 | 0.20 |
| `d365.whsworktemplatetable` | 25 | 0.20 |
| `d365.customerinstancevalue` | 18 | 0.07 |
| `d365.ecoresreferencevalue` | 11 | 0.07 |
| `d365.usvacquisitiontable` | 8 | 0.07 |
| `d365.custpaymmodespec` | 7 | 0.07 |
| `d365.ecorescategoryhierarchy` | 4 | 0.07 |
| `d365.ecoresstoragedimensiongroup` | 4 | 0.07 |
| `d365.retailchanneltable` | 4 | 0.07 |
| `d365.ecorescategoryhierarchyrole` | 3 | 0.07 |
| `d365.ecoresproductrelationtype` | 2 | 0.07 |
| `d365.retailmcrchanneltable` | 2 | 0.07 |
| `d365.tmsloadbuildstrategyattribvalueset` | 1 | 0.07 |
| `d365.usvdirpartypostaladdressstagingview` | 0 | 0.00 |
| `d365.inventwarehousepostaladdressentity` | 0 | 0.00 |
| `d365.whsworkusersessionlog` | 0 | 0.00 |
| `d365.guppricetreeinstancevalue` | 0 | 0.00 |
| `d365.usvaiscustomerlookupbyorgnumsegmentstagingview` | 0 | 0.00 |
| `d365.usvlogisticscontactinfostagingview` | 0 | 0.00 |
| `d365.usvdirpartycontactv3entity` | 0 | 0.00 |
| `d365.usvcustomerresponsibilitiesemplentity` | 0 | 0.00 |
| `d365.retailpricingsimulatorinstancevalue` | 0 | 0.00 |
| `d365.vendvendorexternalcodeentity` | 0 | 0.00 |
| `d365.usvlogisticspostaladdressentity` | 0 | 0.00 |
| `d365.usvlogisticspostaladdressstagingview` | 0 | 0.00 |

</details>
