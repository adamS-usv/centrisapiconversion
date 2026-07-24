SET NOCOUNT ON; SET ANSI_WARNINGS OFF;

-- Inventory: try datephysical / datefinancial
SELECT 'inventtrans' t, 'datephysical' c, CAST(MIN(datephysical) AS DATE) min_d, CAST(MAX(datephysical) AS DATE) max_d, SUM(CASE WHEN datephysical IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.inventtrans TABLESAMPLE (500000 ROWS) WITH (NOLOCK);
SELECT 'inventtrans' t, 'datefinancial' c, CAST(MIN(datefinancial) AS DATE) min_d, CAST(MAX(datefinancial) AS DATE) max_d, SUM(CASE WHEN datefinancial IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.inventtrans TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

-- Sales tables: try deliverydate / receiptdaterequested
SELECT 'salestable' t, 'deliverydate' c, CAST(MIN(deliverydate) AS DATE) min_d, CAST(MAX(deliverydate) AS DATE) max_d, SUM(CASE WHEN deliverydate IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.salestable TABLESAMPLE (500000 ROWS) WITH (NOLOCK);
SELECT 'salesline' t, 'receiptdaterequested' c, CAST(MIN(receiptdaterequested) AS DATE) min_d, CAST(MAX(receiptdaterequested) AS DATE) max_d, SUM(CASE WHEN receiptdaterequested IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.salesline TABLESAMPLE (500000 ROWS) WITH (NOLOCK);
SELECT 'salesline' t, 'shippingdaterequested' c, CAST(MIN(shippingdaterequested) AS DATE) min_d, CAST(MAX(shippingdaterequested) AS DATE) max_d, SUM(CASE WHEN shippingdaterequested IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.salesline TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

-- Purchase: try deliverydate
SELECT 'purchline' t, 'deliverydate' c, CAST(MIN(deliverydate) AS DATE) min_d, CAST(MAX(deliverydate) AS DATE) max_d, SUM(CASE WHEN deliverydate IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.purchline TABLESAMPLE (500000 ROWS) WITH (NOLOCK);
SELECT 'purchlinehistory' t, 'deliverydate' c, CAST(MIN(deliverydate) AS DATE) min_d, CAST(MAX(deliverydate) AS DATE) max_d, SUM(CASE WHEN deliverydate IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.purchlinehistory TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

-- Fallback to _fivetran_synced for tables with no real business date
SELECT 'inventtrans' t, '_fivetran_synced' c, CAST(MIN(_fivetran_synced) AS DATE) min_d, CAST(MAX(_fivetran_synced) AS DATE) max_d, SUM(CASE WHEN _fivetran_synced IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.inventtrans TABLESAMPLE (500000 ROWS) WITH (NOLOCK);
SELECT 'inventtransorigin' t, '_fivetran_synced' c, CAST(MIN(_fivetran_synced) AS DATE) min_d, CAST(MAX(_fivetran_synced) AS DATE) max_d, SUM(CASE WHEN _fivetran_synced IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.inventtransorigin TABLESAMPLE (500000 ROWS) WITH (NOLOCK);
SELECT 'ledgerentryjournal' t, '_fivetran_synced' c, CAST(MIN(_fivetran_synced) AS DATE) min_d, CAST(MAX(_fivetran_synced) AS DATE) max_d, SUM(CASE WHEN _fivetran_synced IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.ledgerentryjournal TABLESAMPLE (500000 ROWS) WITH (NOLOCK);
SELECT 'reqitemtable' t, '_fivetran_synced' c, CAST(MIN(_fivetran_synced) AS DATE) min_d, CAST(MAX(_fivetran_synced) AS DATE) max_d, SUM(CASE WHEN _fivetran_synced IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.reqitemtable TABLESAMPLE (500000 ROWS) WITH (NOLOCK);
SELECT 'vendinvoiceinfoline' t, '_fivetran_synced' c, CAST(MIN(_fivetran_synced) AS DATE) min_d, CAST(MAX(_fivetran_synced) AS DATE) max_d, SUM(CASE WHEN _fivetran_synced IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.vendinvoiceinfoline TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

-- inventtransorigin/inventtransoriginsalesline have a CreatedDateTime field but it's 1900 -- check sink_created_on
SELECT 'inventtransorigin' t, 'sink_created_on' c, CAST(MIN(sink_created_on) AS DATE) min_d, CAST(MAX(sink_created_on) AS DATE) max_d, SUM(CASE WHEN sink_created_on IS NULL THEN 1 ELSE 0 END) nulls, COUNT_BIG(*) rows_scanned FROM d365.inventtransorigin TABLESAMPLE (500000 ROWS) WITH (NOLOCK);
