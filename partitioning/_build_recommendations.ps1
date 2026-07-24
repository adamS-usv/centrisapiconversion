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
    # Phase 0 - Foundation. Mostly reference. sysuserlog is the only big one.
    'sysuserlog' = @{ col='createddatetime'; type='RANGE'; interval='monthly'; reason='10M user log rows; createddatetime spans 2018-2026' }

    # Phase 2 - Masters
    'whsworkline'                              = @{ col='modifieddatetime'; type='RANGE'; interval='monthly'; reason='528M rows / 445 GB; D365 WHS module live 2023-02 onward; high CDC churn' }
    'inventdim'                                = @{ col='modifieddatetime'; type='RANGE'; interval='quarterly'; reason='328M rows; dimension rows only updated since 2025-06 - short window, quarterly is enough' }
    'whsworktable'                             = @{ col='modifieddatetime'; type='RANGE'; interval='monthly'; reason='239M rows / 136 GB; companion of whsworkline; same WHS-2023 timeline' }
    'usvexclusionprogramcustomerproducts'      = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='151M rows / 75 GB; both audit columns 1900-01-01; no business date - uniform spread by RecId' }
    'ecoresvalue'                              = @{ col='modifieddatetime'; type='RANGE'; interval='quarterly'; reason='82M rows / 43 GB; attribute catalog churns post-2023, quarterly windows are fine' }
    'ecoresattributevalue'                     = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='82M rows / 34 GB; audit columns all 1900-01-01; catalog with single DataAreaId - HASH by RecId' }
    'ecorestextvalue'                          = @{ col='modifieddatetime'; type='RANGE'; interval='quarterly'; reason='78M rows / 29 GB; modifieddatetime 2023-02+ usable' }
    'whsshipmenttable'                         = @{ col='modifieddatetime'; type='RANGE'; interval='monthly'; reason='65M rows / 43 GB; shipment header, WHS-2023+' }
    'ecoresinstancevalue'                      = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='64M rows / 26 GB; both audit columns 1900-01-01; HASH by RecId' }
    'whsloadtable'                             = @{ col='modifieddatetime'; type='RANGE'; interval='monthly'; reason='55M rows / 47 GB; WHS-2023+' }
    'whsloadline'                              = @{ col='modifieddatetime'; type='RANGE'; interval='monthly'; reason='45M rows / 58 GB; WHS-2023+' }
    'usvecoresprodpartsattributes'             = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='17M rows; product attribute catalog, no usable dates; HASH by RecId' }
    'usvecoresprodtiresattributes'             = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='17M rows; same pattern' }
    'usvecoresprodlubeschemicalattributes'     = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='17M rows; same pattern' }
    'whsworklinecyclecount'                    = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='10M rows; both audit cols 1900-01-01; HASH by RecId' }
    'usvecoresprodtiresaccessoriesattributes'  = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }
    'usvecoresprodmicsitemsattributes'         = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }
    'usvecoresprodexhuastattributes'           = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }
    'usvecoresprodtubesattributes'             = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }
    'usvecoresprodtiresattributesext'          = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='8.8M rows; product attribute catalog' }

    # Phase 3 - Dependent reads
    'inventtrans'              = @{ col='datephysical'; type='RANGE'; interval='monthly'; reason='495M rows / 373 GB; datephysical 1900-2026 (default partition for migrated 1900 rows + monthly post-2019)' }
    'inventsum'                = @{ col='_HASH_RECID'; type='HASH'; interval='16 partitions'; reason='399M rows / 329 GB; inventory snapshot, no business date; HASH for parallel reads' }
    'inventtransorigin'        = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='238M rows / 132 GB; both audit columns 1900-01-01; _fivetran_synced only 6 weeks; HASH by RecId' }
    'vendsettlement'           = @{ col='transdate'; type='RANGE+LIST'; interval='quarterly + LIST(DataAreaId)'; reason='227M rows / 125 GB; transdate 2019-2026; 16 DataAreaIds - composite partition for legal-entity isolation' }
    'vendtrans'                = @{ col='transdate'; type='RANGE+LIST'; interval='quarterly + LIST(DataAreaId)'; reason='179M rows / 169 GB; transdate 2019-2026; 8 DataAreaIds' }
    'custtrans'                = @{ col='transdate'; type='RANGE+LIST'; interval='monthly + LIST(DataAreaId)'; reason='134M rows / 126 GB; transdate 2019-2026; 8 DataAreaIds; heavy date-range query pattern' }
    'taxtrans'                 = @{ col='transdate'; type='RANGE'; interval='quarterly'; reason='114M rows / 110 GB; transdate 2019-2026; 5 DataAreaIds' }
    'custinvoicetrans'         = @{ col='invoicedate'; type='RANGE+LIST'; interval='monthly + LIST(DataAreaId)'; reason='103M rows / 138 GB; invoicedate 2019-2026; 5 DataAreaIds - invoice queries always filter both' }
    'custinvoicejour'          = @{ col='invoicedate'; type='RANGE+LIST'; interval='monthly + LIST(DataAreaId)'; reason='90M rows / 125 GB; invoicedate 2019-2026; 6 DataAreaIds; primary table for Invoice API' }
    'custsettlement'           = @{ col='transdate'; type='RANGE'; interval='quarterly'; reason='84M rows / 84 GB; transdate 2019-2026; 7 DataAreaIds' }
    'custconfirmjour'          = @{ col='confirmdate'; type='RANGE'; interval='monthly'; reason='57M rows / 26 GB; confirmdate 2023-2026 (D365 cutover); single DataAreaId' }
    'taxjournaltrans'          = @{ col='transdate'; type='RANGE'; interval='quarterly'; reason='52M rows / 39 GB; transdate 2019-2026; 4 DataAreaIds' }
    'vendinvoicejour'          = @{ col='invoicedate'; type='RANGE+LIST'; interval='monthly + LIST(DataAreaId)'; reason='51M rows / 62 GB; 17 DataAreaIds - heaviest multi-entity table' }
    'inventtransoriginsalesline' = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='36M rows; audit cols 1900-01-01; HASH by RecId' }
    'custinvoicesaleslink'     = @{ col='invoicedate'; type='RANGE'; interval='quarterly'; reason='30M rows / 23 GB; invoicedate 2019-2026; 5 DataAreaIds' }
    'markuptrans'              = @{ col='transdate'; type='RANGE'; interval='quarterly'; reason='26M rows / 28 GB; transdate mostly post-2019 (some 1900 migrated rows -> default partition)' }
    'reqitemtable'             = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='24M rows; audit cols 1900-01-01; no business date' }
    'purchlinehistory'         = @{ col='deliverydate'; type='RANGE'; interval='quarterly'; reason='22M rows / 24 GB; deliverydate spans 1900-2029 (planned future + migrated past) - quarterly with default partition' }
    'purchline'                = @{ col='deliverydate'; type='RANGE+LIST'; interval='quarterly + LIST(DataAreaId)'; reason='20M rows / 34 GB; deliverydate 1900-2029; PO line queries filter delivery window' }
    'vendpackingsliptrans'     = @{ col='accountingdate'; type='RANGE'; interval='quarterly'; reason='18M rows / 16 GB; accountingdate 2023-2026' }
    'vendinvoicetrans'         = @{ col='invoicedate'; type='RANGE'; interval='quarterly'; reason='18M rows / 21 GB; invoicedate 2023-2026; 2 DataAreaIds' }
    'inventtransferline'       = @{ col='createddatetime'; type='RANGE'; interval='quarterly'; reason='12M rows / 15 GB; createddatetime 2023-2026' }
    'usvsspprogramcustomer'    = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='9M rows; both audit cols 1900-01-01' }
    'usvsspprogramproducts'    = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='9M rows; both audit cols 1900-01-01' }
    'inventtransfertable'      = @{ col='createddatetime'; type='RANGE'; interval='quarterly'; reason='8.9M rows / 6.8 GB; createddatetime 2023-2026' }
    'inventvaluereporttmpline' = @{ col='transdate'; type='RANGE'; interval='quarterly'; reason='8.7M rows; transdate 2023-2026; temp-line table - consider whether to partition at all (TBD with API team)' }
    'custinteresttrans'        = @{ col='transdate'; type='RANGE'; interval='quarterly'; reason='6.5M rows / 6.9 GB; transdate 2019-2026; 3 DataAreaIds' }
    'inventjournaltrans'       = @{ col='transdate'; type='RANGE'; interval='quarterly'; reason='6.2M rows; transdate 2023-2026' }
    'vendinvoiceinfoline'      = @{ col='_HASH_RECID'; type='HASH'; interval='4 partitions'; reason='5.5M rows; audit cols 1900-01-01' }

    # Phase 4 - Composite + Finance
    'generaljournalaccountentry' = @{ col='modifieddatetime'; type='RANGE'; interval='monthly'; reason='475M rows / 431 GB; modifieddatetime 2020-10 to 2026-06; biggest GL table' }
    'generaljournalentry'        = @{ col='accountingdate'; type='RANGE+LIST'; interval='monthly + LIST(DataAreaId)'; reason='153M rows / 109 GB; accountingdate 2016-2026 - 10-year span; finance API filters by date AND legal entity' }
    'salesline'                  = @{ col='shippingdaterequested'; type='RANGE+LIST'; interval='monthly + LIST(DataAreaId)'; reason='75M rows / 187 GB; shippingdaterequested 2019-2026 clean (use this over shippingdateconfirmed which has 1900-01-01 entries); 3 DataAreaIds' }
    'salestable'                 = @{ col='deliverydate'; type='RANGE+LIST'; interval='monthly + LIST(DataAreaId)'; reason='59M rows / 110 GB; deliverydate 2019-2026; sales order header - partner of salesline' }
    'usvsalescommissionresptable'= @{ col='invoicedate'; type='RANGE'; interval='monthly'; reason='48M rows / 28 GB; invoicedate 2023-2026' }
    'subledgerjournalaccountentrydistribution' = @{ col='createddatetime'; type='RANGE'; interval='monthly'; reason='42M rows / 19 GB; createddatetime 2021-2026' }
    'ledgertransvoucherlink'     = @{ col='transdate'; type='RANGE+LIST'; interval='quarterly + LIST(DataAreaId)'; reason='37M rows / 16 GB; transdate 2017-2026; 12 DataAreaIds' }
    'whssalesline'               = @{ col='modifieddatetime'; type='RANGE'; interval='monthly'; reason='34M rows / 20 GB; modifieddatetime 2023-2026' }
    'usvcuststatement'           = @{ col='transdate'; type='RANGE'; interval='monthly'; reason='31M rows / 19 GB; transdate 2023-2026' }
    'tmssalestable'              = @{ col='modifieddatetime'; type='RANGE'; interval='monthly'; reason='29M rows / 16 GB; modifieddatetime 2023-2026' }
    'ledgerjournaltable'         = @{ col='createddatetime'; type='RANGE'; interval='quarterly'; reason='27M rows / 24 GB; createddatetime mixed (some 1900) but spans to 2026; 9 DataAreaIds' }
    'usvcustinvoicejourstatement'= @{ col='invoicedate'; type='RANGE'; interval='monthly'; reason='19M rows / 12 GB; invoicedate 2023-2026' }
    'ledgerentryjournal'         = @{ col='_HASH_RECID'; type='HASH'; interval='8 partitions'; reason='14M rows; all audit columns 1900-01-01; HASH by RecId' }
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
