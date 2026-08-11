# Consolidate inventory + profile data + manual fallbacks into a single recommendation CSV.
# Output: _recommendations.csv with columns: phase, table, row_count, size_mb, partition_column, partition_type, interval, rationale

$inventoryCsv = 'C:\git\integration-idb\apiconversion\partitioning\_phase_inventory.csv'
$profileOut   = 'C:\git\integration-idb\apiconversion\partitioning\_profile_out.txt'
$fallbackOut  = 'C:\git\integration-idb\apiconversion\partitioning\_fallback_out.txt'
$round2Out    = 'C:\git\integration-idb\apiconversion\partitioning\_round2_out.txt'

# Parse all profile files: lines like "table|col|min_date|max_date|nulls|scan_rows"
$dateStats = @{}
$dataareaStats = @{}
foreach ($f in @($profileOut, $fallbackOut, $round2Out)) {
    Get-Content $f | ForEach-Object {
        $p = $_ -split '\|'
        if ($p.Count -eq 6) {
            $tbl = $p[0]; $col = $p[1]
            $key = "$tbl|$col"
            $dateStats[$key] = @{
                table = $tbl; col = $col;
                min_date = $p[2]; max_date = $p[3]; nulls = $p[4]; scan_rows = $p[5]
            }
        }
        if ($p.Count -eq 4) {
            $tbl = $p[0]; $col = $p[1]
            if ($col -eq 'dataareaid') {
                $dataareaStats[$tbl] = [int]$p[2]
            }
        }
    }
}

# Load inventory
$inventory = Import-Csv $inventoryCsv

