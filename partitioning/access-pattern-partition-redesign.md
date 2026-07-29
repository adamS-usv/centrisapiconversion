# Access-Pattern Partition Redesign — D365 → AlloyDB

**Supersedes the partition-*key* choices in** `MASTER_PARTITION_LIST.md` / `create-partitions.sql`
(which were derived from **data shape** — cleanest multi-year date column).
**Analyzed:** 2026-07-26. **Companion diagnosis:** `sproc-partition-fit-analysis.md`.
**Evidence:** `_access_by_table.csv`, `_access_by_table_column.csv`,
`_partition_redesign_recommendations.csv` (regenerate with
`_extract_access_patterns.py` → `_build_redesign_recs.py`).

---

## 1. Why redo it

The original recommendations partitioned each large table on its **best date column**
(`invoicedate`, `transdate`, `deliverydate`, …). The companion fit-analysis then found the
uncomfortable truth, which this pass **quantifies**: *the partition key and the access pattern
disagree almost everywhere.* Sprocs and views reach these tables by **business keys and RecId/FK
joins** — `INVOICEID`, `SALESID`, `CUSTACCOUNT`, `PURCHID`, `INVENTTRANSID`, `RECID`, `PROGRAMID`,
`INVOICEACCOUNT` — not by the date column the partitions are built on. A date-RANGE partition only
prunes if the query filters the date; for a point lookup by `INVOICEID` it forces the planner to
probe **every** partition, which is *slower* than an unpartitioned B-tree.

This document re-derives the partition key for all 63 flagged tables **from the predicates the code
actually issues.**

### Method (reproducible)

`_extract_access_patterns.py` scanned **1,015 active `.sql` files** (sprocs, views, functions across
`ais-idb`, `boomi-idb`, `integration-idb`, `rudi-idb`; `Obsolete/` + `quarantine/` + `*.disabled`
excluded). For every file it resolves table aliases in `FROM`/`JOIN`, then classifies each
`alias.column OP rhs` comparison in the body as **param** (`= @p` — sargable input filter),
**join** (`= other.col` — FK/RecId join key), **range** (`<,>,between`), or **const**. Counts are
aggregated per `(table, column)`. The full mechanical output is in the two `_access_by_*` CSVs;
the highest-traffic tables were then read by hand to confirm the mechanical verdict.

> **Scope caveat (unchanged).** "No active consumer" means *no reference in these four repos*.
> Tables may still be read by Boomi flows, Esker, Ventus, or future APIs. Treat **DEFER** as
> "confirm the consumer, then align," not "delete."

---

## 2. Headline: partition by the join key, in co-partition families

The dominant access column, straight from the evidence (`total`[`param`,`join`,`range`]):

| Table | Top access columns (from `_access_by_table_column.csv`) | Old key |
|---|---|---|
| `custinvoicejour` | `salesid` 42[p2,**j39**] · `invoiceid` 30[p11,j18] · `orderaccount` 30[p5,j24] · `invoicedate` 41[**p34**,r40] | invoicedate |
| `custinvoicetrans` | `itemid` 24[j22] · `invoiceid` 22[j17] · `salesid` 10[j10] | invoicedate |
| `salestable` | `salesid` 41[p11,**j29**] · `custaccount` 17[p8,j8] · `invoiceaccount` 22[p13] · (`salestype`/`salesstatus` = enum consts) | deliverydate |
| `salesline` | `salesid` 31[p4,**j27**] · `itemid` 30[**j29**] · `inventtransid` 8[j8] | shippingdaterequested |
| `markuptrans` | `transrecid` 83[p15,**j68**] · `markupcode` (const) · `transtableid` (const) | transdate |
| `inventtrans` | `inventtransorigin` 16[**j15**] · `statusissue` (const/range) | datephysical |
| `inventtransorigin` | `inventtransid` 10[**j10**] | recid (hash) |
| `purchline` | `purchid` 4[**p3**,j1] | deliverydate |
| `vendtrans` | `accountnum` · `invoice` · `dataareaid` (all param) | transdate |
| `custtrans` | `accountnum` 9[p1,j8] · `recid` 8[j8] · `invoice` (param) | modifieddatetime |
| `taxtrans` | `sourcerecid` 10[**j6**] · `voucher` 6[j6] | transdate |
| `usvsspprogramcustomer` | `custaccount` 5[**p3**] · `programid` 4[j4] · `invoiceaccount` 3 | recid (hash) |

