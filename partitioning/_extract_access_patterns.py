#!/usr/bin/env python3
"""
Access-pattern extractor for partition-key redesign.

For every active .sql file (sprocs / views / functions) across the four IDB
repos, resolve table aliases in FROM/JOIN clauses, then classify each
`alias.column OP rhs` comparison found anywhere in the body (JOIN..ON + WHERE)
as one of:
    param  - RHS is a @parameter or sql variable  (sargable input filter)
    join   - RHS is another table.column           (FK / RecId join key)
    range  - OP is <,>,<=,>=,BETWEEN               (range predicate; may also be param)
    const  - RHS is a literal / function / other

Emits:
    _access_by_table_column.csv   table,column,param,join,range,const,total,n_files
    _access_by_table.csv          table,total_predicates,n_files,top_columns
Reporting is filtered to the 63 partitioned tables (PARTITIONED set) but the
raw scan covers every table referenced.
"""
import os, re, csv, collections

REPOS = ["ais-idb", "boomi-idb", "integration-idb", "rudi-idb"]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# The 63 tables currently flagged for partitioning (from MASTER_PARTITION_LIST.md).
PARTITIONED = {
 "generaljournalaccountentry","inventtrans","whsworkline","whsworktable","whsshipmenttable",
 "whsloadtable","whsloadline","usvsalescommissionresptable","subledgerjournalaccountentrydistribution",
 "whssalesline","usvcuststatement","tmssalestable","usvcustinvoicejourstatement","custconfirmjour",
 "sysuserlog","inventdim","ecoresvalue","ecorestextvalue","taxtrans","custsettlement","taxjournaltrans",
 "custinvoicesaleslink","markuptrans","ledgerjournaltable","purchlinehistory","vendpackingsliptrans",
 "vendinvoicetrans","inventtransferline","inventtransfertable","inventvaluereporttmpline","custinteresttrans",
 "inventjournaltrans","vendsettlement","vendtrans","generaljournalentry","custtrans","custinvoicetrans",
 "custinvoicejour","salesline","salestable","vendinvoicejour","ledgertransvoucherlink","purchline",
 "inventsum","inventtransorigin","usvexclusionprogramcustomerproducts","ecoresattributevalue",
 "ecoresinstancevalue","inventtransoriginsalesline","ledgerentryjournal","usvecoresprodpartsattributes",
 "usvecoresprodtiresattributes","usvecoresprodlubeschemicalattributes","whsworklinecyclecount",
 "usvecoresprodtiresaccessoriesattributes","usvecoresprodmicsitemsattributes","usvecoresprodexhuastattributes",
 "usvecoresprodtubesattributes","usvecoresprodtiresattributesext","reqitemtable","usvsspprogramcustomer",
 "usvsspprogramproducts","vendinvoiceinfoline",
}

SQL_KEYWORDS = {
 "select","from","where","join","inner","left","right","outer","full","cross","on","and","or",
 "group","order","by","having","as","with","union","all","insert","update","delete","into","set",
 "values","when","then","case","else","end","exists","not","in","is","null","like","between",
 "declare","begin","end;","top","distinct","apply","pivot","unpivot","over","partition","using",
}

def strip_comments(sql):
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    sql = re.sub(r"--[^\n]*", " ", sql)
    return sql

def norm(tbl):
    # strip brackets/quotes/schema -> lowercase base name
    tbl = tbl.replace("[","").replace("]","").replace('"',"").strip()
    if "." in tbl:
        tbl = tbl.split(".")[-1]
    return tbl.lower()

# FROM/JOIN <tableref> [AS] <alias>
# tableref: optionally-bracketed, optionally schema-qualified identifier
TABLEREF = r"(\[?[A-Za-z_][\w]*\]?(?:\.\[?[A-Za-z_][\w]*\]?){0,2})"
ALIAS    = r"(?:\s+(?:as\s+)?(\[?[A-Za-z_][\w]*\]?))?"
FROMJOIN = re.compile(r"\b(?:from|join)\s+" + TABLEREF + ALIAS, re.I)

