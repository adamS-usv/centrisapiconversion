# Master Partition List — D365 → AlloyDB (Project Atlas Phase 2)

**Generated:** 2026-07-13 · **Synced:** 2026-08-10 (CSV + phase docs brought in line with composite DDL).
**Sources of truth:** [`create-partitions.sql`](create-partitions.sql) (DDL) and [`_recommendations.csv`](_recommendations.csv) (profiled 2026-06-04 against Primal `d365.*`; partition *types* match the SQL).
**Companion DDL:** [`create-partitions.sql`](create-partitions.sql) — runnable partition-creation script covering **now through 2028** (2029 for future-dated delivery tables).

## What this is

Of the 322 tables profiled, **63 exceed the 5M-row / 1-GB threshold and get a partition strategy**; the other 246 stay as plain heap tables with a B-tree on `DataAreaId` + business key (no partitioning). This document is the consolidated list of those 63, and the SQL file is the command set to build their partitions.

### Two strategies in play (revised 2026-07-24)

| Strategy | When | How it's built |
|---|---|---|
| **LIST + RANGE** (composite) | Any table with a usable business/audit date column **and** a `dataareaid` column (all 43 date-partitioned tables) | Two-level, **`DataAreaId` first**: `PARTITION BY LIST (dataareaid)`; each listed legal entity is sub-partitioned `PARTITION BY RANGE (<date>)` (monthly if ≥50M rows, quarterly otherwise) **+ a per-entity date `DEFAULT`** for `1900`/out-of-range rows; plus one **plain-leaf `<tbl>_edef`** catching every unlisted entity. See ordering note below. |
| **HASH** | ≥10M rows but audit columns stuck at `1900-01-01` and no usable business date | `PARTITION BY HASH (recid)`, 4 / 8 / 16 partitions by size |

> Previously the 32 "RANGE" tables were single-level (date only) and only the 11 finance tables were composite. Per stakeholder direction (queries filter legal entity first), **all 43 date-partitioned tables are now composite `LIST(dataareaid) → RANGE(date)`.** 27 of the 32 former RANGE tables are single-entity today (`40` operations, or `dat` shared GL/product/system), so their LIST layer is a 1-entity wrapper + `_edef` leaf — a near-free add (+1 partition) that future-proofs multi-entity growth and lets every query's `dataareaid` predicate prune uniformly.

> **Partition ordering: `DataAreaId` is the leading key, not the date.** Consumers read these tables with the legal-entity predicate almost always present and the business-date predicate often *absent* (`sproc-partition-fit-analysis.md` §2–3: "DataAreaId is the one dimension that aligns"). `LIST (dataareaid)` on top prunes to a single entity subtree on the common access path; the `RANGE (<date>)` sub-level still prunes by date window for the future search APIs (`?startDate&endDate&legalEntity`).

> ⚠️ **Two caveats (read before running DDL):**
> 1. **Legal-entity codes confirmed and trimmed from live data (2026-07-24).** The full 37-entity universe (incl. `dat`, the D365 default company) is in `create-partitions.sql` as `d365.all_dataareaids()` (helper 1h). Rather than apply all 37 everywhere (~35–40k mostly-empty leaves), each composite table gets an **explicit `ARRAY[...]` trimmed to the entities it actually holds with ≥100k rows** — verified against Primal (`_dataareaid_counts.sql` for the 11 finance tables, `_dataareaid_counts_range.sql` for the other 32). The sub-100k tail (and any future entity) falls into the **plain-leaf `<tbl>_edef`** (a single catch-all table, *not* date-subpartitioned — the tail is small enough that a leaf scans fast and a full date subtree there would just be empty bloat). Multi-entity kept lists: `vendsettlement`/`vendtrans` `40,99,20,95,70`; `ledgertransvoucherlink` `99,20,40,95,70,30`; `custsettlement`/`custtrans` `40,20,30`; `custinvoicetrans` `40,20,70`; `taxtrans`/`taxjournaltrans` `40,70`; `ledgerjournaltable` `40,20`; `custinvoicejour`/`vendinvoicejour` `40,20`; `salesline` `40,70`. Single-entity tables: the rest (`40`, or `dat` for `generaljournalentry`/`generaljournalaccountentry`/`ecoresvalue`/`ecorestextvalue`/`subledger…`/`sysuserlog`). **Case matters:** alpha codes are stored lowercase (`dat`,`divp`,`divt`,`sff`); LIST values must match exactly.
> 2. **Column definitions are out of scope here.** These recommendations are partition *strategy* only. The `CREATE TABLE` column lists come from the AlloyDB schema-generation step; the SQL file supplies the exact `PARTITION BY …` clause to append to each generated table, plus all child-partition commands.