None of the old date keys appear as the leading predicate — **except** the WHS EDI tables and one
genuine dual case (see §4). Because the code reaches related tables **through the same join key**,
the redesign groups them into **co-partition families**: partition every table in a family by that
key, with the **same HASH modulus**, so the join executes as a partition-wise join and every point
lookup prunes to a single partition.

### Co-partition families

| Family | Key | Modulus | Tables | Payoff |
|---|---|:--:|---|---|
| **A · Sales order** | `SALESID` | 16 | `salestable`, `salesline`, `custconfirmjour`, `tmssalestable` | `SL.SALESID = ST.SALESID` (8 procs) → partition-wise; point lookup by SalesId → 1 partition |
| **B · Customer invoice** | `INVOICEID` | 16 | `custinvoicejour`, `custinvoicetrans`, `custinvoicesaleslink`* | `CIT.INVOICEID = CIJ.INVOICEID` → partition-wise; `/invoices/{id}` → 1 partition |
| **C · Inventory txn** | `RECID` / `INVENTTRANSID` | 8 | `inventtransorigin`(recid), `inventtrans`(inventtransorigin→recid), `inventtransoriginsalesline`, `whssalesline`(inventtransid), `inventsum` | `ITRANS.INVENTTRANSORIGIN = ITO.RECID` → partition-wise |
| **D · Line charges** | `TRANSRECID` | 16 | `markuptrans` | `MT.TRANSRECID = SL.RECID / CIT.RECID` (charge fan-out) |
| **E · Purchase order** | `PURCHID` | 8/4 | `purchline`, `purchlinehistory` | `WHERE PURCHID=@p` → 1 partition |
| **F · Vendor finance** | `ACCOUNTNUM`/`INVOICEACCOUNT` | 8/4 | `vendtrans`, `vendsettlement`, `vendinvoicejour`, `vendinvoicetrans`, … | vendor lookups |
| **G · Customer finance** | `ACCOUNTNUM`/`TRANSRECID` | 8 | `custtrans`(accountnum), `custsettlement`(transrecid→custtrans.recid) | settlement join partition-wise |
| **H · Program/exclusion** | `INVOICEACCOUNT` | 8/4 | `usvsspprogramcustomer`, `usvsspprogramproducts`, `usvexclusionprogramcustomerproducts` | account lookups; never RecId |
| **I · General ledger** | `RECID` / `GENERALJOURNALENTRY` / `VOUCHER` / `SOURCERECID` | 8/4 | `generaljournalentry`(recid), `generaljournalaccountentry`(gje→recid), `taxtrans`(sourcerecid), `ledger*`, `subledger…` | GL voucher/recid joins |
| **K · Reference** | natural join key | 8/4 | `inventdim`(inventdimid), `ecoresvalue`/`ecorestextvalue`(recid), `inventtransfer*`(transferid), `ecores*attr` catalogs | align to the join key |

\* `custinvoicesaleslink` bridges `SALESID`↔`INVOICEID`; partition by `SALESID` to co-partition with
Family A, or `INVOICEID` for Family B — pick per the dominant traversal direction.

---

## 3. Per-table recommendation matrix

**Verdicts:** **REDESIGN** date→business-key HASH · **KEEP-HASH** already HASH, realign column ·
**KEEP-RANGE** date-window access is real · **DEFER** no in-repo consumer, confirm then align.
Full machine-readable version: `_partition_redesign_recommendations.csv`.

### REDESIGN — switch from date-RANGE to business-key HASH (27)

