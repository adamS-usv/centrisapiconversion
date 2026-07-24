-- =====================================================================
-- Project Atlas Phase 2 — D365 -> AlloyDB partition creation
-- =====================================================================
-- Generated  : 2026-07-13  (revised 2026-07-24: dataareaid-first composite)
-- Source      : apiconversion/partitioning/_recommendations.csv (profiled 2026-06-04)
-- Master list : apiconversion/partitioning/MASTER_PARTITION_LIST.md
-- Target      : PostgreSQL 14+ / AlloyDB Omni. Schema = d365.
--
-- WHAT THIS SCRIPT DOES
--   1. Defines idempotent helper functions that create RANGE (monthly /
--      quarterly), HASH, and composite LIST(dataareaid)+RANGE(date) child
--      partitions.
--   2. For each of the 63 tables flagged for partitioning, supplies:
--        (a) the PARTITION BY clause to append to its CREATE TABLE, and
--        (b) the helper call(s) to build every child partition through 2028
--            (2029 for future-dated delivery tables).
--
-- COMPOSITE ORDER (revised 2026-07-24)
--   The 11 finance/invoice/settlement tables are partitioned
--   **dataareaid FIRST, date SECOND**:
--        PARTITION BY LIST (dataareaid)
--          -> each legal entity is itself PARTITION BY RANGE (<date>)
--   Rationale: the sprocs/views read these tables with the legal-entity
--   predicate almost always present and the business-date predicate often
--   ABSENT (see sproc-partition-fit-analysis.md §2-3 — "DataAreaId is the one
--   dimension that aligns"). Making dataareaid the leading partition key lets
--   the planner prune to a single entity subtree on the common access path,
--   while the RANGE(date) sub-level still prunes by date window for the future
--   search APIs (?startDate&endDate&legalEntity).
--
-- WHAT THIS SCRIPT DOES NOT DO
--   * It does NOT emit the column lists. Partition recommendations are
--     strategy only; the column DDL comes from the AlloyDB schema-gen step.
--     The parent CREATE TABLE for each table is shown as a COMMENT with the
--     required "PARTITION BY ..." clause -- run that first (with real columns),
--     THEN run the helper calls below it.
--
-- LEGAL-ENTITY (dataareaid) CODES
--   Each composite table takes an ARRAY of dataareaid codes. Every entity in
--   the array gets its own sub-partition; a per-table DEFAULT entity bucket
--   ("<tbl>_edef") absorbs any legal entity NOT in the array, so the build is
--   always correct regardless of code-list confidence. Each of the 11 tables
--   passes an explicit ARRAY[...] trimmed to the entities it actually holds with
--   >=100k rows (verified live 2026-07-24; see _dataareaid_counts.sql). The full
--   37-entity universe is kept as reference in d365.all_dataareaids() (helper 1h).
--
-- IDEMPOTENT: every partition is created with CREATE TABLE IF NOT EXISTS, so
-- re-running is safe and is exactly how you extend into future years / add a
-- newly-confirmed legal entity.
-- =====================================================================

SET search_path = d365, public;

-- Rolling horizon. Bump these and re-run each year to roll partitions forward.
\set target_end            '''2028-12-01'''   -- last month/quarter for most tables
\set target_end_delivery   '''2029-12-01'''   -- delivery-date tables run a year further out

-- =====================================================================
-- SECTION 1 — HELPER FUNCTIONS
-- =====================================================================

-- 1a. Monthly RANGE child partitions: <tbl>_pYYYYMM  [from, from+1mo)
--     Works on any RANGE(date) table, including an entity sub-partition
--     such as 'custinvoicejour_40' (children -> custinvoicejour_40_p201901).
CREATE OR REPLACE FUNCTION d365.ensure_monthly_partitions(
    p_parent text, p_from date, p_to date)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    d    date := date_trunc('month', p_from)::date;
    sch  text := split_part(p_parent, '.', 1);
    tbl  text := split_part(p_parent, '.', 2);
    part text;
BEGIN
    WHILE d <= p_to LOOP
        part := tbl || '_p' || to_char(d, 'YYYYMM');
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s FOR VALUES FROM (%L) TO (%L)',
            sch, part, p_parent, d, (d + interval '1 month')::date);
        d := (d + interval '1 month')::date;
    END LOOP;
END; $$;

-- 1b. Quarterly RANGE child partitions: <tbl>_pYYYYqN  [from, from+3mo)
CREATE OR REPLACE FUNCTION d365.ensure_quarterly_partitions(
    p_parent text, p_from date, p_to date)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    d    date := date_trunc('quarter', p_from)::date;
    sch  text := split_part(p_parent, '.', 1);
    tbl  text := split_part(p_parent, '.', 2);
    part text;
