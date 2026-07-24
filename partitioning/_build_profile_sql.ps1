param(
    [int]$RowThreshold = 5000000,
    [string]$InventoryCsv = 'C:\git\integration-idb\apiconversion\partitioning\_phase_inventory.csv',
    [string]$DateColsFile = 'C:\git\integration-idb\apiconversion\partitioning\_d365_date_columns.txt',
    [string]$OutputSql    = 'C:\git\integration-idb\apiconversion\partitioning\_profile_run.sql'
)

# Priority of business-date columns (case-insensitive). First match wins.
$priority = @(
    'invoicedate', 'transdate', 'accountingdate', 'postingdate',
    'shippingdateconfirmed', 'deliverydate', 'orderdate', 'confirmdate',
    'datephysical', 'datefinancial', 'documentdate',
    'modifieddatetime', 'createddatetime'
)

# Load date columns
$cols = @{}
Get-Content $DateColsFile | ForEach-Object {
    $p = $_ -split '\|'
    if ($p.Count -eq 3) {
        $tbl = $p[0].Trim().ToLower()
        $col = $p[1].Trim().ToLower()
        if (-not $cols.ContainsKey($tbl)) { $cols[$tbl] = @() }
        $cols[$tbl] += $col
    }
}

$large = Import-Csv $InventoryCsv | Where-Object {
    [long]$_.row_count -ge $RowThreshold -and $_.landed -eq 'True'
}

$sqlParts = @()
$sqlParts += "SET NOCOUNT ON;"
$sqlParts += "SET ANSI_WARNINGS OFF;"

$pickMap = @()
foreach ($row in $large) {
    $t = $row.table.ToLower()
    if (-not $cols.ContainsKey($t)) { continue }
    $tableCols = $cols[$t]
    $picked = $null
    foreach ($p in $priority) {
        if ($tableCols -contains $p) { $picked = $p; break }
    }
    if (-not $picked) { continue }
    $rowCount = [long]$row.row_count
    $pickMap += [PSCustomObject]@{ phase = $row.phase; table = $t; date_col = $picked; row_count = $rowCount; size_mb = $row.size_mb }

    # Sample size: large tables get TABLESAMPLE for MIN/MAX/null-count estimation
    # DataAreaId distinct count is run separately with a smaller sample
    if ($rowCount -gt 50000000) {
        # >50M rows — sample 500k rows for date stats
        $sampleClause = "TABLESAMPLE (500000 ROWS)"
        $dataAreaSample = "TABLESAMPLE (100000 ROWS)"
    } elseif ($rowCount -gt 20000000) {
        # 20-50M — sample 1M rows
        $sampleClause = "TABLESAMPLE (1000000 ROWS)"
        $dataAreaSample = "TABLESAMPLE (100000 ROWS)"
    } else {
        # <=20M — full scan is acceptable
        $sampleClause = ""
        $dataAreaSample = ""
    }

    $sqlParts += @"
SELECT
    '$t' AS table_name,
    '$picked' AS date_col,
    CAST(MIN([$picked]) AS DATE) AS min_date,
    CAST(MAX([$picked]) AS DATE) AS max_date,
    SUM(CASE WHEN [$picked] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[$t] $sampleClause WITH (NOLOCK);

SELECT
    '$t' AS table_name,
    'dataareaid' AS col,
    COUNT(DISTINCT [dataareaid]) AS distinct_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[$t] $dataAreaSample WITH (NOLOCK);
"@
}

$sqlParts -join "`n`n" | Set-Content -Path $OutputSql -Encoding ASCII
Write-Host "Built profile SQL for $($pickMap.Count) tables -> $OutputSql"
$pickMap | Export-Csv -Path 'C:\git\integration-idb\apiconversion\partitioning\_profile_picks.csv' -NoTypeInformation
