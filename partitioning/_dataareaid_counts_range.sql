-- Per-table dataareaid distribution for the 32 single-level RANGE tables
-- (Sections 2 & 3 of create-partitions.sql). Used to decide which entities get a
-- dedicated LIST(dataareaid) sub-partition (>=100k rows) when converting these to
-- composite LIST(dataareaid) -> RANGE(date). Read-only, WITH (NOLOCK), exact counts.
SET NOCOUNT ON;

SELECT 'generaljournalaccountentry' AS table_name, dataareaid, COUNT_BIG(*) AS rows FROM d365.generaljournalaccountentry WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'inventtrans',        dataareaid, COUNT_BIG(*) FROM d365.inventtrans        WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'whsworkline',        dataareaid, COUNT_BIG(*) FROM d365.whsworkline        WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'whsworktable',       dataareaid, COUNT_BIG(*) FROM d365.whsworktable       WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'whsshipmenttable',   dataareaid, COUNT_BIG(*) FROM d365.whsshipmenttable   WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'whsloadtable',       dataareaid, COUNT_BIG(*) FROM d365.whsloadtable       WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'whsloadline',        dataareaid, COUNT_BIG(*) FROM d365.whsloadline        WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'usvsalescommissionresptable', dataareaid, COUNT_BIG(*) FROM d365.usvsalescommissionresptable WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'subledgerjournalaccountentrydistribution', dataareaid, COUNT_BIG(*) FROM d365.subledgerjournalaccountentrydistribution WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'whssalesline',       dataareaid, COUNT_BIG(*) FROM d365.whssalesline       WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'usvcuststatement',   dataareaid, COUNT_BIG(*) FROM d365.usvcuststatement   WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'tmssalestable',      dataareaid, COUNT_BIG(*) FROM d365.tmssalestable      WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'usvcustinvoicejourstatement', dataareaid, COUNT_BIG(*) FROM d365.usvcustinvoicejourstatement WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'custconfirmjour',    dataareaid, COUNT_BIG(*) FROM d365.custconfirmjour    WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'sysuserlog',         dataareaid, COUNT_BIG(*) FROM d365.sysuserlog         WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'inventdim',          dataareaid, COUNT_BIG(*) FROM d365.inventdim          WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'ecoresvalue',        dataareaid, COUNT_BIG(*) FROM d365.ecoresvalue        WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'ecorestextvalue',    dataareaid, COUNT_BIG(*) FROM d365.ecorestextvalue    WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'taxtrans',           dataareaid, COUNT_BIG(*) FROM d365.taxtrans           WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'custsettlement',     dataareaid, COUNT_BIG(*) FROM d365.custsettlement     WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'taxjournaltrans',    dataareaid, COUNT_BIG(*) FROM d365.taxjournaltrans    WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'custinvoicesaleslink', dataareaid, COUNT_BIG(*) FROM d365.custinvoicesaleslink WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'markuptrans',        dataareaid, COUNT_BIG(*) FROM d365.markuptrans        WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'ledgerjournaltable', dataareaid, COUNT_BIG(*) FROM d365.ledgerjournaltable WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'purchlinehistory',   dataareaid, COUNT_BIG(*) FROM d365.purchlinehistory   WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'vendpackingsliptrans', dataareaid, COUNT_BIG(*) FROM d365.vendpackingsliptrans WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'vendinvoicetrans',   dataareaid, COUNT_BIG(*) FROM d365.vendinvoicetrans   WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'inventtransferline', dataareaid, COUNT_BIG(*) FROM d365.inventtransferline WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'inventtransfertable', dataareaid, COUNT_BIG(*) FROM d365.inventtransfertable WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'inventvaluereporttmpline', dataareaid, COUNT_BIG(*) FROM d365.inventvaluereporttmpline WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'custinteresttrans',  dataareaid, COUNT_BIG(*) FROM d365.custinteresttrans  WITH (NOLOCK) GROUP BY dataareaid
UNION ALL SELECT 'inventjournaltrans', dataareaid, COUNT_BIG(*) FROM d365.inventjournaltrans WITH (NOLOCK) GROUP BY dataareaid
ORDER BY table_name, rows DESC;