| Table | Family | Old key | → New key (HASH) | Evidence |
|---|---|---|---|---|
| `salestable` | A | RANGE deliverydate | `salesid` /16 | salesid j29; deliverydate never filtered |
| `salesline` | A | RANGE shippingdaterequested | `salesid` /16 | salesid j27, itemid j29 |
| `custconfirmjour` | A | RANGE confirmdate | `salesid` /8 | salesid+confirmdocnum joins |
| `tmssalestable` | A | RANGE modifieddatetime | `salesid` /8 | salesid+dataareaid join |
| `custinvoicejour` | B | RANGE invoicedate + LIST | `invoiceid` /16 **+ local btree(invoicedate)** | **dual** — see §4 |
| `custinvoicetrans` | B | RANGE invoicedate + LIST | `invoiceid` /16 | invoiceid j17, salesid j10 |
| `custinvoicesaleslink` | B | RANGE invoicedate | `salesid` /8 | link keyed by salesid/invoiceid |
| `inventtrans` | C | RANGE datephysical | `inventtransorigin` /8 | j15 → inventtransorigin.recid |
| `whssalesline` | C | RANGE modifieddatetime | `inventtransid` /8 | inventtransid j6 |
| `markuptrans` | D | RANGE transdate + LIST | `transrecid` /16 | transrecid j68 → line.recid |
| `purchline` | E | RANGE deliverydate + LIST | `purchid` /8 | WHERE purchid=@p |
| `purchlinehistory` | E | RANGE deliverydate | `purchid` /4 | align to purchline |
| `vendtrans` | F | RANGE transdate + LIST | `accountnum` /8 **+ btree(invoice)** | dataareaid+accountnum+invoice params |
| `custtrans` | G | RANGE modifieddatetime + LIST | `accountnum` /8 | accountnum, recid j8 |
| `custsettlement` | G | RANGE transdate | `transrecid` /8 | transrecid→custtrans.recid |
| `usvsspprogramcustomer` | H | HASH recid | `invoiceaccount` /4 | custaccount/invoiceaccount/programid |
| `usvsspprogramproducts` | H | HASH recid | `invoiceaccount` /4 | invoiceaccount/programid/itemid |
| `usvexclusionprogramcustomerproducts` | H | HASH recid | `invoiceaccount` /8 | invoiceaccount; 73 GB |
| `generaljournalentry` | I | RANGE accountingdate + LIST | `recid` /8 | child joins by recid |
| `generaljournalaccountentry` | I | RANGE modifieddatetime | `generaljournalentry` /8 | gjae.gje = gje.recid |
| `taxtrans` | I | RANGE transdate + LIST | `sourcerecid` /8 | sourcerecid j6, voucher j6 |
| `ledgerjournaltable` | I | RANGE createddatetime | `recid` /4 | journalname + posteddatetime (mild date) |
| `inventdim` | K | RANGE modifieddatetime | `inventdimid` /8 | universally joined by inventdimid |
| `ecoresvalue` | K | RANGE modifieddatetime | `recid` /8 | joined by recid via v_ecoresvalue |
| `ecorestextvalue` | K | RANGE modifieddatetime | `recid` /8 | joined by recid |
| `inventtransferline` | K | RANGE createddatetime | `transferid` /4 | WHERE transferid=@t |
| `inventtransfertable` | K | RANGE createddatetime | `transferid` /4 | WHERE transferid=@t |

### KEEP-HASH — already HASH; realign the column, count stays (10)

`inventtransorigin` → keep HASH(`recid`) so `inventtrans` co-partitions; **add btree(`inventtransid`)**
for the entry lookup. `inventtransoriginsalesline`, `inventsum` (consider HASH(`itemid`)),
`ecoresattributevalue`, `ecoresinstancevalue`, `ledgerentryjournal`, `reqitemtable`,
`vendinvoiceinfoline`, `whsworklinecyclecount`, and the 8 `usvecoresprod*attributes` catalogs — no
predicate signal; HASH(`recid`) is correct for parallel scan/vacuum.

### KEEP-RANGE — date-window access is real (2 active)

`whsloadtable`, `whsloadline` — `sp856OutboundCombinedASN…` filters
`ModifiedDateTime >= @LoadModifiedDate AND < @LoadModifiedLTDate`. This is the **one** genuine
date-window pattern in the four repos. **Keep RANGE(`modifieddatetime`).**

### DEFER — no active in-repo consumer (24)

`whsworkline`, `whsworktable`, `whsshipmenttable` (WHS; no active consumer — prior refs were in
disabled procs), `sysuserlog`, `vendsettlement`, `vendinvoicejour`, `vendinvoicetrans`,
`vendpackingsliptrans`, `custinteresttrans`, `subledgerjournalaccountentrydistribution`,
`ledgertransvoucherlink`, `taxjournaltrans`, `inventjournaltrans`, `inventvaluereporttmpline`,
`usvcuststatement`, `usvcustinvoicejourstatement`, `usvsalescommissionresptable`. For each, the
**note** in the CSV gives the key to use *once a consumer is confirmed* (statement views →
account-keyed HASH; voucher link → `VOUCHER`; vendor tables → Family F). Until then, HASH(`recid`)
for maintenance parallelism, or leave unpartitioned.

---

## 4. The one dual case: `custinvoicejour`

