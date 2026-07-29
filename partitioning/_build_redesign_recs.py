#!/usr/bin/env python3
"""Build _partition_redesign_recommendations.csv from access evidence + family map."""
import csv, os, collections

HERE = os.path.dirname(os.path.abspath(__file__))

# load evidence: (table,col) -> counters
ev = collections.defaultdict(dict)
with open(os.path.join(HERE,"_access_by_table_column.csv")) as f:
    for r in csv.DictReader(f):
        ev[r["table"]][r["column"]] = r
nfiles = {}
with open(os.path.join(HERE,"_access_by_table.csv")) as f:
    for r in csv.DictReader(f):
        nfiles[r["table"]] = r["n_files_referencing"]

# family, new_key, new_strategy, modulus, dominant access evidence col, verdict, note
# strategy: HASH / RANGE(keep) / DEFER
R = [
 # table, family, old_key, new_strategy, new_key, mod, evid_col, verdict, note
 ("salestable","A SalesId","RANGE deliverydate","HASH","salesid",16,"salesid","REDESIGN","Entered by SALESID/CUSTACCOUNT; deliverydate never filtered. Co-partition w/ salesline for partition-wise SALESID join."),
 ("salesline","A SalesId","RANGE shippingdaterequested","HASH","salesid",16,"salesid","REDESIGN","salesid j27 / itemid j29; date never filtered. Same modulus as salestable."),
 ("custconfirmjour","A SalesId","RANGE confirmdate","HASH","salesid",8,"salesid","REDESIGN","Joined by SALESID+CONFIRMDOCNUM; confirmdate not filtered."),
 ("tmssalestable","A SalesId","RANGE modifieddatetime","HASH","salesid",8,"salesid","REDESIGN","Joined by SALESID+DATAAREAID."),
 ("custinvoicejour","B InvoiceId","RANGE invoicedate + LIST dai","HASH","invoiceid",16,"invoiceid","REDESIGN*","DUAL pattern: point-lookup INVOICEID/SALESID (30+ files) AND date-range analytics (invoicedate p34/r40, 19 files). HASH(invoiceid)+local btree(invoicedate). Co-partition w/ custinvoicetrans."),
 ("custinvoicetrans","B InvoiceId","RANGE invoicedate + LIST dai","HASH","invoiceid",16,"invoiceid","REDESIGN","invoiceid j17 / salesid j10 / itemid j22; date only as join-equality. Same modulus as custinvoicejour."),
 ("custinvoicesaleslink","B InvoiceId","RANGE invoicedate","HASH","salesid",8,"origsalesid","REDESIGN","Link table SALESID<->INVOICEID; keyed by (orig)salesid/invoiceid, not date."),
 ("inventtransorigin","C InventTransId","HASH recid","HASH","recid",8,"inventtransid","KEEP-HASH","Entered by INVENTTRANSID (j10); child inventtrans joins by RECID. Keep HASH(recid) so inventtrans co-partitions; add btree(inventtransid) for the entry lookup."),
 ("inventtrans","C InventTransId","RANGE datephysical","HASH","inventtransorigin",8,"inventtransorigin","REDESIGN","Joined ITRANS.INVENTTRANSORIGIN = inventtransorigin.RECID (j15); datephysical never filtered. HASH(inventtransorigin) co-partitions w/ inventtransorigin(recid)."),
 ("inventtransoriginsalesline","C InventTransId","HASH recid","HASH","recid",8,"salesline","KEEP-HASH","Joined by FK; keep HASH(recid)."),
 ("whssalesline","C InventTransId","RANGE modifieddatetime","HASH","inventtransid",8,"inventtransid","REDESIGN","Joined by INVENTTRANSID (j6)+DATAAREAID; modifieddatetime selected but not filtered."),
 ("inventsum","C InventTransId","HASH recid","HASH","recid",16,"itemid","KEEP-HASH","Entered by ITEMID+dims, never RECID. HASH(recid) = parallel scan only; consider HASH(itemid)."),
 ("markuptrans","D TransRecId","RANGE transdate + LIST dai","HASH","transrecid",16,"transrecid","REDESIGN","transrecid j68 -> salesline.RECID / custinvoicetrans.RECID; transdate never filtered. HASH(transrecid)."),
 ("purchline","E PurchId","RANGE deliverydate + LIST dai","HASH","purchid",8,"purchid","REDESIGN","WHERE PURCHID=@p AND DATAAREAID=@le; deliverydate never filtered."),
 ("purchlinehistory","E PurchId","RANGE deliverydate","HASH","purchid",4,"purchid","REDESIGN","No active consumer; align to purchline family by PURCHID."),
 ("vendtrans","F Vendor","RANGE transdate + LIST dai","HASH","accountnum",8,"accountnum","REDESIGN","WHERE DATAAREAID+ACCOUNTNUM+INVOICE; transdate absent. HASH(accountnum)+btree(invoice)."),
 ("vendsettlement","F Vendor","RANGE transdate + LIST dai","HASH","accountnum",8,"","DEFER","No active consumer (Ventus retired). HASH(accountnum) to match vendtrans, or defer."),
 ("vendinvoicejour","F Vendor","RANGE invoicedate + LIST dai","HASH","invoiceaccount",4,"","DEFER","No active consumer; future vendor Invoice API -> INVOICEACCOUNT/INVOICEID."),
 ("vendinvoicetrans","F Vendor","RANGE invoicedate","HASH","invoiceid",4,"","DEFER","No active consumer."),
 ("vendpackingsliptrans","F Vendor","RANGE accountingdate","HASH","recid",4,"","DEFER","No active consumer."),
 ("vendinvoiceinfoline","F Vendor","HASH recid","HASH","recid",4,"","KEEP-HASH","No active consumer; keep HASH(recid)."),
 ("custtrans","G CustFinance","RANGE modifieddatetime + LIST dai","HASH","accountnum",8,"accountnum","REDESIGN","COMPASSValidateCustomerInvoice: DATAAREAID+ACCOUNTNUM+INVOICE; recid j8 for settlement joins. HASH(accountnum)."),
 ("custsettlement","G CustFinance","RANGE transdate","HASH","transrecid",8,"transrecid","REDESIGN","Joined by TRANSRECID/OFFSETRECID -> custtrans.RECID; transdate not filtered."),
 ("custinteresttrans","G CustFinance","RANGE transdate","HASH","recid",4,"","DEFER","No active consumer."),
 ("usvsspprogramcustomer","H Program","HASH recid","HASH","invoiceaccount",4,"custaccount","REDESIGN","Filtered by CUSTACCOUNT/INVOICEACCOUNT/PROGRAMID, never RECID."),
 ("usvsspprogramproducts","H Program","HASH recid","HASH","invoiceaccount",4,"invoiceaccount","REDESIGN","Joined by INVOICEACCOUNT/PROGRAMID/ITEMID, never RECID."),
 ("usvexclusionprogramcustomerproducts","H Program","HASH recid","HASH","invoiceaccount",8,"invoiceaccount","REDESIGN","Filtered by INVOICEACCOUNT; never RECID. 73GB - key alignment matters."),
 ("generaljournalentry","I GL","RANGE accountingdate + LIST dai","HASH","recid",8,"recid","REDESIGN","Child gjae joins by RECID; entered by SUBLEDGERVOUCHER / Ledger.Name; accountingdate absent."),
 ("generaljournalaccountentry","I GL","RANGE modifieddatetime","HASH","generaljournalentry",8,"generaljournalentry","REDESIGN","Joined gjae.GENERALJOURNALENTRY = gje.RECID (j2); modifieddatetime never filtered. Co-partition w/ generaljournalentry."),
 ("subledgerjournalaccountentrydistribution","I GL","RANGE createddatetime","HASH","recid",4,"","DEFER","No active consumer."),
 ("ledgertransvoucherlink","I GL","RANGE transdate + LIST dai","HASH","voucher",4,"","DEFER","No active consumer; voucher-lookup path (rudi GetVoucherPostedDate) -> VOUCHER."),
 ("ledgerjournaltable","I GL","RANGE createddatetime","HASH","recid",4,"posteddatetime","REDESIGN","Filtered by JOURNALNAME + POSTEDDATETIME range (p3/r3). Mild date use; HASH(recid) or keep small RANGE."),
 ("ledgerentryjournal","I GL","HASH recid","HASH","recid",8,"","KEEP-HASH","No active consumer; keep HASH(recid)."),
 ("taxtrans","I GL","RANGE transdate + LIST dai","HASH","sourcerecid",8,"sourcerecid","REDESIGN","Joined by SOURCERECID (j6)/VOUCHER; transdate never filtered."),
 ("taxjournaltrans","I GL","RANGE transdate","HASH","recid",4,"","DEFER","No active consumer."),
 ("inventdim","K Ref","RANGE modifieddatetime","HASH","inventdimid",8,"inventdimid","REDESIGN","Universally joined by INVENTDIMID; date never filtered."),
 ("ecoresvalue","K Ref","RANGE modifieddatetime","HASH","recid",8,"recid","REDESIGN","Joined by RECID via v_ecoresvalue; date never filtered."),
 ("ecorestextvalue","K Ref","RANGE modifieddatetime","HASH","recid",8,"recid","REDESIGN","Joined by RECID; date never filtered."),
 ("ecoresattributevalue","K Ref","HASH recid","HASH","recid",8,"value","KEEP-HASH","Filtered by ATTRIBUTE/VALUE; keep HASH(recid)."),
 ("ecoresinstancevalue","K Ref","HASH recid","HASH","recid",8,"","KEEP-HASH","Joined by PRODUCT/ITEMID; keep HASH(recid)."),
 ("inventtransferline","K Ref","RANGE createddatetime","HASH","transferid",4,"transferid","REDESIGN","WHERE TRANSFERID=@t AND DATAAREAID; createddatetime not filtered."),
 ("inventtransfertable","K Ref","RANGE createddatetime","HASH","transferid",4,"transferid","REDESIGN","WHERE TRANSFERID=@t AND DATAAREAID; createddatetime not filtered."),
 ("inventjournaltrans","K Ref","RANGE transdate","HASH","recid",4,"","DEFER","No active consumer."),
 ("inventvaluereporttmpline","K Ref","RANGE transdate","HASH","recid",4,"","DEFER","Temp-line table; consider no partitioning."),
 ("reqitemtable","K Ref","HASH recid","HASH","recid",4,"","KEEP-HASH","No active consumer; keep HASH(recid)."),
 # WHS date-window family -- KEEP RANGE
 ("whsloadtable","J WHS-date","RANGE modifieddatetime","KEEP-RANGE","modifieddatetime",None,"modifieddatetime","KEEP-RANGE","sp856 EDI: WHERE modifieddatetime >= @LoadModifiedDate AND < @LoadModifiedLTDate. Genuine date-window - keep RANGE."),
 ("whsloadline","J WHS-date","RANGE modifieddatetime","KEEP-RANGE","modifieddatetime",None,"modifieddatetime","KEEP-RANGE","sp856 filters wll.modifieddatetime >= @LoadModifiedDate. Keep RANGE."),
 ("whsworkline","J WHS-date","RANGE modifieddatetime","KEEP-RANGE","modifieddatetime",None,"","DEFER","No active consumer in current repo (was sp856/WaveId in disabled procs). Keep RANGE or defer."),
 ("whsworktable","J WHS-date","RANGE modifieddatetime","KEEP-RANGE","modifieddatetime",None,"","DEFER","No active consumer in current repo. Keep RANGE or defer."),
 ("whsshipmenttable","J WHS-date","RANGE modifieddatetime","KEEP-RANGE","modifieddatetime",None,"","DEFER","No active consumer. Keep RANGE (future Warehouse API date filter)."),
 ("whsworklinecyclecount","J WHS-date","HASH recid","HASH","recid",4,"","KEEP-HASH","No active consumer; keep HASH(recid)."),
 # statement / commission views -- account-keyed
 ("usvcuststatement","L Statement","RANGE transdate","HASH","custaccount",8,"","DEFER","View -> /finance/customers/{acct}/statement; API path-keyed by account. HASH(custaccount) or keep date+btree."),
 ("usvcustinvoicejourstatement","L Statement","RANGE invoicedate","HASH","invoiceaccount",4,"","DEFER","Statement API path-keyed by account. HASH(invoiceaccount) or keep date."),
 ("usvsalescommissionresptable","L Statement","RANGE invoicedate","HASH","invoiceaccount",8,"","DEFER","View -> Vendor commission API; invoicedate not filtered by consumers."),
 ("sysuserlog","M System","RANGE createddatetime","KEEP-RANGE","createddatetime",None,"","DEFER","System log, no IDB consumer. Keep RANGE for retention rolloff, or defer."),
 # ecores product-attribute catalogs (8) - no consumer, keep HASH(recid)
 ("usvecoresprodtiresattributes","K Ref","HASH recid","HASH","recid",4,"","KEEP-HASH","Product-attribute catalog; no IDB consumer."),
 ("usvecoresprodpartsattributes","K Ref","HASH recid","HASH","recid",4,"","KEEP-HASH","Product-attribute catalog; no IDB consumer."),
 ("usvecoresprodtubesattributes","K Ref","HASH recid","HASH","recid",4,"","KEEP-HASH","Product-attribute catalog; no IDB consumer."),
 ("usvecoresprodlubeschemicalattributes","K Ref","HASH recid","HASH","recid",4,"","KEEP-HASH","Product-attribute catalog; no IDB consumer."),
 ("usvecoresprodtiresaccessoriesattributes","K Ref","HASH recid","HASH","recid",4,"","KEEP-HASH","Product-attribute catalog; no IDB consumer."),
 ("usvecoresprodmicsitemsattributes","K Ref","HASH recid","HASH","recid",4,"","KEEP-HASH","Product-attribute catalog; no IDB consumer."),
 ("usvecoresprodexhuastattributes","K Ref","HASH recid","HASH","recid",4,"","KEEP-HASH","Product-attribute catalog; no IDB consumer."),
 ("usvecoresprodtiresattributesext","K Ref","HASH recid","HASH","recid",4,"","KEEP-HASH","Product-attribute catalog; no IDB consumer."),
]

def evid(tbl, col):
    if not col or col not in ev.get(tbl,{}):
        return ""
    r = ev[tbl][col]
    return f"{col}: tot={r['total']} param={r['param']} join={r['join']} range={r['range']} files={r['n_files']}"

with open(os.path.join(HERE,"_partition_redesign_recommendations.csv"),"w",newline="") as f:
    w = csv.writer(f)
    w.writerow(["table","family","old_partition_key","new_strategy","new_partition_key",
                "hash_modulus","verdict","n_files_ref","access_evidence","note"])
    for row in R:
        tbl,fam,oldk,strat,newk,mod,ecol,verdict,note = row
        w.writerow([tbl,fam,oldk,strat,newk, mod if mod else "",
                    verdict, nfiles.get(tbl,"?"), evid(tbl,ecol), note])

print(f"wrote _partition_redesign_recommendations.csv ({len(R)} tables)")
# quick stats
from collections import Counter
c = Counter(r[7] for r in R)
print("verdicts:", dict(c))
