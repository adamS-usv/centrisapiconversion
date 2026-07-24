SET NOCOUNT ON;

SET ANSI_WARNINGS OFF;

SELECT
    'sysuserlog' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[sysuserlog]  WITH (NOLOCK);

SELECT
    'sysuserlog' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[sysuserlog]  WITH (NOLOCK);

SELECT
    'whsworkline' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsworkline] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'whsworkline' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsworkline] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'inventdim' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventdim] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'inventdim' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventdim] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'whsworktable' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsworktable] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'whsworktable' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsworktable] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'usvexclusionprogramcustomerproducts' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvexclusionprogramcustomerproducts] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'usvexclusionprogramcustomerproducts' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvexclusionprogramcustomerproducts] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'ecoresvalue' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecoresvalue] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'ecoresvalue' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecoresvalue] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'ecoresattributevalue' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecoresattributevalue] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'ecoresattributevalue' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecoresattributevalue] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'ecorestextvalue' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecorestextvalue] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'ecorestextvalue' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecorestextvalue] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'whsshipmenttable' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsshipmenttable] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'whsshipmenttable' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsshipmenttable] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'ecoresinstancevalue' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecoresinstancevalue] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'ecoresinstancevalue' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ecoresinstancevalue] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'whsloadtable' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsloadtable] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'whsloadtable' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsloadtable] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'whsloadline' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsloadline] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'whsloadline' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsloadline] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'usvecoresprodpartsattributes' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodpartsattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodpartsattributes' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodpartsattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodtiresattributes' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtiresattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodtiresattributes' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtiresattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodlubeschemicalattributes' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodlubeschemicalattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodlubeschemicalattributes' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodlubeschemicalattributes]  WITH (NOLOCK);

SELECT
    'whsworklinecyclecount' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsworklinecyclecount]  WITH (NOLOCK);

SELECT
    'whsworklinecyclecount' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whsworklinecyclecount]  WITH (NOLOCK);

SELECT
    'usvecoresprodtiresaccessoriesattributes' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtiresaccessoriesattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodtiresaccessoriesattributes' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtiresaccessoriesattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodmicsitemsattributes' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodmicsitemsattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodmicsitemsattributes' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodmicsitemsattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodexhuastattributes' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodexhuastattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodexhuastattributes' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodexhuastattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodtubesattributes' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtubesattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodtubesattributes' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtubesattributes]  WITH (NOLOCK);

SELECT
    'usvecoresprodtiresattributesext' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtiresattributesext]  WITH (NOLOCK);

SELECT
    'usvecoresprodtiresattributesext' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvecoresprodtiresattributesext]  WITH (NOLOCK);