### Fivetran ID index

Every partitioned parent also gets a **btree index on `recid`** (Section 6 of the SQL file). Fivetran merges each changed row into the destination by its primary key, and on a partitioned table that scan is prohibitively slow without an index. Creating the index on the *parent* makes PostgreSQL cascade a matching local index to every existing **and future** child partition automatically. It is non-unique because PostgreSQL only permits a `UNIQUE` index on a partitioned table when the index includes the partition-key column, and Fivetran keys on `recid` alone (HASH tables, being partitioned by `recid`, may use `UNIQUE`). For the initial historical backfill you can defer this section and re-run it after the first sync to avoid slowing the bulk load.

---

## Composite tables, single-entity-dominant (32) — `LIST(dataareaid) → RANGE(date)`

These are the former single-level RANGE tables, now composite. `Date sub-key` is the RANGE column under each entity; `# date parts` is the date children **per entity subtree** (through 2028-12, delivery tables through 2029-12, excluding DEFAULTs) — total leaves ≈ `# date parts × (kept entities + 1 edef)`. **All are single-entity (`40`, or `dat` for the shared GL/product/system tables) EXCEPT:** `custsettlement` (`40,20,30`), `taxtrans` (`40,70`), `taxjournaltrans` (`40,70`), `ledgerjournaltable` (`40,20`). Everything below the ≥100k-row cut → the `<tbl>_edef` leaf. Exact per-table lists live in `create-partitions.sql` Sections 2–3.

| Phase | Table | Rows | Size (GB) | Date sub-key | Interval | Data window | # date parts |
|:--:|---|--:|--:|---|:--:|:--:|--:|
| 4 | `generaljournalaccountentry` | 475.0M | 421.6 | `modifieddatetime` | monthly | 2020-10 → | 99 |
| 3 | `inventtrans` | 495.2M | 365.0 | `datephysical` | monthly | 2019-01 → (pre-2019 → DEFAULT) | 120 |
| 2 | `whsworkline` | 528.2M | 435.1 | `modifieddatetime` | monthly | 2023-02 → | 71 |
| 2 | `whsworktable` | 239.9M | 133.7 | `modifieddatetime` | monthly | 2023-02 → | 71 |
| 2 | `whsshipmenttable` | 65.6M | 42.1 | `modifieddatetime` | monthly | 2023-02 → | 71 |
| 2 | `whsloadtable` | 55.8M | 46.6 | `modifieddatetime` | monthly | 2023-02 → | 71 |
| 2 | `whsloadline` | 45.9M | 56.9 | `modifieddatetime` | monthly | 2023-02 → | 71 |
| 4 | `usvsalescommissionresptable` | 48.5M | 27.6 | `invoicedate` | monthly | 2023-01 → | 72 |
| 4 | `subledgerjournalaccountentrydistribution` | 42.6M | 19.4 | `createddatetime` | monthly | 2021-01 → | 96 |
| 4 | `whssalesline` | 34.8M | 19.9 | `modifieddatetime` | monthly | 2023-01 → | 72 |
| 4 | `usvcuststatement` | 31.9M | 19.1 | `transdate` | monthly | 2023-01 → | 72 |
| 4 | `tmssalestable` | 29.9M | 16.2 | `modifieddatetime` | monthly | 2023-01 → | 72 |
| 4 | `usvcustinvoicejourstatement` | 20.0M | 12.3 | `invoicedate` | monthly | 2023-01 → | 72 |
| 3 | `custconfirmjour` | 57.1M | 25.9 | `confirmdate` | monthly | 2023-01 → | 72 |
| 0 | `sysuserlog` | 10.1M | 6.0 | `createddatetime` | monthly | 2018-01 → | 132 |
| 2 | `inventdim` | 328.0M | 139.6 | `modifieddatetime` | quarterly | 2025-Q2 → | 15 |
| 2 | `ecoresvalue` | 82.9M | 42.3 | `modifieddatetime` | quarterly | 2023-Q1 → | 24 |
| 2 | `ecorestextvalue` | 78.9M | 29.1 | `modifieddatetime` | quarterly | 2023-Q1 → | 24 |
| 3 | `taxtrans` | 114.3M | 107.5 | `transdate` | quarterly | 2019-Q1 → | 40 |
| 3 | `custsettlement` | 84.2M | 82.5 | `transdate` | quarterly | 2019-Q1 → | 40 |
| 3 | `taxjournaltrans` | 52.1M | 38.4 | `transdate` | quarterly | 2019-Q1 → | 40 |
| 3 | `custinvoicesaleslink` | 30.3M | 23.4 | `invoicedate` | quarterly | 2019-Q1 → | 40 |
| 3 | `markuptrans` | 26.9M | 28.1 | `transdate` | quarterly | 2019-Q1 → (1900 → DEFAULT) | 40 |
| 4 | `ledgerjournaltable` | 27.7M | 24.1 | `createddatetime` | quarterly | 2019-Q1 → (1900 → DEFAULT) | 40 |
| 3 | `purchlinehistory` | 22.5M | 24.2 | `deliverydate` | quarterly | 2019-Q1 → 2029 (1900 → DEFAULT) | 44 |
| 3 | `vendpackingsliptrans` | 18.5M | 16.0 | `accountingdate` | quarterly | 2023-Q1 → | 24 |
| 3 | `vendinvoicetrans` | 18.4M | 21.3 | `invoicedate` | quarterly | 2023-Q1 → | 24 |
| 3 | `inventtransferline` | 12.8M | 14.9 | `createddatetime` | quarterly | 2023-Q1 → | 24 |
| 3 | `inventtransfertable` | 9.0M | 6.7 | `createddatetime` | quarterly | 2023-Q1 → | 24 |
| 3 | `inventvaluereporttmpline` | 8.7M | 5.6 | `transdate` | quarterly | 2023-Q1 → | 24 |
| 3 | `custinteresttrans` | 6.5M | 6.8 | `transdate` | quarterly | 2019-Q1 → | 40 |
| 3 | `inventjournaltrans` | 6.2M | 4.8 | `transdate` | quarterly | 2023-Q1 → | 24 |

