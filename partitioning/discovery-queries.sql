-- =====================================================================
-- Project Atlas Phase 2 - d365.* partition discovery queries
-- =====================================================================
-- Read-only T-SQL bundle used to gather row counts, size, date-column
-- distributions, and DataAreaId cardinality for the d365.* schema on
-- Azure SQL `d365a1prdsynlinkusvprod2sql01.database.windows.net / primal`.
--
-- Run from sqlcmd, e.g.:
--   sqlcmd -S d365a1prdsynlinkusvprod2sql01.database.windows.net `
--          -d primal -U usvsa -P "$env:SQLPWD" `
--          -N -C -l 60 -t 600 -i discovery-queries.sql -o out.txt
--
-- All queries are read-only. Large tables use TABLESAMPLE so the bundle
-- completes in ~10 minutes total against the live `primal` database.
-- Adjust sample sizes if you need tighter accuracy.
-- =====================================================================

SET NOCOUNT ON;
SET ANSI_WARNINGS OFF;

-- ---------------------------------------------------------------------
-- Query 1: Table inventory (row count + size in MB) for the d365 schema.
-- Source: sys.partitions + sys.allocation_units (no scan of data).
-- ---------------------------------------------------------------------
SELECT
    t.name                                                              AS table_name,
    SUM(p.rows)                                                         AS row_count,
    CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(18,2))               AS size_mb
FROM   sys.tables t
JOIN   sys.indexes i             ON t.object_id = i.object_id
JOIN   sys.partitions p          ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN   sys.allocation_units a    ON p.partition_id = a.container_id
WHERE  SCHEMA_NAME(t.schema_id) = 'd365'
  AND  i.index_id IN (0,1)   -- heap or clustered only - avoid double counting
GROUP  BY t.name
ORDER  BY t.name;

-- ---------------------------------------------------------------------
-- Query 2: All date/datetime columns on d365 tables (for picking a
-- partition column).
-- ---------------------------------------------------------------------
SELECT
    c.TABLE_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE
FROM   INFORMATION_SCHEMA.COLUMNS c
WHERE  c.TABLE_SCHEMA = 'd365'
  AND  c.DATA_TYPE IN ('datetime','datetime2','date','smalldatetime','datetimeoffset')
ORDER  BY c.TABLE_NAME, c.COLUMN_NAME;

-- ---------------------------------------------------------------------
-- Query 3 (per table): Date column profile - min, max, null count.
-- Uses TABLESAMPLE for tables larger than ~20M rows.
--   - <=20M rows  -> full scan
--   - 20-50M rows -> sample 1,000,000 rows
--   - >50M rows   -> sample 500,000 rows
-- Substitute the table name and column. Example for custinvoicejour:
-- ---------------------------------------------------------------------
SELECT
    'custinvoicejour'                                       AS table_name,
    'invoicedate'                                           AS date_col,
    CAST(MIN([invoicedate]) AS DATE)                        AS min_date,
    CAST(MAX([invoicedate]) AS DATE)                        AS max_date,
    SUM(CASE WHEN [invoicedate] IS NULL THEN 1 ELSE 0 END)  AS null_count,
    COUNT_BIG(*)                                            AS scan_rows
FROM   d365.[custinvoicejour] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

-- ---------------------------------------------------------------------
-- Query 4 (per table): DataAreaId cardinality - tells us whether LIST
-- sub-partitioning is worthwhile (cardinality 4+ = useful; 1 = skip).
-- Sample 100k rows; cardinality estimates stabilize quickly.
-- ---------------------------------------------------------------------
SELECT
    'custinvoicejour'                AS table_name,
    'dataareaid'                     AS col,
    COUNT(DISTINCT [dataareaid])     AS distinct_count,
    COUNT_BIG(*)                     AS scan_rows
FROM   d365.[custinvoicejour] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

-- ---------------------------------------------------------------------
-- Query 5 (optional - per table): Year-by-year row distribution. Use
-- this when picking between monthly and quarterly partition intervals.
-- For tables with stable post-2019 distribution, monthly buys nothing
-- over quarterly. For tables with most rows in the last 12 months,
-- monthly is right.
-- ---------------------------------------------------------------------
SELECT
    YEAR([invoicedate])              AS yr,
    COUNT_BIG(*)                     AS sampled_rows
FROM   d365.[custinvoicejour] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK)
GROUP  BY YEAR([invoicedate])
ORDER  BY yr;

-- ---------------------------------------------------------------------
-- Query 6: Coverage check - does the manifest list a table we don't see?
-- Run this after Fivetran changes to catch new/dropped d365 tables.
-- ---------------------------------------------------------------------
-- Replace the IN list with the table names parsed from BASE_TABLES_BY_PHASE.md.
-- The _parse_manifest.ps1 script automates this comparison.
SELECT
    name                             AS d365_table,
    create_date,
    modify_date
FROM   sys.tables
WHERE  SCHEMA_NAME(schema_id) = 'd365'
ORDER  BY name;

-- ---------------------------------------------------------------------
-- Footnote on column choice
-- ---------------------------------------------------------------------
-- Priority order used when picking the partition column for a table:
--   1. invoicedate        (Invoice domain: custinvoice*, vendinvoice*)
--   2. transdate          (Trans domain: custtrans, vendtrans, *settlement, taxtrans, ledgertransvoucherlink)
--   3. accountingdate     (GL: generaljournalentry, vendpackingsliptrans)
--   4. postingdate        (rare; alternative to accountingdate)
--   5. shippingdaterequested / deliverydate (Sales/PO)
--   6. confirmdate        (custconfirmjour)
--   7. datephysical / datefinancial (inventtrans)
--   8. documentdate       (fallback)
--   9. modifieddatetime   (post-2023 audit fallback)
--  10. createddatetime    (final fallback)
--
-- Tables where ALL audit columns return 1900-01-01 fall through to
-- HASH partitioning on RecId. This is documented per table in the
-- per-phase markdown reports.
