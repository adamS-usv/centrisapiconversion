# Render per-phase markdown files from _recommendations.csv
$recs = Import-Csv 'C:\git\integration-idb\apiconversion\partitioning\_recommendations.csv'

$phaseInfo = @{
    0 = @{ title='Phase 0 - Foundation';        slug='phase-0-foundation';        scope='Party/org backbone, financial dimensions, HCM, currency, system reference. Mostly slow-changing reference data.' }
    2 = @{ title='Phase 2 - Masters';            slug='phase-2-masters';            scope='Customer, Vendor, Warehouse, Product. Mix of master data and high-volume warehouse work tables.' }
    3 = @{ title='Phase 3 - Dependent reads';   slug='phase-3-dependent-reads';    scope='Program, Delivery, PurchaseOrder, Invoice, TransferOrder. Heaviest concentration of date-range query workloads.' }
    4 = @{ title='Phase 4 - Composite + Finance'; slug='phase-4-composite-finance'; scope='OrderStatus (Sales) and Finance (GL, FX, Bank, Esker AR). Largest individual tables in the project.' }
}

foreach ($phase in @(0,2,3,4)) {
    $info = $phaseInfo[$phase]
    $rows = $recs | Where-Object { [int]$_.phase -eq $phase }
    # LIST+RANGE = composite LIST(dataareaid) → RANGE(date). Legacy aliases RANGE / RANGE+LIST kept for old CSVs.
    $partitioned = $rows | Where-Object { $_.partition_type -in 'LIST+RANGE','RANGE','HASH','RANGE+LIST' }
    $noPart      = $rows | Where-Object { $_.partition_type -eq 'NONE' }
    $tbd         = $rows | Where-Object { $_.partition_type -eq 'TBD' }
    $listRangeN  = @($partitioned | Where-Object { $_.partition_type -in 'LIST+RANGE','RANGE+LIST','RANGE' }).Count
    $hashN       = @($partitioned | Where-Object { $_.partition_type -eq 'HASH' }).Count

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# $($info.title) - Partition Recommendations")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("**Scope:** $($info.scope)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("**Source:** profiled from ``d365.*`` schema on Azure SQL ``d365a1prdsynlinkusvprod2sql01.database.windows.net / primal`` on 2026-06-04. Row counts from ``sys.dm_db_partition_stats``; date column min/max from TABLESAMPLE. Partition *type* synced to composite DDL 2026-08-10.")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("**Summary:**")
    [void]$sb.AppendLine("- Tables in scope: $($rows.Count)")
    [void]$sb.AppendLine("- Partitioning recommended: $($partitioned.Count) ($listRangeN LIST+RANGE, $hashN HASH)")
    [void]$sb.AppendLine("- No partitioning needed: $($noPart.Count)")
    if ($tbd.Count -gt 0) {
        [void]$sb.AppendLine("- Flagged for review: $($tbd.Count)")
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("> **Composite rule (2026-07-24):** Every date-partitioned table is **``LIST(dataareaid) → RANGE(<date>)``** — legal entity first, date second — matching ``create-partitions.sql`` / ``MASTER_PARTITION_LIST.md``. HASH tables (no usable date) stay ``HASH(recid)``.")
    [void]$sb.AppendLine()

    # Section 1: tables that get partitioning
    [void]$sb.AppendLine("## Tables to partition")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Sorted by size (largest first).")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| Table | Rows | Size (MB) | Partition column | Type | Interval | DataAreaIds | Rationale |")
    [void]$sb.AppendLine("|---|---:|---:|---|---|---|---:|---|")
    foreach ($r in ($partitioned | Sort-Object { [decimal]$_.size_mb } -Descending)) {
        $col = $r.partition_column
        if ($col -eq '_HASH_RECID') { $col = 'RecId' }
        $dai = if ($r.dataareaid_distinct) { $r.dataareaid_distinct } else { '-' }
        $rationale = $r.rationale -replace '\|','/'
        [void]$sb.AppendLine("| ``d365.$($r.table)`` | $([long]$r.row_count) | $([decimal]$r.size_mb) | ``$col`` | $($r.partition_type) | $($r.interval) | $dai | $rationale |")
    }
    [void]$sb.AppendLine()

    if ($tbd.Count -gt 0) {
        [void]$sb.AppendLine("## Flagged for review")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| Table | Rows | Size (MB) | Note |")
        [void]$sb.AppendLine("|---|---:|---:|---|")
        foreach ($r in ($tbd | Sort-Object { [decimal]$_.size_mb } -Descending)) {
            [void]$sb.AppendLine("| ``d365.$($r.table)`` | $([long]$r.row_count) | $([decimal]$r.size_mb) | $($r.rationale) |")
        }
        [void]$sb.AppendLine()
    }

    # Section 2: no partitioning needed (collapsed)
    [void]$sb.AppendLine("## No partitioning needed ($($noPart.Count) tables)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("These tables are small enough (under 10M rows AND under 5 GB) or zero-row that PostgreSQL/AlloyDB single-table storage with a B-tree index on ``DataAreaId`` + business key is sufficient. Listed by descending row count for sanity check.")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("<details><summary>Show full list</summary>")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("| Table | Rows | Size (MB) |")
    [void]$sb.AppendLine("|---|---:|---:|")
    foreach ($r in ($noPart | Sort-Object { [long]$_.row_count } -Descending)) {
        [void]$sb.AppendLine("| ``d365.$($r.table)`` | $([long]$r.row_count) | $([decimal]$r.size_mb) |")
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("</details>")

    $out = "C:\git\integration-idb\apiconversion\partitioning\$($info.slug).md"
    [System.IO.File]::WriteAllText($out, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote $out"
}