## LIST + RANGE tables (11) — composite, `DataAreaId` first

`Entities (live/kept)` = distinct `dataareaid` values actually in the table (verified 2026-07-24 via `_dataareaid_counts.sql`) / how many get a dedicated top-level `LIST (dataareaid)` sub-partition (those with ≥100k rows). Every table also builds a `_edef` entity DEFAULT for the remaining tail. Each kept entity is then RANGE-partitioned by date. `Interval` = the date sub-level granularity.

| Phase | Table | Rows | Size (GB) | Date sub-key | Interval | Entities (live/kept) | Kept codes | Data window |
|:--:|---|--:|--:|---|:--:|:--:|---|:--:|
| 3 | `vendsettlement` | 227.0M | 122.3 | `transdate` | quarterly | 21 / 5 | 40,99,20,95,70 | 2019-Q1 → |
| 3 | `vendtrans` | 179.9M | 165.2 | `transdate` | quarterly | 21 / 5 | 40,99,20,95,70 | 2019-Q1 → |
| 4 | `generaljournalentry` | 153.0M | 106.5 | `accountingdate` | monthly | 1 / 1 | dat | 2016-01 → |
| 3 | `custtrans` | 134.8M | 123.1 | `modifieddatetime` | monthly | 10 / 3 | 40,20,30 | 2019-02 → |
| 3 | `custinvoicetrans` | 103.9M | 134.8 | `invoicedate` | monthly | 10 / 3 | 40,20,70 | 2019-01 → |
| 3 | `custinvoicejour` | 90.7M | 122.5 | `invoicedate` | monthly | 10 / 2 | 40,20 | 2019-01 → |
| 4 | `salesline` | 75.7M | 183.5 | `shippingdaterequested` | monthly | 6 / 2 | 40,70 | 2019-01 → |
| 4 | `salestable` | 59.9M | 107.8 | `deliverydate` | monthly | 6 / 1 | 40 | 2019-01 → |
| 3 | `vendinvoicejour` | 51.5M | 60.8 | `invoicedate` | monthly | 21 / 2 | 40,20 | 2019-01 → |
| 4 | `ledgertransvoucherlink` | 37.1M | 16.2 | `transdate` | quarterly | 21 / 6 | 99,20,40,95,70,30 | 2017-Q1 → |
| 3 | `purchline` | 20.0M | 33.3 | `deliverydate` | quarterly | 2 / 1 | 40 | 2019-Q1 → 2029 (1900 → per-entity DEFAULT) |

