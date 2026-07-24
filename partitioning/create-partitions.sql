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
--   ALL date-partitioned tables (Sections 2, 3, 4 = 43 tables) are partitioned
--   **dataareaid FIRST, date SECOND**:
--        PARTITION BY LIST (dataareaid)
--          -> each listed legal entity is itself PARTITION BY RANGE (<date>)
--          -> plus a plain-leaf entity DEFAULT (<tbl>_edef) for the rest
--   Rationale: the sprocs/views read these tables with the legal-entity
--   predicate almost always present and the business-date predicate often
--   ABSENT (see sproc-partition-fit-analysis.md §2-3 — "DataAreaId is the one
--   dimension that aligns"). Making dataareaid the leading partition key lets
--   the planner prune to a single entity subtree on the common access path,
--   while the RANGE(date) sub-level still prunes by date window for the future
--   search APIs (?startDate&endDate&legalEntity). The 20 HASH tables (Section 5,
--   no usable date) stay HASH(recid) and are unaffected.
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
--   the array gets its own RANGE(date) sub-partition; a per-table plain-leaf
--   DEFAULT ("<tbl>_edef") absorbs any legal entity NOT in the array, so the
--   build is always correct regardless of code-list confidence. Every composite
--   table passes an explicit ARRAY[...] trimmed to the entities it actually holds
--   with >=100k rows (verified live 2026-07-24; see _dataareaid_counts.sql for the
--   11 finance tables and _dataareaid_counts_range.sql for the other 32). Many of
--   the Section 2/3 tables are single-entity ('40' or 'dat'), so their LIST layer
--   is a 1-entity wrapper + _edef leaf. The full 37-entity universe is kept as
--   reference in d365.all_dataareaids() (helper 1h).
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
--        The PARENT is PARTITION BY LIST (dataareaid). For each code in
--        p_dataareaids we create one entity sub-partition that is itself
--        PARTITION BY RANGE (<date>), then fill it with monthly (1e) or
--        quarterly (1f) date children + a per-entity date DEFAULT (absorbs
--        1900/out-of-range rows for that entity).
--        The top-level entity DEFAULT ("<tbl>_edef") is a PLAIN LEAF table (NOT
--        date-subpartitioned): it only ever holds the small sub-threshold tail
--        of legal entities plus any future/unseen code, so date pruning there
--        buys nothing and a full empty date subtree would just bloat the catalog.
--        This keeps single-entity tables at ~= their single-level partition count
--        while still adding the dataareaid pruning layer.
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
    -- top-level entity DEFAULT: plain leaf catch-all (tail entities + future codes)
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s DEFAULT',
                   sch, tbl || '_edef', p_parent);
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
    -- top-level entity DEFAULT: plain leaf catch-all (tail entities + future codes)
    EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I PARTITION OF %s DEFAULT',
                   sch, tbl || '_edef', p_parent);
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
-- SECTION 2 — COMPOSITE LIST(dataareaid) -> RANGE(date), MONTHLY  (15 tables)
-- =====================================================================
-- Converted from single-level RANGE 2026-07-24: dataareaid is the leading key
-- on these too (per stakeholder direction — queries filter legal entity first).
-- Entity lists trimmed to >=100k-row entities (verified live via
-- _dataareaid_counts_range.sql); the tail + any future entity fall into the
-- plain-leaf <tbl>_edef. Most of these are single-entity today ('40' operations,
-- or 'dat' shared GL/product/system), so the LIST layer is a near-free wrapper
-- (+1 _edef leaf) that future-proofs multi-entity growth and lets every query's
-- dataareaid predicate prune uniformly.
-- For each: (a) create parent with the shown PARTITION BY; (b) run the call.
-- =====================================================================

-- generaljournalaccountentry | 475M / 421 GB | modifieddatetime 2020-10 -> | 1 entity: dat (100%)
--   CREATE TABLE d365.generaljournalaccountentry ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.generaljournalaccountentry',
       DATE '2020-10-01', DATE :target_end, 'modifieddatetime', ARRAY['dat']);

