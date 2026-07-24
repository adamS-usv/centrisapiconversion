SET NOCOUNT ON; SET ANSI_WARNINGS OFF;

SELECT
    'sysuserlog' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[sysuserlog]  WITH (NOLOCK);

SELECT
    'usvexclusionprogramcustomerproducts' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvexclusionprogramcustomerproducts] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'ecoresattributevalue' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecoresattributevalue] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'ecoresinstancevalue' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecoresinstancevalue] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'usvecoresprodpartsattributes' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodpartsattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodtiresattributes' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtiresattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodlubeschemicalattributes' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodlubeschemicalattributes]  WITH (NOLOCK);

SELECT
    'whsworklinecyclecount' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsworklinecyclecount]  WITH (NOLOCK);

SELECT
    'usvecoresprodtiresaccessoriesattributes' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtiresaccessoriesattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodmicsitemsattributes' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodmicsitemsattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodexhuastattributes' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodexhuastattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodtubesattributes' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtubesattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodtiresattributesext' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtiresattributesext]  WITH (NOLOCK);

SELECT
    'inventtrans' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtrans] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'inventtransorigin' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransorigin] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'inventtransoriginsalesline' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransoriginsalesline] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'reqitemtable' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[reqitemtable] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'purchlinehistory' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[purchlinehistory] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'purchline' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[purchline] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'inventtransferline' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransferline]  WITH (NOLOCK);

SELECT
    'usvsspprogramcustomer' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvsspprogramcustomer]  WITH (NOLOCK);

SELECT
    'usvsspprogramproducts' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvsspprogramproducts]  WITH (NOLOCK);

SELECT
    'inventtransfertable' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransfertable]  WITH (NOLOCK);

SELECT
    'vendinvoiceinfoline' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendinvoiceinfoline]  WITH (NOLOCK);

SELECT
    'salestable' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[salestable] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'subledgerjournalaccountentrydistribution' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[subledgerjournalaccountentrydistribution] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'ledgerjournaltable' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ledgerjournaltable] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'ledgerentryjournal' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ledgerentryjournal]  WITH (NOLOCK);