Unlike the point-lookup-only tables, `custinvoicejour` has **two** real access patterns:

- **Point lookup / join** — `INVOICEID` (30 files), `SALESID` (j39), `ORDERACCOUNT` (j24),
  `RECID`. This is `spGetInvoiceData`, `spOrderStatusDetail`, `spRWAInvoiceData*`.
- **Date-range analytics** — `invoicedate` filtered as a range in **19 files** (`p34`, `r40`):
  `spGetDirectSalesData*`, `spGetSSPData*`, `spGetSelloutData*`, `spGetCMPData*`,
  `AllInvoicesSummary`, `USVOrderStatusSummaryByInvoiceAccountAndDateRange`.
  *(This corrects the prior "invoicedate never filtered" claim — it is, in the vendor/sellout
  reporting family.)*

Recommendation: **HASH(`invoiceid`) /16** (serves the higher-traffic point-lookup + co-partitions
with `custinvoicetrans`), **plus a local btree on `invoicedate`** on every partition so the
date-range reporting procs still get an index seek (they scan all 16 partitions, but each via a
cheap dated index range — acceptable for the lower-frequency analytics path). If the date-range
extracts turn out to dominate load, revisit with composite `HASH(invoiceid)` sub-partitioned or a
separate reporting replica. Flag for the API owners (§6).

---

## 5. PostgreSQL / AlloyDB implementation notes

1. **Partition-wise joins require identical schemes.** Two tables join partition-wise only if they
   are HASH-partitioned on the join column with the **same type and same modulus**. Hence the fixed
   family moduli (A/B/D = 16; C/E/G/H/I = 8; small tables = 4). Keep them equal within a family; set
   `enable_partitionwise_join = on`.
2. **The partition key must be in every PK/UNIQUE constraint.** These D365 tables key on `RECID`
   (Fivetran merges on it). HASH on a business key means the PK becomes `(RECID)` non-unique-indexed
   for the merge *plus* the partition still needs `recid` findable — keep the **btree on `recid`**
   the master list already mandates (Fivetran ID index) on every partitioned parent; it cascades to
   children. Where the business key ≠ `recid`, add a **local btree on the business key** too.
3. **Point-lookup pruning.** `WHERE invoiceid = @p` on `HASH(invoiceid)` prunes to exactly one
   partition — the whole point of the redesign. Verify with `EXPLAIN` that only one child is scanned.
4. **`DataAreaId` is no longer the leading key.** The prior design led with `LIST(dataareaid)`.
   Under HASH-by-business-key, `dataareaid` becomes a **local btree / composite-index prefix**, not a
   partition level. This is fine: the business key already prunes to one partition; `dataareaid`
   filters within it. (Note the master list flagged `--AND x.DATAAREAID = @LegalEntity` commented out
   in several ais procs; re-enabling those still helps index selectivity but is no longer required
   for pruning.)
5. **HASH loses time-based retention rolloff.** Date-RANGE made it trivial to drop old months. If any
   table needs age-based purge (`sysuserlog`, WHS), keep it RANGE (already recommended) or add a
   scheduled delete.

---

## 6. Next steps / open questions

1. **Confirm the live `vN` procs.** Verdicts depend on which `spOrderStatusDetail` (v3–v15),
   `spRWAInvoiceMatchingService` (v2–v9), `spGetInvoiceRemainder` (v2–v4) is in production. The scan
   used the un-suffixed active files; confirm these are live (master plan Open Q §I.1).
2. **`custinvoicejour` dual pattern (§4).** API owners: is the point-lookup `/invoices/{id}` or the
   date-range vendor/sellout extract the dominant load? Determines HASH-only vs. composite.
3. **External consumers.** Do Boomi/Esker/Ventus/reporting add date or `DataAreaId` filters not in
   these repos? This decides whether the 24 DEFER tables benefit from any partitioning.
4. **DEFER tables' keys.** Confirm the statement views' API path key (account vs. date),
   `ledgertransvoucherlink` voucher-lookup path, and the vendor Finance API contract, then apply the
   Family F/I/L keys noted in the CSV.
5. **Record the decision.** This reverses the "DataAreaId-first, date-RANGE" direction in
   `MASTER_PARTITION_LIST.md` (2026-07-24). Worth an ADR entry ("Partition D365 tables by access-path
   business key, not landing date") so the reversal is durable — happy to add it to the vault
   `Architecture-Decisions.md` log.
