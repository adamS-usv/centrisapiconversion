-- =====================================================================
-- Per-table dataareaid distribution for the 11 composite tables.
-- Purpose: confirm which legal entities each table actually contains so the
-- LIST(dataareaid) partition lists in create-partitions.sql can be trimmed.
-- Read-only; WITH (NOLOCK). Exact counts (full grouped scan) — a few minutes
-- against the big tables. Run against Primal (d365 schema).
-- =====================================================================
SET NOCOUNT ON;

SELECT 'vendsettlement'         AS table_name, dataareaid, COUNT_BIG(*) AS rows FROM d365.vendsettlement         WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'vendtrans',              dataareaid, COUNT_BIG(*) FROM d365.vendtrans              WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'generaljournalentry',    dataareaid, COUNT_BIG(*) FROM d365.generaljournalentry    WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'custtrans',              dataareaid, COUNT_BIG(*) FROM d365.custtrans              WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'custinvoicetrans',       dataareaid, COUNT_BIG(*) FROM d365.custinvoicetrans       WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'custinvoicejour',        dataareaid, COUNT_BIG(*) FROM d365.custinvoicejour        WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'salesline',             dataareaid, COUNT_BIG(*) FROM d365.salesline             WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'salestable',            dataareaid, COUNT_BIG(*) FROM d365.salestable            WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'vendinvoicejour',        dataareaid, COUNT_BIG(*) FROM d365.vendinvoicejour        WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'ledgertransvoucherlink', dataareaid, COUNT_BIG(*) FROM d365.ledgertransvoucherlink WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'purchline',             dataareaid, COUNT_BIG(*) FROM d365.purchline             WITH (NOLOCK) GROUP BY dataareaid
ORDER BY table_name, rows DESC;