# Manual partition column choice per table - derived from profile data above.
# Tables not in this map fall through to default logic (size-based).
$manualPick = @{
    # Revised 2026-07-24 / synced 2026-08-10: every date table is LIST+RANGE
    # (LIST(dataareaid) → RANGE(date)). HASH tables unchanged.
    # Phase 0 - Foundation. Mostly reference. sysuserlog is the only big one.
    'sysuserlog' = @{ col='createddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='10M user log rows; createddatetime spans 2018-2026; composite LIST(dataareaid) → RANGE(date)' }

    # Phase 2 - Masters
    'whsworkline' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='528M rows / 445 GB; D365 WHS module live 2023-02 onward; high CDC churn; composite LIST(dataareaid) → RANGE(date)' }
    'inventdim' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='328M rows; dimension rows only updated since 2025-06 - short window, quarterly is enough; composite LIST(dataareaid) → RANGE(date)' }
    'whsworktable' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='239M rows / 136 GB; companion of whsworkline; same WHS-2023 timeline; composite LIST(dataareaid) → RANGE(date)' }
    'usvexclusionprogramcustomerproducts' = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='151M rows / 75 GB; both audit columns 1900-01-01; no business date - uniform spread by RecId' }
    'ecoresvalue' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='82M rows / 43 GB; attribute catalog churns post-2023, quarterly windows are fine; composite LIST(dataareaid) → RANGE(date)' }
    'ecoresattributevalue' = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='82M rows / 34 GB; audit columns all 1900-01-01; catalog with single DataAreaId - HASH by RecId' }
    'ecorestextvalue' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='78M rows / 29 GB; modifieddatetime 2023-02+ usable; composite LIST(dataareaid) → RANGE(date)' }
    'whsshipmenttable' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='65M rows / 43 GB; shipment header, WHS-2023+; composite LIST(dataareaid) → RANGE(date)' }
    'ecoresinstancevalue' = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='64M rows / 26 GB; both audit columns 1900-01-01; HASH by RecId' }
    'whsloadtable' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='55M rows / 47 GB; WHS-2023+; composite LIST(dataareaid) → RANGE(date)' }
    'whsloadline' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='45M rows / 58 GB; WHS-2023+; composite LIST(dataareaid) → RANGE(date)' }
    'usvecoresprodpartsattributes' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='17M rows; product attribute catalog, no usable dates; HASH by RecId' }
    'usvecoresprodtiresattributes' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='17M rows; same pattern' }
    'usvecoresprodlubeschemicalattributes' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='17M rows; same pattern' }
    'whsworklinecyclecount' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='10M rows; both audit cols 1900-01-01; HASH by RecId' }
    'usvecoresprodtiresaccessoriesattributes' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }
    'usvecoresprodmicsitemsattributes' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }
    'usvecoresprodexhuastattributes' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }
    'usvecoresprodtubesattributes' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }
    'usvecoresprodtiresattributesext' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }

    # Phase 3 - Dependent reads
    'inventtrans' = @{ col='datephysical'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='495M rows / 373 GB; datephysical 1900-2026 (default partition for migrated 1900 rows + monthly post-2019); composite LIST(dataareaid) → RANGE(date)' }
    'inventsum' = @{ col='_HASH_RECID'; type='HASH'; interval='16 partitions'; reason='399M rows / 329 GB; inventory snapshot, no business date; HASH for parallel reads' }
    'inventtransorigin' = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='238M rows / 132 GB; both audit columns 1900-01-01; _fivetran_synced only 6 weeks; HASH by RecId' }
    'vendsettlement' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='227M rows / 125 GB; transdate 2019-2026; 16 DataAreaIds - composite partition for legal-entity isolation' }
    'vendtrans' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='179M rows / 169 GB; transdate 2019-2026; 8 DataAreaIds' }
    'custtrans' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='134M rows / 126 GB; modifieddatetime 2019-02+ verified clean (0 x 1900 rows); 3 kept DataAreaIds (40,20,30); LIST(dataareaid) → RANGE(modifieddatetime) monthly' }
    'taxtrans' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='114M rows / 110 GB; transdate 2019-2026; 5 DataAreaIds; composite LIST(dataareaid) → RANGE(date)' }
    'custinvoicetrans' = @{ col='invoicedate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='103M rows / 138 GB; invoicedate 2019-2026; 5 DataAreaIds - invoice queries always filter both' }
    'custinvoicejour' = @{ col='invoicedate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='90M rows / 125 GB; invoicedate 2019-2026; 6 DataAreaIds; primary table for Invoice API' }
    'custsettlement' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='84M rows / 84 GB; transdate 2019-2026; 7 DataAreaIds; composite LIST(dataareaid) → RANGE(date)' }
    'custconfirmjour' = @{ col='confirmdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='57M rows / 26 GB; confirmdate 2023-2026 (D365 cutover); single DataAreaId; composite LIST(dataareaid) → RANGE(date)' }
    'taxjournaltrans' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='52M rows / 39 GB; transdate 2019-2026; 4 DataAreaIds; composite LIST(dataareaid) → RANGE(date)' }
    'vendinvoicejour' = @{ col='invoicedate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='51M rows / 62 GB; 17 DataAreaIds - heaviest multi-entity table' }
    'inventtransoriginsalesline' = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='36M rows; audit cols 1900-01-01; HASH by RecId' }
    'custinvoicesaleslink' = @{ col='invoicedate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='30M rows / 23 GB; invoicedate 2019-2026; 5 DataAreaIds; composite LIST(dataareaid) → RANGE(date)' }
    'markuptrans' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='26M rows / 28 GB; transdate mostly post-2019 (some 1900 migrated rows -> default partition); composite LIST(dataareaid) → RANGE(date)' }
    'reqitemtable' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='24M rows; audit cols 1900-01-01; no business date' }
    'purchlinehistory' = @{ col='deliverydate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='22M rows / 24 GB; deliverydate spans 1900-2029 (planned future + migrated past) - quarterly with default partition; composite LIST(dataareaid) → RANGE(date)' }
    'purchline' = @{ col='deliverydate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='20M rows / 34 GB; deliverydate 1900-2029; PO line queries filter delivery window' }
    'vendpackingsliptrans' = @{ col='accountingdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='18M rows / 16 GB; accountingdate 2023-2026; composite LIST(dataareaid) → RANGE(date)' }
    'vendinvoicetrans' = @{ col='invoicedate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='18M rows / 21 GB; invoicedate 2023-2026; 2 DataAreaIds; composite LIST(dataareaid) → RANGE(date)' }
    'inventtransferline' = @{ col='createddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='12M rows / 15 GB; createddatetime 2023-2026; composite LIST(dataareaid) → RANGE(date)' }
    'usvsspprogramcustomer' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='9M rows; both audit cols 1900-01-01' }
    'usvsspprogramproducts' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='9M rows; both audit cols 1900-01-01' }
    'inventtransfertable' = @{ col='createddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='8.9M rows / 6.8 GB; createddatetime 2023-2026; composite LIST(dataareaid) → RANGE(date)' }
    'inventvaluereporttmpline' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='8.7M rows; transdate 2023-2026; temp-line table - consider whether to partition at all (TBD with API team); composite LIST(dataareaid) → RANGE(date)' }
    'custinteresttrans' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='6.5M rows / 6.9 GB; transdate 2019-2026; 3 DataAreaIds; composite LIST(dataareaid) → RANGE(date)' }
    'inventjournaltrans' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='6.2M rows; transdate 2023-2026; composite LIST(dataareaid) → RANGE(date)' }
    'vendinvoiceinfoline' = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='5.5M rows; audit cols 1900-01-01' }

    # Phase 4 - Composite + Finance
    'generaljournalaccountentry' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='475M rows / 431 GB; modifieddatetime 2020-10 to 2026-06; biggest GL table; composite LIST(dataareaid) → RANGE(date)' }
    'generaljournalentry' = @{ col='accountingdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='153M rows / 109 GB; accountingdate 2016-2026 - 10-year span; finance API filters by date AND legal entity' }
    'salesline' = @{ col='shippingdaterequested'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='75M rows / 187 GB; shippingdaterequested 2019-2026 clean (use this over shippingdateconfirmed which has 1900-01-01 entries); 3 DataAreaIds' }
    'salestable' = @{ col='deliverydate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='59M rows / 110 GB; deliverydate 2019-2026; sales order header - partner of salesline' }
    'usvsalescommissionresptable' = @{ col='invoicedate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='48M rows / 28 GB; invoicedate 2023-2026; composite LIST(dataareaid) → RANGE(date)' }
    'subledgerjournalaccountentrydistribution' = @{ col='createddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='42M rows / 19 GB; createddatetime 2021-2026; composite LIST(dataareaid) → RANGE(date)' }
    'ledgertransvoucherlink' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='37M rows / 16 GB; transdate 2017-2026; 12 DataAreaIds' }
    'whssalesline' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='34M rows / 20 GB; modifieddatetime 2023-2026; composite LIST(dataareaid) → RANGE(date)' }
    'usvcuststatement' = @{ col='transdate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='31M rows / 19 GB; transdate 2023-2026; composite LIST(dataareaid) → RANGE(date)' }
    'tmssalestable' = @{ col='modifieddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='29M rows / 16 GB; modifieddatetime 2023-2026; composite LIST(dataareaid) → RANGE(date)' }
    'ledgerjournaltable' = @{ col='createddatetime'; type='LIST+RANGE'; interval='LIST(DataAreaId) + quarterly'; reason='27M rows / 24 GB; createddatetime mixed (some 1900) but spans to 2026; 9 DataAreaIds; composite LIST(dataareaid) → RANGE(date)' }
    'usvcustinvoicejourstatement' = @{ col='invoicedate'; type='LIST+RANGE'; interval='LIST(DataAreaId) + monthly'; reason='19M rows / 12 GB; invoicedate 2023-2026; composite LIST(dataareaid) → RANGE(date)' }
    'ledgerentryjournal' = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='14M rows; all audit columns 1900-01-01; HASH by RecId' }
}

$out = @()
foreach ($row in $inventory) {
    $t = $row.table
    $phase = $row.phase
    $rowCount = [long]$row.row_count
    $sizeMb = [decimal]$row.size_mb

    if ($manualPick.ContainsKey($t)) {
        $mp = $manualPick[$t]
        $out += [PSCustomObject]@{
            phase = $phase
            table = $t
            row_count = $rowCount
            size_mb = $sizeMb
            partition_column = $mp.col
            partition_type = $mp.type
            interval = $mp.interval
            rationale = $mp.reason
            dataareaid_distinct = if ($dataareaStats.ContainsKey($t)) { $dataareaStats[$t] } else { '' }
        }
    } else {
        # Default: small table → no partitioning
        $type = 'NONE'; $col = ''; $interval = ''; $reason = ''
        if ($rowCount -ge 5000000 -or $sizeMb -ge 5000) {
            $type = 'TBD'; $reason = 'flagged for review - borderline size, not in manual pick map'
        } else {
            $reason = "small table ($rowCount rows / $sizeMb MB) - no partitioning needed; index on DataAreaId + business key"
        }
        $out += [PSCustomObject]@{
            phase = $phase
            table = $t
            row_count = $rowCount
            size_mb = $sizeMb
            partition_column = $col
            partition_type = $type
            interval = $interval
            rationale = $reason
            dataareaid_distinct = if ($dataareaStats.ContainsKey($t)) { $dataareaStats[$t] } else { '' }
        }
    }
}

$out | Export-Csv 'C:\git\integration-idb\apiconversion\partitioning\_recommendations.csv' -NoTypeInformation
Write-Host "Wrote _recommendations.csv with $($out.Count) rows"
Write-Host "By partition_type:"
$out | Group-Object partition_type | Select-Object Name, Count | Format-Table