-- inventtrans | 495M / 365 GB | datephysical (pre-2019 incl 1900 -> per-entity DEFAULT) | 40 (+20 tail=652)
--   CREATE TABLE d365.inventtrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.inventtrans',
       DATE '2019-01-01', DATE :target_end, 'datephysical', ARRAY['40']);

-- whsworkline | 528M / 435 GB | modifieddatetime | WHS live 2023-02 | 1 entity: 40
--   CREATE TABLE d365.whsworkline ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.whsworkline',
       DATE '2023-02-01', DATE :target_end, 'modifieddatetime', ARRAY['40']);

-- whsworktable | 239M / 133 GB | modifieddatetime | WHS 2023-02 | 1 entity: 40
--   CREATE TABLE d365.whsworktable ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.whsworktable',
       DATE '2023-02-01', DATE :target_end, 'modifieddatetime', ARRAY['40']);

-- whsshipmenttable | 65M / 42 GB | modifieddatetime | WHS 2023-02 | 1 entity: 40
--   CREATE TABLE d365.whsshipmenttable ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.whsshipmenttable',
       DATE '2023-02-01', DATE :target_end, 'modifieddatetime', ARRAY['40']);

-- whsloadtable | 55M / 46 GB | modifieddatetime | WHS 2023-02 | 1 entity: 40
--   CREATE TABLE d365.whsloadtable ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.whsloadtable',
       DATE '2023-02-01', DATE :target_end, 'modifieddatetime', ARRAY['40']);

-- whsloadline | 45M / 58 GB | modifieddatetime | WHS 2023-02 | 1 entity: 40
--   CREATE TABLE d365.whsloadline ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.whsloadline',
       DATE '2023-02-01', DATE :target_end, 'modifieddatetime', ARRAY['40']);

-- usvsalescommissionresptable | 48M / 28 GB | invoicedate 2023 -> | 1 entity: 40
--   CREATE TABLE d365.usvsalescommissionresptable ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.usvsalescommissionresptable',
       DATE '2023-01-01', DATE :target_end, 'invoicedate', ARRAY['40']);

-- subledgerjournalaccountentrydistribution | 42M / 19 GB | createddatetime 2021 -> | 1 entity: dat
--   CREATE TABLE d365.subledgerjournalaccountentrydistribution ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.subledgerjournalaccountentrydistribution',
       DATE '2021-01-01', DATE :target_end, 'createddatetime', ARRAY['dat']);

-- whssalesline | 34M / 20 GB | modifieddatetime 2023 -> | 1 entity: 40 (+20 tail=3)
--   CREATE TABLE d365.whssalesline ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.whssalesline',
       DATE '2023-01-01', DATE :target_end, 'modifieddatetime', ARRAY['40']);

-- usvcuststatement | 31M / 19 GB | transdate 2023 -> | 1 entity: 40
--   CREATE TABLE d365.usvcuststatement ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.usvcuststatement',
       DATE '2023-01-01', DATE :target_end, 'transdate', ARRAY['40']);

-- tmssalestable | 29M / 16 GB | modifieddatetime 2023 -> | 1 entity: 40
--   CREATE TABLE d365.tmssalestable ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.tmssalestable',
       DATE '2023-01-01', DATE :target_end, 'modifieddatetime', ARRAY['40']);

-- usvcustinvoicejourstatement | 19M / 12 GB | invoicedate 2023 -> | 1 entity: 40
--   CREATE TABLE d365.usvcustinvoicejourstatement ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.usvcustinvoicejourstatement',
       DATE '2023-01-01', DATE :target_end, 'invoicedate', ARRAY['40']);

-- custconfirmjour | 57M / 26 GB | confirmdate 2023 -> (D365 cutover) | 1 entity: 40 (+20 tail=1)
--   CREATE TABLE d365.custconfirmjour ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.custconfirmjour',
       DATE '2023-01-01', DATE :target_end, 'confirmdate', ARRAY['40']);

-- sysuserlog | 10M / 6 GB | createddatetime 2018 -> | 1 entity: dat
--   CREATE TABLE d365.sysuserlog ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_monthly_partitions('d365.sysuserlog',
       DATE '2018-01-01', DATE :target_end, 'createddatetime', ARRAY['dat']);