BEGIN
    WHILE d <= p_to LOOP
        part := tbl || '_p' || to_char(d, 'YYYY') || 'q' || to_char(d, 'Q');
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s FOR VALUES FROM (%L) TO (%L)',
            sch, part, p_parent, d, (d + interval '3 months')::date);
        d := (d + interval '3 months')::date;
    END LOOP;
END; $$;

-- 1c. HASH child partitions: <tbl>_ph0 .. _ph(N-1)
CREATE OR REPLACE FUNCTION d365.ensure_hash_partitions(
    p_parent text, p_modulus int)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    sch  text := split_part(p_parent, '.', 1);
    tbl  text := split_part(p_parent, '.', 2);
    i    int;
BEGIN
    FOR i IN 0 .. p_modulus - 1 LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s FOR VALUES WITH (MODULUS %s, REMAINDER %s)',
            sch, tbl || '_ph' || i, p_parent, p_modulus, i);
    END LOOP;
END; $$;

-- 1d. DEFAULT partition (absorbs migrated 1900-01-01 + any out-of-range rows).
--     Create a DEFAULT on every RANGE table so inserts never fail. Also used
--     as the per-entity date DEFAULT under each composite entity sub-partition.
CREATE OR REPLACE FUNCTION d365.ensure_default_partition(p_parent text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    sch text := split_part(p_parent, '.', 1);
    tbl text := split_part(p_parent, '.', 2);
BEGIN
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s DEFAULT',
                   sch, tbl || '_pdefault', p_parent);
END; $$;

-- 1e/1f. Composite LIST(dataareaid) -> RANGE(date) helpers.
--        The PARENT is PARTITION BY LIST (dataareaid). For each code we create
--        one entity sub-partition that is itself PARTITION BY RANGE (<date>),
--        then fill it with monthly (1e) or quarterly (1f) date children + a
--        per-entity date DEFAULT. A top-level entity DEFAULT ("<tbl>_edef"),
--        also RANGE(date), absorbs every legal entity not in p_dataareaids so
--        the table is complete regardless of code-list confidence.
CREATE OR REPLACE FUNCTION d365.ensure_list_monthly_partitions(
    p_parent text, p_from date, p_to date, p_datecol text, p_dataareaids text[])
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    sch text := split_part(p_parent, '.', 1);
    tbl text := split_part(p_parent, '.', 2);
    da  text;
    ent text;   -- unqualified entity sub-partition name
BEGIN
    -- one entity sub-partition per confirmed code, each RANGE(date)-partitioned
    FOREACH da IN ARRAY p_dataareaids LOOP
        ent := tbl || '_' || lower(da);
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s FOR VALUES IN (%L) PARTITION BY RANGE (%I)',
            sch, ent, p_parent, da, p_datecol);
        PERFORM d365.ensure_monthly_partitions(sch || '.' || ent, p_from, p_to);
        PERFORM d365.ensure_default_partition (sch || '.' || ent);
    END LOOP;
    -- top-level entity DEFAULT (all other legal entities), also RANGE(date)
    ent := tbl || '_edef';
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s DEFAULT PARTITION BY RANGE (%I)',
        sch, ent, p_parent, p_datecol);
    PERFORM d365.ensure_monthly_partitions(sch || '.' || ent, p_from, p_to);
    PERFORM d365.ensure_default_partition (sch || '.' || ent);
END; $$;

CREATE OR REPLACE FUNCTION d365.ensure_list_quarterly_partitions(
    p_parent text, p_from date, p_to date, p_datecol text, p_dataareaids text[])
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    sch text := split_part(p_parent, '.', 1);
    tbl text := split_part(p_parent, '.', 2);
    da  text;
    ent text;
BEGIN
    FOREACH da IN ARRAY p_dataareaids LOOP
        ent := tbl || '_' || lower(da);
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s FOR VALUES IN (%L) PARTITION BY RANGE (%I)',
            sch, ent, p_parent, da, p_datecol);
        PERFORM d365.ensure_quarterly_partitions(sch || '.' || ent, p_from, p_to);
        PERFORM d365.ensure_default_partition   (sch || '.' || ent);
    END LOOP;
    ent := tbl || '_edef';
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s DEFAULT PARTITION BY RANGE (%I)',
        sch, ent, p_parent, p_datecol);
    PERFORM d365.ensure_quarterly_partitions(sch || '.' || ent, p_from, p_to);
    PERFORM d365.ensure_default_partition   (sch || '.' || ent);