SELECT
    'inventtrans' AS table_name,
    'shippingdateconfirmed' AS date_col,
    CAST(MIN([shippingdateconfirmed]) AS DATE) AS min_date,
    CAST(MAX([shippingdateconfirmed]) AS DATE) AS max_date,
    SUM(CASE WHEN [shippingdateconfirmed] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtrans] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'inventtrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtrans] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'inventsum' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventsum] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'inventsum' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventsum] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'inventtransorigin' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransorigin] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'inventtransorigin' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransorigin] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'vendsettlement' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendsettlement] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'vendsettlement' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendsettlement] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'vendtrans' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendtrans] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'vendtrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendtrans] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'custtrans' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custtrans] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'custtrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custtrans] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'taxtrans' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[taxtrans] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'taxtrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[taxtrans] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'custinvoicetrans' AS table_name,
    'invoicedate' AS date_col,
    CAST(MIN([invoicedate]) AS DATE) AS min_date,
    CAST(MAX([invoicedate]) AS DATE) AS max_date,
    SUM(CASE WHEN [invoicedate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custinvoicetrans] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'custinvoicetrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custinvoicetrans] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'custinvoicejour' AS table_name,
    'invoicedate' AS date_col,
    CAST(MIN([invoicedate]) AS DATE) AS min_date,
    CAST(MAX([invoicedate]) AS DATE) AS max_date,
    SUM(CASE WHEN [invoicedate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custinvoicejour] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'custinvoicejour' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custinvoicejour] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'custsettlement' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custsettlement] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'custsettlement' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custsettlement] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'custconfirmjour' AS table_name,
    'confirmdate' AS date_col,
    CAST(MIN([confirmdate]) AS DATE) AS min_date,
    CAST(MAX([confirmdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [confirmdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custconfirmjour] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'custconfirmjour' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custconfirmjour] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'taxjournaltrans' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[taxjournaltrans] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'taxjournaltrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[taxjournaltrans] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'vendinvoicejour' AS table_name,
    'invoicedate' AS date_col,
    CAST(MIN([invoicedate]) AS DATE) AS min_date,
    CAST(MAX([invoicedate]) AS DATE) AS max_date,
    SUM(CASE WHEN [invoicedate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendinvoicejour] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'vendinvoicejour' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendinvoicejour] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'inventtransoriginsalesline' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransoriginsalesline] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'inventtransoriginsalesline' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransoriginsalesline] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'custinvoicesaleslink' AS table_name,
    'invoicedate' AS date_col,
    CAST(MIN([invoicedate]) AS DATE) AS min_date,
    CAST(MAX([invoicedate]) AS DATE) AS max_date,
    SUM(CASE WHEN [invoicedate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custinvoicesaleslink] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'custinvoicesaleslink' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custinvoicesaleslink] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'markuptrans' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[markuptrans] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'markuptrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[markuptrans] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'reqitemtable' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[reqitemtable] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'reqitemtable' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[reqitemtable] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'purchlinehistory' AS table_name,
    'shippingdateconfirmed' AS date_col,
    CAST(MIN([shippingdateconfirmed]) AS DATE) AS min_date,
    CAST(MAX([shippingdateconfirmed]) AS DATE) AS max_date,
    SUM(CASE WHEN [shippingdateconfirmed] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[purchlinehistory] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'purchlinehistory' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[purchlinehistory] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'purchline' AS table_name,
    'shippingdateconfirmed' AS date_col,
    CAST(MIN([shippingdateconfirmed]) AS DATE) AS min_date,
    CAST(MAX([shippingdateconfirmed]) AS DATE) AS max_date,
    SUM(CASE WHEN [shippingdateconfirmed] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[purchline] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'purchline' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[purchline] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'vendpackingsliptrans' AS table_name,
    'accountingdate' AS date_col,
    CAST(MIN([accountingdate]) AS DATE) AS min_date,
    CAST(MAX([accountingdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [accountingdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendpackingsliptrans]  WITH (NOLOCK);

SELECT
    'vendpackingsliptrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendpackingsliptrans]  WITH (NOLOCK);

SELECT
    'vendinvoicetrans' AS table_name,
    'invoicedate' AS date_col,
    CAST(MIN([invoicedate]) AS DATE) AS min_date,
    CAST(MAX([invoicedate]) AS DATE) AS max_date,
    SUM(CASE WHEN [invoicedate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendinvoicetrans]  WITH (NOLOCK);

SELECT
    'vendinvoicetrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendinvoicetrans]  WITH (NOLOCK);

SELECT
    'inventtransferline' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransferline]  WITH (NOLOCK);

SELECT
    'inventtransferline' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransferline]  WITH (NOLOCK);

SELECT
    'usvsspprogramcustomer' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvsspprogramcustomer]  WITH (NOLOCK);

SELECT
    'usvsspprogramcustomer' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvsspprogramcustomer]  WITH (NOLOCK);

SELECT
    'usvsspprogramproducts' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvsspprogramproducts]  WITH (NOLOCK);

SELECT
    'usvsspprogramproducts' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvsspprogramproducts]  WITH (NOLOCK);

SELECT
    'inventtransfertable' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransfertable]  WITH (NOLOCK);

SELECT
    'inventtransfertable' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventtransfertable]  WITH (NOLOCK);

SELECT
    'inventvaluereporttmpline' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventvaluereporttmpline]  WITH (NOLOCK);

SELECT
    'inventvaluereporttmpline' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventvaluereporttmpline]  WITH (NOLOCK);

SELECT
    'custinteresttrans' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custinteresttrans]  WITH (NOLOCK);

