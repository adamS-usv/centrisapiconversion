param(
    [string]$ProfileOut   = 'C:\git\integration-idb\apiconversion\partitioning\_profile_out.txt',
    [string]$PickCsv      = 'C:\git\integration-idb\apiconversion\partitioning\_profile_picks.csv',
    [string]$OutputSql    = 'C:\git\integration-idb\apiconversion\partitioning\_fallback_run.sql'
)

# Parse profile output: lines like "table|col|min_date|max_date|nulls|scan_rows"
# Find tables where max_date = 1900-01-01 (date col entirely unreliable)
$bogus = New-Object System.Collections.Generic.HashSet[string]
Get-Content $ProfileOut | ForEach-Object {
    $p = $_ -split '\|'
    if ($p.Count -eq 6 -and $p[3] -eq '1900-01-01') {
        $bogus.Add($p[0]) | Out-Null
    }
}

Write-Host "Tables needing fallback profile: $($bogus.Count)"

$picks = Import-Csv $PickCsv
$sqlParts = @("SET NOCOUNT ON; SET ANSI_WARNINGS OFF;")
foreach ($t in $bogus) {
    $pick = $picks | Where-Object { $_.table -eq $t } | Select-Object -First 1
    if (-not $pick) { continue }
    $rowCount = [long]$pick.row_count
    if ($rowCount -gt 50000000)      { $samp = "TABLESAMPLE (500000 ROWS)" }
    elseif ($rowCount -gt 20000000)  { $samp = "TABLESAMPLE (1000000 ROWS)" }
    else                              { $samp = "" }

    $sqlParts += @"
SELECT
    '$t' AS table_name,
    'createddatetime' AS date_col,
    CAST(MIN([createddatetime]) AS DATE) AS min_date,
    CAST(MAX([createddatetime]) AS DATE) AS max_date,
    SUM(CASE WHEN [createddatetime] IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT_BIG(*) AS scan_rows
FROM d365.[$t] $samp WITH (NOLOCK);
"@
}
$sqlParts -join "`n`n" | Set-Content -Path $OutputSql -Encoding ASCII
Write-Host "Wrote $OutputSql"