END; $$;

-- 1g. Fivetran ID index. Fivetran merges each changed row into the destination
--     by its primary key (D365 = recid); without an index that becomes a scan
--     per row. Creating the index on the PARTITIONED PARENT makes PostgreSQL
--     auto-create a matching local index on every existing AND future partition
--     at EVERY level (the cascade is recursive, so composite leaf partitions are
--     covered too). Non-unique: PostgreSQL only allows UNIQUE on a partitioned
--     table when the index includes the partition key, and Fivetran keys on
--     recid alone. (For HASH tables, which ARE partitioned by recid, you may
--     make it UNIQUE.)
CREATE OR REPLACE FUNCTION d365.ensure_recid_index(p_parent text, p_col text DEFAULT 'recid')
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    sch text := split_part(p_parent, '.', 1);
    tbl text := split_part(p_parent, '.', 2);
BEGIN
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %s (%I)',
                   tbl || '_' || p_col || '_idx', p_parent, p_col);
END; $$;

-- 1h. Canonical legal-entity (dataareaid) universe — REFERENCE ONLY (37 codes,
--     confirmed by the API owners 2026-07-24). Section 4 does NOT use this; each
--     composite table passes an explicit ARRAY[...] trimmed to the entities that
--     table actually contains (>=100k rows — verified live 2026-07-24), so we
--     don't build empty date subtrees for entities a table never uses. Kept here
--     as the documented full set + fallback for any future composite table.
--     CASE-SENSITIVITY: LIST values must match the stored dataareaid EXACTLY.
--     Live data stores the alpha codes LOWERCASE ('dat','divp','divt','sff' were
--     confirmed lowercase); the 'FX'/'Q' variants were not observed in the 11
--     tables — VERIFY their stored case before using them in a LIST partition.
CREATE OR REPLACE FUNCTION d365.all_dataareaids()
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
    SELECT ARRAY[
        'dat','94','451','450','100','101','102','150','20','21','70','151','75',
        '152','75fx','30','90','91','93','95','divp','divt','99','49','71','710',
        '51','51fx','22','50','98','sff','97','40','96','96q','22fx'
    ]::text[];
$$;

-- =====================================================================
-- SECTION 2 — RANGE, MONTHLY  (13 tables)
-- For each: (a) create parent with the shown PARTITION BY; (b) run the calls.
-- =====================================================================

-- generaljournalaccountentry | 475M / 421 GB | modifieddatetime 2020-10 ->
--   CREATE TABLE d365.generaljournalaccountentry ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_monthly_partitions('d365.generaljournalaccountentry', DATE '2020-10-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.generaljournalaccountentry');

-- inventtrans | 495M / 365 GB | datephysical (pre-2019 incl 1900 -> DEFAULT)
--   CREATE TABLE d365.inventtrans ( ... ) PARTITION BY RANGE (datephysical);
SELECT d365.ensure_monthly_partitions('d365.inventtrans', DATE '2019-01-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.inventtrans');

-- whsworkline | 528M / 435 GB | modifieddatetime | WHS live 2023-02
--   CREATE TABLE d365.whsworkline ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_monthly_partitions('d365.whsworkline', DATE '2023-02-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.whsworkline');

-- whsworktable | 239M / 133 GB | modifieddatetime | WHS 2023-02
--   CREATE TABLE d365.whsworktable ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_monthly_partitions('d365.whsworktable', DATE '2023-02-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.whsworktable');

-- whsshipmenttable | 65M / 42 GB | modifieddatetime | WHS 2023-02
--   CREATE TABLE d365.whsshipmenttable ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_monthly_partitions('d365.whsshipmenttable', DATE '2023-02-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.whsshipmenttable');

-- whsloadtable | 55M / 46 GB | modifieddatetime | WHS 2023-02
--   CREATE TABLE d365.whsloadtable ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_monthly_partitions('d365.whsloadtable', DATE '2023-02-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.whsloadtable');

-- whsloadline | 45M / 58 GB | modifieddatetime | WHS 2023-02
--   CREATE TABLE d365.whsloadline ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_monthly_partitions('d365.whsloadline', DATE '2023-02-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.whsloadline');