SELECT
    'custinteresttrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[custinteresttrans]  WITH (NOLOCK);

SELECT
    'inventjournaltrans' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventjournaltrans]  WITH (NOLOCK);

SELECT
    'inventjournaltrans' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[inventjournaltrans]  WITH (NOLOCK);

SELECT
    'vendinvoiceinfoline' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendinvoiceinfoline]  WITH (NOLOCK);

SELECT
    'vendinvoiceinfoline' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[vendinvoiceinfoline]  WITH (NOLOCK);

SELECT
    'generaljournalaccountentry' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[generaljournalaccountentry] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'generaljournalaccountentry' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[generaljournalaccountentry] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'generaljournalentry' AS table_name,
    'accountingdate' AS date_col,
    CAST(MIN([accountingdate]) AS DATE) AS min_date,
    CAST(MAX([accountingdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [accountingdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[generaljournalentry] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'generaljournalentry' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[generaljournalentry] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'salesline' AS table_name,
    'shippingdateconfirmed' AS date_col,
    CAST(MIN([shippingdateconfirmed]) AS DATE) AS min_date,
    CAST(MAX([shippingdateconfirmed]) AS DATE) AS max_date,
    SUM(CASE WHEN [shippingdateconfirmed] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[salesline] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'salesline' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[salesline] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'salestable' AS table_name,
    'shippingdateconfirmed' AS date_col,
    CAST(MIN([shippingdateconfirmed]) AS DATE) AS min_date,
    CAST(MAX([shippingdateconfirmed]) AS DATE) AS max_date,
    SUM(CASE WHEN [shippingdateconfirmed] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[salestable] TABLESAMPLE (500000 ROWS) WITH (NOLOCK);

SELECT
    'salestable' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[salestable] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'usvsalescommissionresptable' AS table_name,
    'invoicedate' AS date_col,
    CAST(MIN([invoicedate]) AS DATE) AS min_date,
    CAST(MAX([invoicedate]) AS DATE) AS max_date,
    SUM(CASE WHEN [invoicedate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvsalescommissionresptable] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'usvsalescommissionresptable' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvsalescommissionresptable] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'subledgerjournalaccountentrydistribution' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[subledgerjournalaccountentrydistribution] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'subledgerjournalaccountentrydistribution' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[subledgerjournalaccountentrydistribution] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'ledgertransvoucherlink' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ledgertransvoucherlink] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'ledgertransvoucherlink' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ledgertransvoucherlink] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'whssalesline' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whssalesline] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'whssalesline' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[whssalesline] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'usvcuststatement' AS table_name,
    'transdate' AS date_col,
    CAST(MIN([transdate]) AS DATE) AS min_date,
    CAST(MAX([transdate]) AS DATE) AS max_date,
    SUM(CASE WHEN [transdate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvcuststatement] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'usvcuststatement' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvcuststatement] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'tmssalestable' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[tmssalestable] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'tmssalestable' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[tmssalestable] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'ledgerjournaltable' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ledgerjournaltable] TABLESAMPLE (1000000 ROWS) WITH (NOLOCK);

SELECT
    'ledgerjournaltable' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ledgerjournaltable] TABLESAMPLE (100000 ROWS) WITH (NOLOCK);

SELECT
    'usvcustinvoicejourstatement' AS table_name,
    'invoicedate' AS date_col,
    CAST(MIN([invoicedate]) AS DATE) AS min_date,
    CAST(MAX([invoicedate]) AS DATE) AS max_date,
    SUM(CASE WHEN [invoicedate] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvcustinvoicejourstatement]  WITH (NOLOCK);

SELECT
    'usvcustinvoicejourstatement' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[usvcustinvoicejourstatement]  WITH (NOLOCK);

SELECT
    'ledgerentryjournal' AS table_name,
    'modifieddatetime' AS date_col,
    CAST(MIN([modifieddatetime]) AS DATE) AS min_date,
    CAST(MAX([modifieddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [modifieddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ledgerentryjournal]  WITH (NOLOCK);

SELECT
    'ledgerentryjournal' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[ledgerentryjournal]  WITH (NOLOCK);
