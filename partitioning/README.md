# Project Atlas Phase 2 - PostgreSQL/AlloyDB Partitioning Recommendations

## What this is

Per-table partitioning recommendations for the `d365.*` source tables in scope for the AlloyDB migration. Tables are grouped by the API phase that first depends on them (per `../BASE_TABLES_BY_PHASE.md`). Coverage: Phase 0 (Foundation), Phase 2 (Masters), Phase 3 (Dependent reads), Phase 4 (Composite + Finance).

Recommendations are derived from empirical inspection of the `d365.*` schema currently landing in Azure SQL via Fivetran on `d365a1prdsynlinkusvprod2sql01.database.windows.net / primal` (a.k.a. "the Primal server"), profiled on **2026-06-04**.

## Headline numbers

- **322** tables landed in the `d365` schema (from a manifest of ~365 base tables; the gap is D365 entity views like `DIMATTRIBUTE*`, `*ENTITY`, and `V_*` which are not physical tables - the underlying base tables ARE replicated; see the diff note below).
- **63** tables exceed the 5M-row / 1-GB threshold; these get specific partition strategies.
- **246** smaller tables (across all four phases) get no partitioning - a B-tree index on `DataAreaId` + business key is sufficient.

| Phase | Total in scope | Partition recommended | No partitioning |
|---|---:|---:|---:|
| 0 - Foundation | 64 | 1 | 63 |
| 2 - Masters | 102 | 17 | 85 |
| 3 - Dependent reads | 59 | 29 | 30 |
| 4 - Composite + Finance | 36 | 13 | 23 |

## Decision framework

Cheapest answer wins:

| Signal | Recommendation |
|---|---|
| Row count < 10M **and** size < 5 GB | **No partitioning.** B-tree index on `DataAreaId` + business key. |
| Row count >= 10M, strong business-date column (`InvoiceDate`, `TransDate`, `AccountingDate`, `DeliveryDate`, etc.), multi-year spread | **RANGE by business-date column.** Monthly if >= 50M rows, quarterly otherwise. |
| Above + `DataAreaId` distinct >= 4 + finance/invoice/settlement domain | **Composite LIST + RANGE** - `LIST (dataareaid)` as the leading key, `RANGE (<date>)` sub-partition per legal entity. (Revised 2026-07-24: `DataAreaId` first, because consumers filter legal entity far more consistently than date - see `MASTER_PARTITION_LIST.md` ordering note and `sproc-partition-fit-analysis.md` §2-3.) |
| Row count >= 10M but audit columns stuck at `1900-01-01` and no usable business-date column | **HASH by `RecId`** (4-16 partitions depending on size). |
| Master/reference data | **No partitioning.** Caching layer or materialized views address read amplification. |

## Key gotchas discovered

1. **`ModifiedDateTime = 1900-01-01`** on roughly 30% of large tables. D365 leaves this column at the default value when a row has never been modified after initial migration. Do **not** partition on `ModifiedDateTime` without checking - several tables had to fall back to `CreatedDateTime`, business dates, or HASH.

2. **`_fivetran_synced` is too narrow.** Fivetran replication was bootstrapped on 2026-04-21, so this column spans only ~6 weeks today. Not a viable partition key (would put all data in one partition for years).

3. **D365 WHS module went live 2023-02.** All warehouse tables (`whsworkline`, `whsworktable`, `whsshipmenttable`, `whsloadtable`, `whsloadline`, `whssalesline`, `tmssalestable`) have clean `ModifiedDateTime` starting 2023-02. Monthly partitions from 2023-02 forward are appropriate.

4. **Finance/Invoice tables span 2019-2026** (and `generaljournalentry` goes back to **2016-08-25** - a 10-year span). Monthly RANGE partitions on `InvoiceDate` / `AccountingDate` / `TransDate` are the right choice for these.

5. **Migrated 1900-01-01 rows in business-date columns.** Some tables (e.g., `purchline.deliverydate`, `markuptrans.transdate`) have a mix of legitimate dates and `1900-01-01` placeholders from the original DMS migration. In PostgreSQL/AlloyDB, define a **default partition** (or an explicit `1900-1999` partition) to absorb these.

6. **`DataAreaId` cardinality is low.** Most tables have 1-3 distinct values; only finance/invoice/settlement tables go higher (top: `vendinvoicejour` at 17, `vendsettlement` at 16, `ledgertransvoucherlink` at 12). LIST sub-partitioning is worthwhile only for those.

## File layout

```
apiconversion/partitioning/
  README.md                       <- this file
  discovery-queries.sql           <- documented, idempotent T-SQL bundle
  phase-0-foundation.md           <- per-table recommendations
  phase-2-masters.md
  phase-3-dependent-reads.md
  phase-4-composite-finance.md
  _d365_inventory.txt             <- raw: table | row_count | size_mb
  _d365_date_columns.txt          <- raw: table | column | data_type
  _phase_inventory.csv            <- inventory joined to phase manifest
  _profile_picks.csv              <- which date column was selected per table
  _profile_out.txt                <- raw output of first profile pass
  _fallback_out.txt               <- raw output of CreatedDateTime fallback pass
  _round2_out.txt                 <- raw output of round-2 business-date fallback
  _recommendations.csv            <- final consolidated recommendations
  _build_*.ps1, _render_*.ps1     <- scripts used to assemble the report
```

## Manifest diff

The Phase 0/2/3/4 manifest at `../BASE_TABLES_BY_PHASE.md` references **309** tables. Of those:

- **252** are physical tables in `d365.*` and were profiled here.
- **55** are missing from `d365.*` - **almost all are D365 entity views or computed views** (names ending in `ENTITY`, starting with `V_` / `DIMATTRIBUTE` / `*VIEW`), which Fivetran does not replicate. The underlying base tables that these views aggregate from ARE landed. This matches the caveat already documented at `BASE_TABLES_BY_PHASE.md:204`.
- **2** Esker AR tables (`Esker_USVOpenAR`, `USVOpenAR`) and `usvpnccusttransdataentity` are genuinely missing - these are quarantined per `MASTER_IMPLEMENTATION_PLAN.md` Section I.14 and will need a separate decision.

## How to re-run the analysis

1. Update the connection string in your shell (`$env:SQLPWD`) and run `discovery-queries.sql` against the `primal` database. The queries are read-only and use `WITH (NOLOCK)` + `TABLESAMPLE` for the large tables.
2. Re-run `_parse_manifest.ps1` then `_build_profile_sql.ps1` then `_build_recommendations.ps1` then `_render_markdown.ps1`. Each is idempotent.
3. The full pass takes ~10 minutes end-to-end (the profile bundle is ~9 minutes against the 63 large tables).

## What's out of scope here

- **Phase 1 (Pilot)** and **Phase 5 (Complex)**: can be added in a follow-up pass; Phase 5 tables are mostly low-volume EDI queues.
- **AlloyDB DDL generation**: partition recommendations only. DDL will be authored once the AlloyDB target schema (`d365.*` vs. flattened API views) is finalized.
- **Index tuning, FK design, CDC parameters**: separate concerns.

## Sign-off / next steps

- Walk the per-phase reports with the API team owners (Customer, Vendor, Invoice, OrderStatus, Finance).
- Confirm the `DataAreaId` filter pattern in each API matches the LIST sub-partition direction here.
- For HASH-partitioned tables, agree on partition count (4 / 8 / 16) based on AlloyDB cluster sizing.
- Decide on default-partition policy for tables with migrated `1900-01-01` business dates.