-- usvsalescommissionresptable | 48M / 28 GB | invoicedate 2023 ->
--   CREATE TABLE d365.usvsalescommissionresptable ( ... ) PARTITION BY RANGE (invoicedate);
SELECT d365.ensure_monthly_partitions('d365.usvsalescommissionresptable', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.usvsalescommissionresptable');

-- subledgerjournalaccountentrydistribution | 42M / 19 GB | createddatetime 2021 ->
--   CREATE TABLE d365.subledgerjournalaccountentrydistribution ( ... ) PARTITION BY RANGE (createddatetime);
SELECT d365.ensure_monthly_partitions('d365.subledgerjournalaccountentrydistribution', DATE '2021-01-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.subledgerjournalaccountentrydistribution');

-- whssalesline | 34M / 20 GB | modifieddatetime 2023 ->
--   CREATE TABLE d365.whssalesline ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_monthly_partitions('d365.whssalesline', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.whssalesline');

-- usvcuststatement | 31M / 19 GB | transdate 2023 ->
--   CREATE TABLE d365.usvcuststatement ( ... ) PARTITION BY RANGE (transdate);
SELECT d365.ensure_monthly_partitions('d365.usvcuststatement', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.usvcuststatement');

-- tmssalestable | 29M / 16 GB | modifieddatetime 2023 ->
--   CREATE TABLE d365.tmssalestable ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_monthly_partitions('d365.tmssalestable', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.tmssalestable');

-- usvcustinvoicejourstatement | 19M / 12 GB | invoicedate 2023 ->
--   CREATE TABLE d365.usvcustinvoicejourstatement ( ... ) PARTITION BY RANGE (invoicedate);
SELECT d365.ensure_monthly_partitions('d365.usvcustinvoicejourstatement', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.usvcustinvoicejourstatement');

-- custconfirmjour | 57M / 26 GB | confirmdate 2023 -> (D365 cutover)
--   CREATE TABLE d365.custconfirmjour ( ... ) PARTITION BY RANGE (confirmdate);
SELECT d365.ensure_monthly_partitions('d365.custconfirmjour', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.custconfirmjour');

-- sysuserlog | 10M / 6 GB | createddatetime 2018 ->
--   CREATE TABLE d365.sysuserlog ( ... ) PARTITION BY RANGE (createddatetime);
SELECT d365.ensure_monthly_partitions('d365.sysuserlog', DATE '2018-01-01', DATE :target_end);
SELECT d365.ensure_default_partition ('d365.sysuserlog');

-- =====================================================================
-- SECTION 3 — RANGE, QUARTERLY  (17 tables)
-- =====================================================================

-- inventdim | 328M / 139 GB | modifieddatetime | dimension rows only since 2025-06
--   CREATE TABLE d365.inventdim ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_quarterly_partitions('d365.inventdim', DATE '2025-04-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.inventdim');

-- ecoresvalue | 82M / 42 GB | modifieddatetime 2023 ->
--   CREATE TABLE d365.ecoresvalue ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_quarterly_partitions('d365.ecoresvalue', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.ecoresvalue');

-- ecorestextvalue | 78M / 29 GB | modifieddatetime 2023 ->
--   CREATE TABLE d365.ecorestextvalue ( ... ) PARTITION BY RANGE (modifieddatetime);
SELECT d365.ensure_quarterly_partitions('d365.ecorestextvalue', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.ecorestextvalue');

-- taxtrans | 114M / 110 GB | transdate 2019 ->
--   CREATE TABLE d365.taxtrans ( ... ) PARTITION BY RANGE (transdate);
SELECT d365.ensure_quarterly_partitions('d365.taxtrans', DATE '2019-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.taxtrans');

-- custsettlement | 84M / 84 GB | transdate 2019 ->
--   CREATE TABLE d365.custsettlement ( ... ) PARTITION BY RANGE (transdate);
SELECT d365.ensure_quarterly_partitions('d365.custsettlement', DATE '2019-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.custsettlement');

-- taxjournaltrans | 52M / 39 GB | transdate 2019 ->
--   CREATE TABLE d365.taxjournaltrans ( ... ) PARTITION BY RANGE (transdate);
SELECT d365.ensure_quarterly_partitions('d365.taxjournaltrans', DATE '2019-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.taxjournaltrans');

-- custinvoicesaleslink | 30M / 23 GB | invoicedate 2019 ->
--   CREATE TABLE d365.custinvoicesaleslink ( ... ) PARTITION BY RANGE (invoicedate);
SELECT d365.ensure_quarterly_partitions('d365.custinvoicesaleslink', DATE '2019-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.custinvoicesaleslink');

-- markuptrans | 26M / 28 GB | transdate (mostly post-2019; 1900 rows -> DEFAULT)
--   CREATE TABLE d365.markuptrans ( ... ) PARTITION BY RANGE (transdate);
SELECT d365.ensure_quarterly_partitions('d365.markuptrans', DATE '2019-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.markuptrans');

-- ledgerjournaltable | 27M / 24 GB | createddatetime (some 1900 -> DEFAULT)
--   CREATE TABLE d365.ledgerjournaltable ( ... ) PARTITION BY RANGE (createddatetime);
SELECT d365.ensure_quarterly_partitions('d365.ledgerjournaltable', DATE '2019-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.ledgerjournaltable');

-- purchlinehistory | 22M / 24 GB | deliverydate 1900-2029 (planned future + migrated past)
--   CREATE TABLE d365.purchlinehistory ( ... ) PARTITION BY RANGE (deliverydate);
SELECT d365.ensure_quarterly_partitions('d365.purchlinehistory', DATE '2019-01-01', DATE :target_end_delivery);
SELECT d365.ensure_default_partition   ('d365.purchlinehistory');

-- vendpackingsliptrans | 18M / 16 GB | accountingdate 2023 ->
--   CREATE TABLE d365.vendpackingsliptrans ( ... ) PARTITION BY RANGE (accountingdate);
SELECT d365.ensure_quarterly_partitions('d365.vendpackingsliptrans', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.vendpackingsliptrans');

-- vendinvoicetrans | 18M / 21 GB | invoicedate 2023 ->
--   CREATE TABLE d365.vendinvoicetrans ( ... ) PARTITION BY RANGE (invoicedate);
SELECT d365.ensure_quarterly_partitions('d365.vendinvoicetrans', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.vendinvoicetrans');

-- inventtransferline | 12M / 15 GB | createddatetime 2023 ->
--   CREATE TABLE d365.inventtransferline ( ... ) PARTITION BY RANGE (createddatetime);
SELECT d365.ensure_quarterly_partitions('d365.inventtransferline', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.inventtransferline');

-- inventtransfertable | 8.9M / 6.8 GB | createddatetime 2023 ->
--   CREATE TABLE d365.inventtransfertable ( ... ) PARTITION BY RANGE (createddatetime);
SELECT d365.ensure_quarterly_partitions('d365.inventtransfertable', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.inventtransfertable');

-- inventvaluereporttmpline | 8.7M | transdate 2023 -> (temp-line: confirm w/ API team)
--   CREATE TABLE d365.inventvaluereporttmpline ( ... ) PARTITION BY RANGE (transdate);
SELECT d365.ensure_quarterly_partitions('d365.inventvaluereporttmpline', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.inventvaluereporttmpline');

-- custinteresttrans | 6.5M / 6.9 GB | transdate 2019 ->
--   CREATE TABLE d365.custinteresttrans ( ... ) PARTITION BY RANGE (transdate);
SELECT d365.ensure_quarterly_partitions('d365.custinteresttrans', DATE '2019-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.custinteresttrans');

-- inventjournaltrans | 6.2M | transdate 2023 ->
--   CREATE TABLE d365.inventjournaltrans ( ... ) PARTITION BY RANGE (transdate);
SELECT d365.ensure_quarterly_partitions('d365.inventjournaltrans', DATE '2023-01-01', DATE :target_end);
SELECT d365.ensure_default_partition   ('d365.inventjournaltrans');

-- =====================================================================
-- SECTION 4 — COMPOSITE  LIST(dataareaid) -> RANGE(date)   (11 tables)
-- =====================================================================
-- These 11 finance/invoice/settlement tables partition dataareaid FIRST
-- (top-level LIST), date SECOND (RANGE sub-partition). Parent PARTITION BY
-- is LIST (dataareaid); the helper creates each entity sub-partition as its
-- own RANGE(date) table plus a per-entity date DEFAULT, and a top-level
-- entity DEFAULT ("<tbl>_edef") for any legal entity not listed.
--
-- Each table's ARRAY[...] is TRIMMED to the legal entities that table actually
-- holds with >=100k rows (verified live against Primal 2026-07-24 — see
-- _dataareaid_counts.sql). Every other entity (the long tail of small legal
-- entities, plus any future/unseen one) lands in the table's top-level entity
-- DEFAULT <tbl>_edef, which is itself RANGE(date)-partitioned — so tail rows
-- still get date pruning, just not their own entity subtree.
--
-- Why trim: dataareaid-first multiplies date children by entity count. Using the
-- full 37-entity universe on every table would build ~35-40k leaf partitions,
-- mostly EMPTY subtrees for entities a given table never uses. The >=100k-row
-- cut keeps pruning for every material entity while holding the 11 tables to
-- ~3,500 partitions total. To promote a tail entity to its own partition later,
-- add its code here and re-run (idempotent) — but see the _edef caveat in
-- Section 7 if data is already loaded.
-- =====================================================================

-- vendsettlement | 227M / 125 GB | transdate 2019 -> | quarterly | 16 DataAreaIds
--   CREATE TABLE d365.vendsettlement ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.vendsettlement',
       DATE '2019-01-01', DATE :target_end, 'transdate',
       ARRAY['40','99','20','95','70']);   -- 21 entities live; tail (<100k rows) -> _edef

-- vendtrans | 179M / 169 GB | transdate 2019 -> | quarterly | 8 DataAreaIds
--   CREATE TABLE d365.vendtrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.vendtrans',
       DATE '2019-01-01', DATE :target_end, 'transdate',
       ARRAY['40','99','20','95','70']);   -- 21 entities live; tail (<100k rows) -> _edef

-- generaljournalentry | 153M / 109 GB | accountingdate 2016 -> | monthly | 1* DataAreaId
--   CREATE TABLE d365.generaljournalentry ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.generaljournalentry',
       DATE '2016-01-01', DATE :target_end, 'accountingdate',
       ARRAY['dat']);   -- single entity: 100% under 'dat' (D365 default company), 159.9M rows

-- custtrans | 134M / 126 GB | modifieddatetime 2019-02 -> | monthly | 10 DataAreaIds live
--   Date col = modifieddatetime (chosen 2026-07-24). Verified clean: min 2019-02-01,
--   max current, 0 pre-2000/1900 rows, 0 nulls (71M rows; weighted to 2023+).
--   CREATE TABLE d365.custtrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.custtrans',
       DATE '2019-02-01', DATE :target_end, 'modifieddatetime',
       ARRAY['40','20','30']);   -- 10 entities live; tail (<100k rows) -> _edef

-- custinvoicetrans | 103M / 138 GB | invoicedate 2019 -> | monthly | 5 DataAreaIds
--   CREATE TABLE d365.custinvoicetrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.custinvoicetrans',
       DATE '2019-01-01', DATE :target_end, 'invoicedate',
       ARRAY['40','20','70']);   -- 10 entities live; tail (<100k rows) -> _edef

-- custinvoicejour | 90M / 125 GB | invoicedate 2019 -> | monthly | 6 DataAreaIds | primary Invoice API table
--   CREATE TABLE d365.custinvoicejour ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.custinvoicejour',
       DATE '2019-01-01', DATE :target_end, 'invoicedate',
       ARRAY['40','20']);   -- 10 entities live; tail (<100k rows) -> _edef

-- salesline | 75M / 187 GB | shippingdaterequested 2019 -> | monthly | 3 DataAreaIds
--   (clean; avoid shippingdateconfirmed=1900)
--   CREATE TABLE d365.salesline ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.salesline',
       DATE '2019-01-01', DATE :target_end, 'shippingdaterequested',
       ARRAY['40','70']);   -- 6 entities live; tail (<100k rows) -> _edef

-- salestable | 59M / 110 GB | deliverydate 2019 -> | monthly | 3 DataAreaIds | partner of salesline
--   CREATE TABLE d365.salestable ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.salestable',
       DATE '2019-01-01', DATE :target_end, 'deliverydate',
       ARRAY['40']);   -- 6 entities live, only '40' >100k rows; tail -> _edef

-- vendinvoicejour | 51M / 62 GB | invoicedate 2019 -> | monthly | 17 DataAreaIds (heaviest multi-entity)
--   CREATE TABLE d365.vendinvoicejour ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.vendinvoicejour',
       DATE '2019-01-01', DATE :target_end, 'invoicedate',
       ARRAY['40','20']);   -- 21 entities live; tail (<100k rows, next is 95 at 92k) -> _edef

-- ledgertransvoucherlink | 37M / 16 GB | transdate 2017 -> | quarterly | 12 DataAreaIds
--   CREATE TABLE d365.ledgertransvoucherlink ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.ledgertransvoucherlink',
       DATE '2017-01-01', DATE :target_end, 'transdate',
       ARRAY['99','20','40','95','70','30']);   -- 21 entities live; tail (<100k rows) -> _edef

-- purchline | 20M / 34 GB | deliverydate 1900-2029 (migrated 1900 -> per-entity DEFAULT) | quarterly | 1* DataAreaId
--   CREATE TABLE d365.purchline ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.purchline',
       DATE '2019-01-01', DATE :target_end_delivery, 'deliverydate',
       ARRAY['40']);   -- only '40' (10.8M) + '20' (22 rows -> _edef)

-- =====================================================================
-- SECTION 5 — HASH  (20 tables) | PARTITION BY HASH (recid)
-- =====================================================================

--   CREATE TABLE d365.<t> ( ... ) PARTITION BY HASH (recid);   -- for each below
SELECT d365.ensure_hash_partitions('d365.inventsum', 16);                                   -- 399M / 329 GB
SELECT d365.ensure_hash_partitions('d365.inventtransorigin', 8);                            -- 238M / 132 GB
SELECT d365.ensure_hash_partitions('d365.usvexclusionprogramcustomerproducts', 8);          -- 151M / 75 GB
SELECT d365.ensure_hash_partitions('d365.ecoresattributevalue', 8);                         -- 82M / 34 GB
SELECT d365.ensure_hash_partitions('d365.ecoresinstancevalue', 8);                          -- 64M / 26 GB
SELECT d365.ensure_hash_partitions('d365.inventtransoriginsalesline', 8);                   -- 36M / 16 GB
SELECT d365.ensure_hash_partitions('d365.ledgerentryjournal', 8);                           -- 14M / 5.8 GB
SELECT d365.ensure_hash_partitions('d365.usvecoresprodpartsattributes', 4);                 -- 17M / 7 GB
SELECT d365.ensure_hash_partitions('d365.usvecoresprodtiresattributes', 4);                 -- 17M / 10 GB
SELECT d365.ensure_hash_partitions('d365.usvecoresprodlubeschemicalattributes', 4);         -- 17M / 6 GB
SELECT d365.ensure_hash_partitions('d365.whsworklinecyclecount', 4);                        -- 10M / 8.7 GB
SELECT d365.ensure_hash_partitions('d365.usvecoresprodtiresaccessoriesattributes', 4);      -- 8.8M / 6 GB
SELECT d365.ensure_hash_partitions('d365.usvecoresprodmicsitemsattributes', 4);             -- 8.8M / 6 GB
SELECT d365.ensure_hash_partitions('d365.usvecoresprodexhuastattributes', 4);               -- 8.8M / 6 GB
SELECT d365.ensure_hash_partitions('d365.usvecoresprodtubesattributes', 4);                 -- 8.8M / 6.8 GB
SELECT d365.ensure_hash_partitions('d365.usvecoresprodtiresattributesext', 4);              -- 8.8M / 5.2 GB
SELECT d365.ensure_hash_partitions('d365.reqitemtable', 4);                                 -- 24M / 25 GB
SELECT d365.ensure_hash_partitions('d365.usvsspprogramcustomer', 4);                        -- 9M / 5.6 GB
SELECT d365.ensure_hash_partitions('d365.usvsspprogramproducts', 4);                        -- 9M / 5.5 GB
SELECT d365.ensure_hash_partitions('d365.vendinvoiceinfoline', 4);                          -- 5.5M / 6.2 GB

-- =====================================================================
-- SECTION 6 — FIVETRAN ID INDEX  (all 63 partitioned tables)
-- =====================================================================
-- Btree on recid, created on each partitioned parent so it cascades to every
-- existing and future child partition -- at ALL levels, so the composite leaf
-- partitions (<tbl>_<entity>_pYYYYMM) are covered by the same cascade.
-- Speeds Fivetran's per-row merge scans.
-- NOTE ON LOAD ORDER: an index present during the initial bulk load slows the
-- load. If Fivetran does a large historical backfill, you can DEFER this whole
-- section until after the first sync completes -- re-run it then and PostgreSQL
-- builds the local index on every partition. For incremental syncs, keep it on.
-- Adjust p_col if a table's Fivetran primary key is not recid (e.g. tables with
-- no PK use '_fivetran_id').
DO $$
DECLARE
    t text;
    parents text[] := ARRAY[
        -- RANGE monthly
        'generaljournalaccountentry','inventtrans','whsworkline','whsworktable',
        'whsshipmenttable','whsloadtable','whsloadline','usvsalescommissionresptable',
        'subledgerjournalaccountentrydistribution','whssalesline','usvcuststatement',
        'tmssalestable','usvcustinvoicejourstatement','custconfirmjour','sysuserlog',
        -- RANGE quarterly
        'inventdim','ecoresvalue','ecorestextvalue','taxtrans','custsettlement',
        'taxjournaltrans','custinvoicesaleslink','markuptrans','ledgerjournaltable',
        'purchlinehistory','vendpackingsliptrans','vendinvoicetrans','inventtransferline',
        'inventtransfertable','inventvaluereporttmpline','custinteresttrans','inventjournaltrans',
        -- COMPOSITE LIST(dataareaid) -> RANGE(date)
        'vendsettlement','vendtrans','generaljournalentry','custtrans','custinvoicetrans',
        'custinvoicejour','salesline','salestable','vendinvoicejour','ledgertransvoucherlink','purchline',
        -- HASH
        'inventsum','inventtransorigin','usvexclusionprogramcustomerproducts',
        'ecoresattributevalue','ecoresinstancevalue','inventtransoriginsalesline',
        'ledgerentryjournal','usvecoresprodpartsattributes','usvecoresprodtiresattributes',
        'usvecoresprodlubeschemicalattributes','whsworklinecyclecount',
        'usvecoresprodtiresaccessoriesattributes','usvecoresprodmicsitemsattributes',
        'usvecoresprodexhuastattributes','usvecoresprodtubesattributes',
        'usvecoresprodtiresattributesext','reqitemtable','usvsspprogramcustomer',
        'usvsspprogramproducts','vendinvoiceinfoline'
    ];
BEGIN
    FOREACH t IN ARRAY parents LOOP
        PERFORM d365.ensure_recid_index('d365.' || t);
    END LOOP;
END $$;

-- =====================================================================
-- SECTION 7 — LEGAL-ENTITY CODE LIST (maintenance)
-- =====================================================================
-- Section 4 gives each composite table an explicit ARRAY[...] trimmed to the
-- entities it holds with >=100k rows (verified live 2026-07-24). The full
-- 37-entity universe is documented in d365.all_dataareaids() (helper 1h) for
-- reference. Every table carries a top-level entity DEFAULT (<tbl>_edef) that
-- absorbs the small-entity tail and any future/unseen entity.
--
-- Because the build is idempotent, you can promote a tail entity to its own
-- partition over time:
--
--   1. Add the code to that table's ARRAY[...] in Section 4.
--   2. Re-run the affected SELECT. The helper creates the new entity subtree
--      (<tbl>_<code> + its date children). CREATE TABLE IF NOT EXISTS makes the
--      already-built entities and date partitions no-ops.
--
-- CAUTION when promoting an entity OUT of the DEFAULT after data has loaded:
-- PostgreSQL will not let you attach a LIST partition for a value that already
-- has rows sitting in the DEFAULT partition. If <tbl>_edef already holds rows
-- for the new code, detach the default, create the new entity partition, move
-- the rows, then re-attach:
--   ALTER TABLE d365.<tbl> DETACH PARTITION d365.<tbl>_edef;
--   -- create d365.<tbl>_<code> (RANGE(date)) + its children via the helper,
--   -- INSERT ... SELECT the rows for <code> out of _edef, then:
--   ALTER TABLE d365.<tbl> ATTACH PARTITION d365.<tbl>_edef DEFAULT;
-- Doing this BEFORE the initial Fivetran load avoids the move entirely.
--
-- To re-discover the actual codes/row-counts per table, re-run the bundled
-- query (this is how the Section 4 lists were derived):
--   partitioning/_dataareaid_counts.sql   (per-table dataareaid GROUP BY, NOLOCK)
-- Remember: alpha codes are stored LOWERCASE ('dat','divp','divt','sff'); match
-- the LIST value to the stored value exactly.

-- =====================================================================
-- SECTION 8 — YEARLY MAINTENANCE
-- =====================================================================
-- To roll partitions into a new year: bump :target_end / :target_end_delivery
-- at the top of this file and re-run it. IF NOT EXISTS makes every existing
-- partition a no-op; only the new trailing months/quarters get created -- for
-- the composite tables, the new date children are created under EVERY entity
-- subtree (including <tbl>_edef) automatically.
--
-- Production alternative: pg_partman. For single-level RANGE tables, register
-- each parent once, e.g.
--   SELECT partman.create_parent(
--       p_parent_table := 'd365.custsettlement',
--       p_control      := 'transdate',
--       p_type         := 'range',
--       p_interval     := '3 months',
--       p_premake      := 4);
-- then schedule  SELECT partman.run_maintenance();  on a daily cron to
-- auto-create ahead and (optionally) retire old partitions by retention policy.
-- For the composite LIST->RANGE tables, pg_partman manages the RANGE sub-level
-- per entity; register each entity subtree (d365.<tbl>_<code>) as its own
-- parent, or keep using this script's idempotent re-run for the date roll.
-- =====================================================================