-- =====================================================================
-- SECTION 3 — COMPOSITE LIST(dataareaid) -> RANGE(date), QUARTERLY  (17 tables)
-- =====================================================================
-- Same conversion as Section 2 (dataareaid leading key), quarterly date sub-level.
-- Entity lists trimmed to >=100k-row entities (verified live 2026-07-24); tail +
-- future entities -> plain-leaf <tbl>_edef.
-- =====================================================================

-- inventdim | 328M / 139 GB | modifieddatetime | dim rows since 2025-06 | 40 (+long 1-row tail -> _edef)
--   CREATE TABLE d365.inventdim ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.inventdim',
       DATE '2025-04-01', DATE :target_end, 'modifieddatetime', ARRAY['40']);

-- ecoresvalue | 82M / 42 GB | modifieddatetime 2023 -> | 1 entity: dat (shared product data)
--   CREATE TABLE d365.ecoresvalue ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.ecoresvalue',
       DATE '2023-01-01', DATE :target_end, 'modifieddatetime', ARRAY['dat']);

-- ecorestextvalue | 78M / 29 GB | modifieddatetime 2023 -> | 1 entity: dat (shared product data)
--   CREATE TABLE d365.ecorestextvalue ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.ecorestextvalue',
       DATE '2023-01-01', DATE :target_end, 'modifieddatetime', ARRAY['dat']);

-- taxtrans | 114M / 110 GB | transdate 2019 -> | 40,70 (tail <100k -> _edef)
--   CREATE TABLE d365.taxtrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.taxtrans',
       DATE '2019-01-01', DATE :target_end, 'transdate', ARRAY['40','70']);

-- custsettlement | 84M / 84 GB | transdate 2019 -> | 40,20,30 (tail <100k -> _edef)
--   CREATE TABLE d365.custsettlement ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.custsettlement',
       DATE '2019-01-01', DATE :target_end, 'transdate', ARRAY['40','20','30']);

-- taxjournaltrans | 52M / 39 GB | transdate 2019 -> | 40,70 (tail <100k -> _edef)
--   CREATE TABLE d365.taxjournaltrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.taxjournaltrans',
       DATE '2019-01-01', DATE :target_end, 'transdate', ARRAY['40','70']);

-- custinvoicesaleslink | 30M / 23 GB | invoicedate 2019 -> | 1 entity: 40 (tail <100k -> _edef)
--   CREATE TABLE d365.custinvoicesaleslink ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.custinvoicesaleslink',
       DATE '2019-01-01', DATE :target_end, 'invoicedate', ARRAY['40']);

-- markuptrans | 26M / 28 GB | transdate (post-2019; 1900 -> per-entity DEFAULT) | 40 (+20 tail=4)
--   CREATE TABLE d365.markuptrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.markuptrans',
       DATE '2019-01-01', DATE :target_end, 'transdate', ARRAY['40']);

-- ledgerjournaltable | 27M / 24 GB | createddatetime (1900 -> per-entity DEFAULT) | 40,20 (tail <100k -> _edef)
--   CREATE TABLE d365.ledgerjournaltable ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.ledgerjournaltable',
       DATE '2019-01-01', DATE :target_end, 'createddatetime', ARRAY['40','20']);

-- purchlinehistory | 22M / 24 GB | deliverydate 1900-2029 (1900 -> per-entity DEFAULT) | 1 entity: 40
--   CREATE TABLE d365.purchlinehistory ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.purchlinehistory',
       DATE '2019-01-01', DATE :target_end_delivery, 'deliverydate', ARRAY['40']);

-- vendpackingsliptrans | 18M / 16 GB | accountingdate 2023 -> | 1 entity: 40 (+20 tail=129)
--   CREATE TABLE d365.vendpackingsliptrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.vendpackingsliptrans',
       DATE '2023-01-01', DATE :target_end, 'accountingdate', ARRAY['40']);

-- vendinvoicetrans | 18M / 21 GB | invoicedate 2023 -> | 1 entity: 40 (tail <100k, next 20=96k -> _edef)
--   CREATE TABLE d365.vendinvoicetrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.vendinvoicetrans',
       DATE '2023-01-01', DATE :target_end, 'invoicedate', ARRAY['40']);