# alias.column OP rhs   (rhs captured coarsely up to a boundary)
CMP = re.compile(
    r"\b(\[?[A-Za-z_][\w]*\]?)\.\[?([A-Za-z_][\w]*)\]?\s*"
    r"(=|<>|!=|>=|<=|>|<|\bbetween\b|\blike\b|\bin\b)\s*"
    r"([^\s\)]+)", re.I)

def build_alias_map(sql):
    amap = {}
    for m in FROMJOIN.finditer(sql):
        tref, alias = m.group(1), m.group(2)
        tbl = norm(tref)
        amap[tbl] = tbl  # table name references itself
        if alias:
            a = alias.replace("[","").replace("]","").lower()
            if a not in SQL_KEYWORDS:
                amap[a] = tbl
    return amap

def classify_rhs(op, rhs):
    op = op.lower()
    is_range = op in ("<",">","<=",">=","between")
    rhs = rhs.strip()
    if rhs.startswith("@") or rhs.lower().startswith("iif") is False and rhs.startswith("@"):
        kind = "param"
    elif rhs.startswith("@"):
        kind = "param"
    elif re.match(r"^\[?[A-Za-z_][\w]*\]?\.\[?[A-Za-z_]", rhs):
        kind = "join"
    else:
        kind = "const"
    return kind, is_range

# per (table,col): counters
cc = collections.defaultdict(lambda: collections.Counter())
files_for = collections.defaultdict(set)          # (table,col) -> files
tblfiles  = collections.defaultdict(set)           # table -> files (referenced at all)

scanned = 0
for repo in REPOS:
    base = os.path.join(ROOT, repo, "src")
    for dirpath, _, files in os.walk(base):
        if "/Obsolete/" in dirpath or "/quarantine/" in dirpath:
            continue
        for fn in files:
            if not fn.endswith(".sql"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, ROOT)
            try:
                sql = open(path, encoding="utf-8", errors="ignore").read()
            except Exception:
                continue
            sql = strip_comments(sql)
            scanned += 1
            amap = build_alias_map(sql)
            # note table references
            for t in set(amap.values()):
                tblfiles[t].add(rel)
            for m in CMP.finditer(sql):
                alias, col, op, rhs = m.group(1), m.group(2), m.group(3), m.group(4)
                a = alias.replace("[","").replace("]","").lower()
                tbl = amap.get(a)
                if not tbl:
                    continue
                col = col.lower()
                kind, is_range = classify_rhs(op, rhs)
                cc[(tbl,col)][kind] += 1
                if is_range:
                    cc[(tbl,col)]["range"] += 1
                cc[(tbl,col)]["total"] += 1
                files_for[(tbl,col)].add(rel)

# ---- write per-table-column csv (partitioned tables only) ----
outdir = os.path.join(ROOT, "centrisapiconversion", "partitioning")
with open(os.path.join(outdir,"_access_by_table_column.csv"),"w",newline="") as f:
    w = csv.writer(f)
    w.writerow(["table","column","param","join","range","const","total","n_files"])
    rows = []
    for (tbl,col),ctr in cc.items():
        if tbl not in PARTITIONED:
            continue
        rows.append((tbl,col,ctr["param"],ctr["join"],ctr["range"],ctr["const"],
                     ctr["total"],len(files_for[(tbl,col)])))
    rows.sort(key=lambda r:(r[0], -r[6]))
    w.writerows(rows)

# ---- write per-table summary with ranked access columns ----
with open(os.path.join(outdir,"_access_by_table.csv"),"w",newline="") as f:
    w = csv.writer(f)
    w.writerow(["table","n_files_referencing","total_predicates","ranked_access_columns(col:total[p=param,j=join,r=range])"])
    for tbl in sorted(PARTITIONED):
        cols = [(col,ctr) for (t,col),ctr in cc.items() if t==tbl]
        cols.sort(key=lambda x:-x[1]["total"])
        total = sum(c[1]["total"] for c in cols)
        ranked = " | ".join(
            f"{col}:{ctr['total']}[p{ctr['param']},j{ctr['join']},r{ctr['range']}]"
            for col,ctr in cols[:8])
        w.writerow([tbl, len(tblfiles.get(tbl,set())), total, ranked])

print(f"scanned {scanned} active .sql files")
print(f"wrote _access_by_table_column.csv and _access_by_table.csv")
