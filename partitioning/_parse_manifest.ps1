param(
    [string]$ManifestPath = 'C:\git\integration-idb\apiconversion\BASE_TABLES_BY_PHASE.md',
    [string]$InventoryPath = 'C:\git\integration-idb\apiconversion\partitioning\_d365_inventory.txt',
    [string]$OutputCsv = 'C:\git\integration-idb\apiconversion\partitioning\_phase_inventory.csv'
)

# Load inventory: pipe-separated table_name|row_count|size_mb
$inventory = @{}
Get-Content $InventoryPath | ForEach-Object {
    $parts = $_ -split '\|'
    if ($parts.Count -eq 3) {
        $name = $parts[0].Trim().ToLower()
        $inventory[$name] = [PSCustomObject]@{
            row_count = [long]$parts[1].Trim()
            size_mb   = [decimal]$parts[2].Trim()
        }
    }
}
Write-Host "Loaded $($inventory.Count) tables from d365 inventory"

# Parse manifest: extract backticked tokens grouped by `## Phase N` headers
$content = Get-Content $ManifestPath -Raw
$phaseRegex = [regex]'(?ms)^## Phase (\d+)[^\n]*\n(.*?)(?=^## Phase \d+|\z)'
$tickRegex  = [regex]'`([A-Za-z_][A-Za-z0-9_]*)`'

$phaseTables = @{}
foreach ($m in $phaseRegex.Matches($content)) {
    $phaseNum = [int]$m.Groups[1].Value
    $body = $m.Groups[2].Value
    $tables = @()
    foreach ($t in $tickRegex.Matches($body)) {
        $name = $t.Groups[1].Value.ToLower()
        if ($name -notin @('from','where','select')) { $tables += $name }
    }
    $phaseTables[$phaseNum] = $tables | Sort-Object -Unique
    Write-Host "Phase $phaseNum`: $($phaseTables[$phaseNum].Count) tables in manifest"
}

# Build per-phase rows and capture missing
$rows = @()
$missing = @{}
foreach ($phase in @(0,2,3,4)) {
    $missing[$phase] = @()
    foreach ($t in $phaseTables[$phase]) {
        if ($inventory.ContainsKey($t)) {
            $rows += [PSCustomObject]@{
                phase     = $phase
                table     = $t
                row_count = $inventory[$t].row_count
                size_mb   = $inventory[$t].size_mb
                landed    = $true
            }
        } else {
            $missing[$phase] += $t
            $rows += [PSCustomObject]@{
                phase     = $phase
                table     = $t
                row_count = 0
                size_mb   = 0
                landed    = $false
            }
        }
    }
}

$rows | Sort-Object phase, @{Expression='row_count'; Descending=$true} | Export-Csv -Path $OutputCsv -NoTypeInformation
Write-Host "`nWrote $OutputCsv ($($rows.Count) rows)"

Write-Host "`n=== MISSING TABLES (manifest entries not in d365 schema) ==="
foreach ($phase in @(0,2,3,4)) {
    if ($missing[$phase].Count -gt 0) {
        Write-Host "Phase $phase ($($missing[$phase].Count) missing):"
        $missing[$phase] | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "Phase $phase`: all tables landed"
    }
}

Write-Host "`n=== TOP 20 BY SIZE (Phases 0,2,3,4 combined) ==="
$rows | Where-Object { $_.landed } | Sort-Object size_mb -Descending | Select-Object -First 20 phase, table, row_count, size_mb | Format-Table -AutoSize