Note: `generaljournalentry` is single-entity (`dat` = D365 default company, 100% of rows) — the `LIST` layer is effectively a 1-entity wrapper over the date RANGE, kept for uniformity and future legal entities. `purchline` is `40` + a 22-row `20` (→ `_edef`).

## HASH tables (20) — `PARTITION BY HASH (recid)`

No usable date column (audit columns at `1900-01-01`); partition count sized to row count for parallel-read balance.

| Phase | Table | Rows | Size (GB) | # HASH partitions |
|:--:|---|--:|--:|--:|
| 3 | `inventsum` | 399.1M | 321.7 | 16 |
| 3 | `inventtransorigin` | 238.5M | 129.2 | 8 |
| 2 | `usvexclusionprogramcustomerproducts` | 151.3M | 73.7 | 8 |
| 2 | `ecoresattributevalue` | 82.9M | 33.5 | 8 |
| 2 | `ecoresinstancevalue` | 64.8M | 25.3 | 8 |
| 3 | `inventtransoriginsalesline` | 36.6M | 15.8 | 8 |
| 4 | `ledgerentryjournal` | 14.9M | 5.7 | 8 |
| 2 | `usvecoresprodpartsattributes` | 17.7M | 7.1 | 4 |
| 2 | `usvecoresprodtiresattributes` | 17.7M | 10.6 | 4 |
| 2 | `usvecoresprodlubeschemicalattributes` | 17.7M | 6.3 | 4 |
| 2 | `whsworklinecyclecount` | 11.0M | 8.5 | 4 |
| 2 | `usvecoresprodtiresaccessoriesattributes` | 8.9M | 6.2 | 4 |
| 2 | `usvecoresprodmicsitemsattributes` | 8.9M | 6.1 | 4 |
| 2 | `usvecoresprodexhuastattributes` | 8.9M | 5.9 | 4 |
| 2 | `usvecoresprodtubesattributes` | 8.9M | 6.7 | 4 |
| 2 | `usvecoresprodtiresattributesext` | 8.9M | 5.1 | 4 |
| 3 | `reqitemtable` | 24.6M | 25.2 | 4 |
| 3 | `usvsspprogramcustomer` | 9.4M | 5.6 | 4 |
| 3 | `usvsspprogramproducts` | 9.2M | 5.4 | 4 |
| 3 | `vendinvoiceinfoline` | 5.5M | 6.1 | 4 |

---

## Totals

| Strategy | Tables | Child partitions created (through 2028/29) |
|---|--:|--:|
| LIST + RANGE composite — single-entity-dominant (former RANGE) | 32 | ~date-buckets **× (kept entities + 1 `_edef` leaf)**; 27 are 1-entity so ≈ single-level count +1 leaf each; 4 multi-entity add 1–2 subtrees |
| LIST + RANGE composite — multi-entity finance | 11 | ~date-buckets **× (kept entities + 1 `_edef` leaf)**, + a per-entity date DEFAULT |
| HASH | 20 | 116 |
| **Total flagged for partitioning** | **63** | **~4,000–4,500 leaves** (with the ≥100k-row trim) |

> Composite count = per-table date children **× number of kept entities**, + one `_edef` leaf per table. Because the entity lists are trimmed to ≥100k-row entities (mostly 1 per table; max 6), the total lands around ~4,000–4,500 leaves — versus ~35–40k if the full 37-entity list were applied everywhere. `_edef` is a single plain leaf (not date-subpartitioned), so it adds exactly one partition per table. The planner only ever probes one entity subtree per query (dataareaid is always filtered).

Remaining **259** in-scope tables: no partitioning (heap + B-tree on `DataAreaId` + business key).

## Running / maintaining

1. Generate the base `CREATE TABLE` column DDL from the AlloyDB schema step.
2. Append the `PARTITION BY …` clause shown for each table in [`create-partitions.sql`](create-partitions.sql) to its `CREATE TABLE`.
3. Run `create-partitions.sql` — it defines idempotent helper functions and calls them once per table. Safe to re-run (`CREATE TABLE IF NOT EXISTS …`).
4. **Extending to future years:** each year, re-run the single `SELECT d365.ensure_*_partitions(...)` call with a later end date, or bump the `:target_end` psql variable at the top and re-run. For production, consider `pg_partman` (`run_maintenance()` on a cron) to auto-roll new partitions — noted inline in the SQL file.
