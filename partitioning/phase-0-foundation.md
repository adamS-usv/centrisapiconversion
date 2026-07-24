# Phase 0 - Foundation - Partition Recommendations

**Scope:** Party/org backbone, financial dimensions, HCM, currency, system reference. Mostly slow-changing reference data.

**Source:** profiled from `d365.*` schema on Azure SQL `d365a1prdsynlinkusvprod2sql01.database.windows.net / primal` on 2026-06-04. Row counts from `sys.dm_db_partition_stats`; date column min/max from TABLESAMPLE.

**Summary:**
- Tables in scope: 98
- Partitioning recommended:  (1 RANGE, 0 RANGE+LIST, 0 HASH)
- No partitioning needed: 97

> **⚠️ Query-fit caveat:** These recommendations are profiled from **data shape**, not query access patterns. Per [`sproc-partition-fit-analysis.md`](sproc-partition-fit-analysis.md), current sprocs filter these tables by **business key** (InvoiceId/SalesId/RecId/AccountNum), not by the partition date column; `DataAreaId` LIST pruning fires only where `legalEntity`/`DataAreaId` is actually filtered (it is commented out in several `ais.*` procs). The date/RANGE design pays off for the **future date-range search APIs**, not legacy point lookups. Validate per table before authoring DDL.

## Tables to partition

Sorted by size (largest first).

| Table | Rows | Size (MB) | Partition column | Type | Interval | DataAreaIds | Rationale |
|---|---:|---:|---|---|---|---:|---|
| `d365.sysuserlog` | 10091295 | 6104.25 | `createddatetime` | RANGE | monthly | 1 | 10M user log rows; createddatetime spans 2018-2026 |

## No partitioning needed (97 tables)

These tables are small enough (under 10M rows AND under 5 GB) or zero-row that PostgreSQL/AlloyDB single-table storage with a B-tree index on `DataAreaId` + business key is sufficient. Listed by descending row count for sanity check.

<details><summary>Show full list</summary>