-- inventtransferline | 12M / 15 GB | createddatetime 2023 -> | 1 entity: 40
--   CREATE TABLE d365.inventtransferline ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.inventtransferline',
       DATE '2023-01-01', DATE :target_end, 'createddatetime', ARRAY['40']);

-- inventtransfertable | 8.9M / 6.8 GB | createddatetime 2023 -> | 1 entity: 40
--   CREATE TABLE d365.inventtransfertable ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.inventtransfertable',
       DATE '2023-01-01', DATE :target_end, 'createddatetime', ARRAY['40']);

-- inventvaluereporttmpline | 8.7M | transdate 2023 -> (temp-line: confirm w/ API team) | 1 entity: 40
--   CREATE TABLE d365.inventvaluereporttmpline ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.inventvaluereporttmpline',
       DATE '2023-01-01', DATE :target_end, 'transdate', ARRAY['40']);

-- custinteresttrans | 6.5M / 6.9 GB | transdate 2019 -> | 1 entity: 40 (tail <100k -> _edef)
--   CREATE TABLE d365.custinteresttrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.custinteresttrans',
       DATE '2019-01-01', DATE :target_end, 'transdate', ARRAY['40']);

-- inventjournaltrans | 6.2M | transdate 2023 -> | 1 entity: 40 (+20 tail=17)
--   CREATE TABLE d365.inventjournaltrans ( ... ) PARTITION BY LIST (dataareaid);
SELECT d365.ensure_list_quarterly_partitions('d365.inventjournaltrans',
       DATE '2023-01-01', DATE :target_end, 'transdate', ARRAY['40']);

-- =====================================================================
-- SECTION 4 — COMPOSITE  LIST(dataareaid) -> RANGE(date)   (11 tables)
-- =====================================================================
-- These 11 finance/invoice/settlement tables partition dataareaid FIRST
-- (top-level LIST), date SECOND (RANGE sub-partition). Parent PARTITION BY
-- is LIST (dataareaid); the helper creates each entity sub-partition as its
-- own RANGE(date) table plus a per-entity date DEFAULT, and a top-level
-- plain-leaf entity DEFAULT ("<tbl>_edef") for any legal entity not listed.
-- (Same structure as Sections 2 & 3; these 11 just have more multi-entity lists.)
--
-- Each table's ARRAY[...] is TRIMMED to the legal entities that table actually
-- holds with >=100k rows (verified live against Primal 2026-07-24 — see
-- _dataareaid_counts.sql). Every other entity (the long tail of small legal
-- entities, plus any future/unseen one) lands in the table's plain-leaf entity
-- DEFAULT <tbl>_edef. That tail is small (< a few hundred k rows total per
-- table), so a single leaf scans fast; it is intentionally NOT date-subpartitioned.
--
-- Why trim: dataareaid-first multiplies date children by entity count. Using the
-- full 37-entity universe on every table would build ~35-40k leaf partitions,
-- mostly EMPTY subtrees for entities a given table never uses. The >=100k-row
-- cut keeps pruning for every material entity. To promote a tail entity to its
-- own partition later, add its code here and re-run (idempotent) — but see the
-- _edef caveat in Section 7 if data is already loaded.
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
-- the composite tables, the new date children are created under every EXPLICIT
-- entity subtree (<tbl>_<code>). The <tbl>_edef leaf needs no date maintenance
-- (it is not date-subpartitioned). HASH tables need no date maintenance either.
--
-- Production alternative: pg_partman. All date-partitioned tables here are now
-- composite LIST(dataareaid) -> RANGE(date), so the RANGE level to automate lives
-- on each entity subtree, not the top parent. Register each entity subtree once,
-- e.g. for custsettlement's primary entity:
--   SELECT partman.create_parent(
--       p_parent_table := 'd365.custsettlement_40',   -- the RANGE(date) sub-partition
--       p_control      := 'transdate',
--       p_type         := 'range',
--       p_interval     := '3 months',
--       p_premake      := 4);
-- then schedule  SELECT partman.run_maintenance();  on a daily cron to
-- auto-create ahead and (optionally) retire old partitions by retention policy.
-- Simplest path for now: keep re-running this idempotent script for the date roll.
-- =====================================================================