| Table | Rows | Size (MB) |
|---|---:|---:|
| `d365.dimensionattributelevelvalue` | 1908769 | 943.15 |
| `d365.dimensionattributevaluecombination` | 1430682 | 812.56 |
| `d365.dimensionattributevaluegroupcombination` | 1136579 | 530.02 |
| `d365.logisticspostaladdress` | 698670 | 385.35 |
| `d365.dirpartytable` | 676160 | 509.18 |
| `d365.dimensionattributevaluegroup` | 593336 | 289.31 |
| `d365.logisticslocation` | 495916 | 276.66 |
| `d365.smmactivities` | 393264 | 213.23 |
| `d365.dirpartylocation` | 369855 | 235.36 |
| `d365.custtable` | 360986 | 691.73 |
| `d365.logisticselectronicaddressrole` | 359824 | 163.40 |
| `d365.logisticselectronicaddress` | 349071 | 252.78 |
| `d365.smmactivityparentlinktable` | 322003 | 151.81 |
| `d365.dirorganizationname` | 254582 | 148.28 |
| `d365.smmresponsibilitiesempltable` | 245608 | 121.05 |
| `d365.dimensionattributevalue` | 239404 | 188.61 |
| `d365.dimensionattributevaluesetitem` | 219196 | 86.66 |
| `d365.dirpartylocationrole` | 193240 | 72.57 |
| `d365.dirorganizationbase` | 191076 | 79.62 |
| `d365.dirorganization` | 190870 | 81.24 |
| `d365.dimensionattributevalueset` | 141764 | 50.48 |
| `d365.numbersequencetable` | 37505 | 35.41 |
| `d365.dirdunsnumber` | 24639 | 7.45 |
| `d365.sysuserinfo` | 15090 | 7.18 |
| `d365.hcmemployment` | 14426 | 9.20 |
| `d365.dirpersonname` | 12917 | 7.52 |
| `d365.dirperson` | 12777 | 7.80 |
| `d365.hcmworkertitle` | 12740 | 7.23 |
| `d365.hcmworker` | 12651 | 6.94 |
| `d365.workcalendardate` | 5879 | 2.07 |
| `d365.unitofmeasureconversion` | 5823 | 3.48 |
| `d365.workcalendardateline` | 4208 | 2.91 |
| `d365.dimensionhierarchylevel` | 689 | 0.45 |
| `d365.hcmpositiondetail` | 620 | 0.45 |
| `d365.hcmpositionworkerassignment` | 611 | 0.52 |
| `d365.hcmpositionhierarchy` | 603 | 0.45 |
| `d365.hcmposition` | 578 | 0.40 |
| `d365.logisticslocationext` | 549 | 0.33 |
| `d365.dimensionhierarchy` | 341 | 0.32 |
| `d365.logisticsaddresscountryregion` | 253 | 0.27 |
| `d365.ominternalorganization` | 206 | 0.20 |
| `d365.omoperatingunit` | 162 | 0.20 |
| `d365.currency` | 155 | 0.26 |
| `d365.companyinfo` | 74 | 0.20 |
| `d365.hcmpersondetails` | 64 | 0.21 |
| `d365.dimensionattribute` | 54 | 0.20 |
| `d365.hcmjobdetail` | 47 | 0.20 |
| `d365.unitofmeasure` | 34 | 0.20 |
| `d365.logisticslocationrole` | 31 | 0.20 |
| `d365.hcmjob` | 22 | 0.07 |
| `d365.hcmtitle` | 21 | 0.07 |
| `d365.workcalendartable` | 12 | 0.07 |
| `d365.dirnameaffix` | 10 | 0.07 |
| `d365.dimensionattributedircategory` | 9 | 0.07 |
| `d365.dirnamesequence` | 9 | 0.07 |
| `d365.omteammembershipcriterion` | 8 | 0.07 |
| `d365.omteam` | 7 | 0.07 |
| `d365.dimensionhierarchyintegration` | 4 | 0.07 |
| `d365.hcmpositionhierarchytype` | 2 | 0.07 |
| `d365.dimensionparameters` | 1 | 0.07 |
| `d365.hcmreasoncode` | 1 | 0.07 |
| `d365.systemparameters` | 1 | 0.07 |
| `d365.dirpartynameprimaryaddressview` | 0 | 0 |
| `d365.dirpartylocationrolesview` | 0 | 0 |
| `d365.dirpartybaseentity` | 0 | 0 |
| `d365.dimensionsetentity` | 0 | 0 |
| `d365.dimattributeretailchannel` | 0 | 0 |
| `d365.hcmworkerdetailsview` | 0 | 0 |
| `d365.dimensioncombinationentity` | 0 | 0 |
| `d365.dimattributevendgroup` | 0 | 0 |
| `d365.dimattributemainaccount` | 0 | 0 |
| `d365.dimattributeomvaluestream` | 0 | 0 |
| `d365.dimattributeomdepartment` | 0 | 0 |
| `d365.dimattributeomcostcenter` | 0 | 0 |
| `d365.dimattributeombusinessunit` | 0 | 0 |
| `d365.dimattributeinventitemgroup` | 0 | 0 |
| `d365.logisticspostaladdressview` | 0 | 0 |
| `d365.logisticspostaladdressbaseentity` | 0 | 0 |
| `d365.dimattributeinventtable` | 0 | 0 |
| `d365.dimattributevendtable` | 0 | 0 |
| `d365.dimattributehcmjob` | 0 | 0 |
| `d365.dimattributebankaccounttable` | 0 | 0 |
| `d365.dimattributecompanyinfo` | 0 | 0 |
| `d365.dimattributehcmposition` | 0 | 0 |
| `d365.dimattributefinancialtag` | 0 | 0 |
| `d365.dimattributecustgroup` | 0 | 0 |
| `d365.dimattributehcmworker` | 0 | 0 |
| `d365.dimattributecusttable` | 0 | 0 |
| `d365.companynafcode` | 0 | 0.00 |
| `d365.v_dirorganization` | 0 | 0 |
| `d365.v_dirpartytable` | 0 | 0 |
| `d365.v_dirperson` | 0 | 0 |
| `d365.vdefaultdimensionview` | 0 | 0 |
| `d365.workcalendardayentity` | 0 | 0 |
| `d365.dirpartypostaladdressview` | 0 | 0 |
| `d365.workcalendartimeintervalentity` | 0 | 0 |
| `d365.workcalendarentity` | 0 | 0 |

</details>
