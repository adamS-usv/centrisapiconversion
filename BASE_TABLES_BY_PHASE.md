# Project Atlas Phase 2 — Base Tables by Phase

> Companion to `PROJECT_PLAN.html`, `MASTER_IMPLEMENTATION_PLAN.md`, and `SPROC_VIEW_API_MAPPING.md`.
>
> **Purpose:** tells the source/replication team **when each `d365.*` base table is needed** so they can prioritize CDC/DMS pipeline coverage into AlloyDB.

---

## Headline

Per `PROJECT_PLAN.html` §05 and §07-Risk-#1, the **Phase 0 → 1 gate explicitly requires "d365.* schema sign-off"** — meaning the plan calls for **all base tables landed in AlloyDB by end of Phase 0 (~2 months)**. Risk #1 mitigation reinforces this: *"written confirmation per table; smoke-test query against each Phase 1 API's source tables before that team starts work."*

So the literal ask to the source team is: **start on everything at Phase 0 kickoff.** What changes by phase is **priority** — which tables block the next API team if they slip. The sections below give that priority order, derived from grouping the 365 views in `integration-idb/src/database/sqlserver/Scripts/views/` by D365 domain and mapping each domain to the APIs that consume it.

---

## How to use this document

- Each phase section lists the `d365.*` base tables that **become required** by the start of that phase.
- A table appearing in an earlier phase is **not repeated** in later phases — assume it's already replicated.
- Filenames map 1:1 to D365 source tables: `Scripts/views/dbo.<name>.sql` → `d365.<name>`.

---

## Phase 0 — Foundation (have ready before Phase 1 starts)

Cross-cutting tables every API joins through. **If these are late, every team blocks.**

### Party / Org backbone
`dirpartytable`, `dirpartylocation`, `dirpartylocationrole`, `DIRPARTYBASEENTITY`, `DIRPARTYLOCATIONROLESVIEW`, `DIRPARTYNAMEPRIMARYADDRESSVIEW`, `DIRPARTYPOSTALADDRESSVIEW`, `dirperson`, `dirpersonname`, `dirorganization`, `dirorganizationbase`, `dirorganizationname`, `dirdunsnumber`, `dirnameaffix`, `dirnamesequence`, `v_dirpartytable`, `v_DirOrganization`, `v_DirPerson`, `companyinfo`, `companynafcode`

### Logistics / addresses
`logisticslocation`, `logisticslocationext`, `logisticslocationrole`, `logisticspostaladdress`, `LOGISTICSPOSTALADDRESSBASEENTITY`, `LOGISTICSPOSTALADDRESSVIEW`, `logisticsaddresscountryregion`, `logisticselectronicaddress`, `logisticselectronicaddressrole`

### Financial dimensions (joined by nearly every domain)
`dimensionattribute`, `dimensionattributedircategory`, `dimensionattributelevelvalue`, `dimensionattributevalue`, `dimensionattributevaluecombination`, `dimensionattributevaluegroup`, `dimensionattributevaluegroupcombination`, `dimensionattributevalueset`, `dimensionattributevaluesetitem`, `dimensionhierarchy`, `dimensionhierarchyintegration`, `dimensionhierarchylevel`, `dimensionparameters`, `DIMENSIONCOMBINATIONENTITY`, `DIMENSIONSETENTITY`, `vDEFAULTDIMENSIONVIEW`, `DIMATTRIBUTEBANKACCOUNTTABLE`, `DIMATTRIBUTECOMPANYINFO`, `DIMATTRIBUTECUSTGROUP`, `DIMATTRIBUTECUSTTABLE`, `DIMATTRIBUTEFINANCIALTAG`, `DIMATTRIBUTEHCMJOB`, `DIMATTRIBUTEHCMPOSITION`, `DIMATTRIBUTEHCMWORKER`, `DIMATTRIBUTEINVENTITEMGROUP`, `DIMATTRIBUTEINVENTTABLE`, `DIMATTRIBUTEMAINACCOUNT`, `DIMATTRIBUTEOMBUSINESSUNIT`, `DIMATTRIBUTEOMCOSTCENTER`, `DIMATTRIBUTEOMDEPARTMENT`, `DIMATTRIBUTEOMVALUESTREAM`, `DIMATTRIBUTERETAILCHANNEL`, `DIMATTRIBUTEVENDGROUP`, `DIMATTRIBUTEVENDTABLE`

### HCM / responsibilities
(Salesforce + Customer use these in Phase 1/2)

`hcmworker`, `hcmworkertitle`, `hcmtitle`, `hcmposition`, `hcmpositiondetail`, `hcmpositionhierarchy`, `hcmpositionhierarchytype`, `hcmpositionworkerassignment`, `hcmjob`, `hcmjobdetail`, `hcmemployment`, `hcmpersondetails`, `hcmreasoncode`, `HCMWORKERDETAILSVIEW`, `smmresponsibilitiesempltable`, `smmactivities`, `smmactivityparentlinktable`

### Org units
`ominternalorganization`, `omoperatingunit`, `omteam`, `omteammembershipcriterion`

### System / reference data
`currency`, `unitofmeasure`, `unitofmeasureconversion`, `numbersequencetable`, `systemparameters`, `sysuserinfo`, `sysuserlog`, `workcalendardate`, `workcalendardateline`, `workcalendartable`, `WORKCALENDARDAYENTITY`, `WORKCALENDARENTITY`, `WORKCALENDARTIMEINTERVALENTITY`

### Smoke-test reference
(Phase 0 §05 success criteria literally names this one)

`custtable`

---

## Phase 1 — Pilot APIs

**APIs:** Routes, Platform, RudiCompass (new), SalesforceIntegration
**Lead time ask:** have ready ~1 month before Phase 1 starts (~end of Phase 0)

### Routes (eta)
`usvroutedeliveryschedule`, `usvrouteline`, `usvroutetable`, `USVROUTETABLECUSTVIEW`, `dlvmode`

### SalesforceIntegration
`vCustomerContactInfo_SalesForce`, `vwDimCustomerContacts`, `custtable` *(referenced from Phase 0)*, `custgroup` (early subset of Phase 2 Customer scope — Salesforce sync needs it before Phase 2)

### RudiCompass (validates customer/program/product references)
`usvprogramcustomer`, `USVPROGRAMCUSTOMERENTITY`, `usvprogramproducts`, `usvprogramtable`, `ecoresproduct`, `ecoresdistinctproduct`

### Platform
Minimal d365 footprint — mostly operational/diagnostic. Phase 0 foundation tables sufficient.

---

## Phase 2 — Foundational masters

**APIs:** Customer, Vendor, Warehouse, Product
**Lead time ask:** have ready ~1 month before Phase 2 starts

### Customer (~30 tables)
`custtable`, `custgroup`, `custparameters`, `custbankaccount`, `custdefaultlocation`, `custpaymmodetable`, `custpaymmodespec`, `custaging`, `customerinstancevalue`, `custvendexternalitem`, `credmancreditlimitcustgroup`, `credmancreditlimitcustgroupline`, `mcrcusttable`, `mcrholdcodetrans`, `retailcusttable`, `retailmcrchanneltable`, `retailchanneltable`, `whscusttable`, `usvacquisitiontable`, `USVAISCustomerLookupByOrgNumSegmentStagingView`, `USVCUSTOMERRESPONSIBILITIESEMPLENTITY`, `usvexclusionprogramcustomerproducts`, `USVDIRPARTYCONTACTV3ENTITY`, `USVDIRPARTYPOSTALADDRESSSTAGINGVIEW`, `USVLOGISTICSCONTACTINFOSTAGINGVIEW`, `USVLOGISTICSPOSTALADDRESSENTITY`, `USVLOGISTICSPOSTALADDRESSSTAGINGVIEW`

### Vendor
`vendtable`, `vendgroup`, `vendbankaccount`, `vendpaymmodetable`, `pdsapprovedvendorlist`, `VENDVENDOREXTERNALCODEENTITY`

### Warehouse
`whsworker`, `whsworktable`, `whsworkline`, `whsworklinecyclecount`, `whsworktemplatetable`, `whsworkclasstable`, `whsworkuser`, `whsworkuserwarehouse`, `whsworkusersessionlog`, `whsloadtable`, `whsloadline`, `whsshipmenttable`, `whslocationprofile`, `whsparameters`, `wmslocation`, `inventlocation`, `inventlocationlogisticslocation`, `inventlocationlogisticslocationrole`, `inventsite`, `INVENTWAREHOUSEPOSTALADDRESSENTITY`, `mcrpickingwbwarehouseinfo`, `usvwarehousepostaladdress`, `usvwarehousetransfersupplywarehouse`, `usvproductexclusionbywhs`, `usvproductfirstreceiptdate`, `tmsloadbuildstrategyattribvalueset`

### Product
**Catalog (ecores):** `ecoresattribute`, `ecoresattributetype`, `ecoresattributevalue`, `ecoresbooleanvalue`, `ecorescategoryhierarchy`, `ecorescategoryhierarchyrole`, `ecoresdatetimevalue`, `ecoresdistinctproduct`, `ecoresfloatvalue`, `ecoresinstancevalue`, `ecoresintvalue`, `ecoresproduct`, `ecoresproductcategory`, `ecoresproductimage`, `ecoresproductinstancevalue`, `ecoresproductrelationtable`, `ecoresproductrelationtype`, `ecoresproducttranslation`, `ecoresreferencevalue`, `ecoresstoragedimensiongroup`, `ecoresstoragedimensiongroupproduct`, `ecorestextvalue`, `ecoresvalue`

**Inventory setup:** `inventtable`, `inventdim`, `inventitemgroup`, `inventitemgroupitem`, `inventiteminventsetup`, `inventitempurchsetup`, `inventitemsalessetup`, `inventmodelgroupitem`, `inventitembarcode`, `inventtablemodule`, `mcrinventtable`

**BOM:** `bom`, `bomtable`, `bomversion`

**USV product attributes (8 tables):** `usvecoresprodexhuastattributes`, `usvecoresprodlubeschemicalattributes`, `usvecoresprodmicsitemsattributes`, `usvecoresprodpartsattributes`, `usvecoresprodtiresaccessoriesattributes`, `usvecoresprodtiresattributes`, `usvecoresprodtiresattributesext`, `usvecoresprodtubesattributes`

**Pricing & misc:** `whsecoresproducttransportationcodes`, `guppricetreeinstancevalue`, `retailpricingsimulatorinstancevalue`, `usvitemchargestable`, `pricedisctable`, `pricediscadmtable`, `pricediscadmtrans`

---

## Phase 3 — Dependent reads

**APIs:** Program, Delivery, PurchaseOrder, Invoice, TransferOrder
**Lead time ask:** have ready ~1 month before Phase 3 starts

### Program
`USVPROGRAMCUSTPRODEXCLUSIONTABLEENTITY`, `USVPROGRAMPRODUCTSTABLEENTITY`, `USVPROGRAMTABLEENTITY`, `usvprogramcustprodexclusiontable`, `usvprogramreasoncode`, `usvsspprogramcustomer`, `usvsspprogramproducts`, `vDuplicatePrograms`, `vProgramsWithNoItems`, `vProgramTablesWithZeroRecords`

### Delivery
*Reuses Routes set from Phase 1.* No new base tables.

### PurchaseOrder
`purchtable`, `purchline`, `purchtablehistory`, `purchlinehistory`, `purchtableversion`, `purchparameters`, `reqitemtable`, `intercompanypurchsalesreference`, `vendpackingslipjour`, `vendpackingsliptrans`, `vendpackingslipversion`

### Invoice
**Customer-side:** `custinvoicejour`, `custinvoicetrans`, `custinvoicesaleslink`, `custinterestjour`, `custinteresttrans`, `custsettlement`, `custtrans`, `custtransopen`, `custconfirmjour`

**Vendor-side:** `vendinvoicejour`, `vendinvoicetrans`, `vendinvoiceinfotable`, `vendinvoiceinfoline`, `vendsettlement`, `vendtrans`, `vendtransopen`

**Tax:** `taxdata`, `taxtable`, `taxtrans`, `taxonitem`, `taxjournaltrans`, `idttaxlogparameters`, `taxgstreliefgroupheading_my`

**Payment terms & markup:** `paymday`, `paymterm`, `PAYMENTTERMENTITY`, `markuptable`, `markuptrans`, `agreementheader`

### TransferOrder
`inventtransfertable`, `inventtransferline`, `inventtransorigin`, `inventtransoriginsalesline`, `inventtrans`, `inventjournaltable`, `inventjournaltrans`, `inventsum`, `inventvaluereporttmpline`

---

## Phase 4 — Composite + finance

**APIs:** OrderStatus, Finance (new)
**Lead time ask:** have ready ~1 month before Phase 4 starts

### OrderStatus / Sales
`salestable`, `salesline`, `salesagreementheader`, `salesjournalautosummary`, `whssalesline`, `tmssalestable`, `usvsalescommissionresptable`, `usvsalestrackingnumbers`, `casedetail`, `casedetailbase`, `casecategoryhierarchydetail`

### Finance (new API)
**General ledger:** `generaljournalentry`, `generaljournalaccountentry`, `subledgerjournalaccountentrydistribution`, `ledger`, `ledgerentryjournal`, `ledgerfiscalcalendarperiod`, `ledgerjournalname`, `ledgerjournaltable`, `ledgertransvoucherlink`, `mainaccount`, `mainaccountcategory`

**Fiscal calendar:** `fiscalcalendarperiod`, `fiscalcalendaryear`

**FX:** `exchangerate`, `exchangeratecurrencypair`, `exchangeratetype`

**Bank:** `bankaccounttable`, `bankgroup`

**Financial dims (additions):** `dimensionfinancialtag`, `FINANCIALDIMENSIONVALUEENTITYFINANCIALTAGVIEW`

**Esker AR:** `Esker_USVOpenAR`, `USVOpenAR`, `USVPNCCUSTTRANSDATAENTITY`

**Customer statement / credit:** `usvcustavailcredit`, `usvcustinvoicejourstatement`, `usvcuststatement`, `usvgeneralledgerhierarchy`, `usvfndcategory`, `spectrans`

> **Decision needed before Phase 0 kickoff (PROJECT_PLAN §08):** confirm the `v_dirpartytable` shape — Esker quarantined procs depend on it. If unresolvable, Phase 4 ships in degraded state.

---

## Phase 5 — Complex integration

**APIs:** VendorProgram, InvoiceMatching, EdiOutbound, EdiInbound
**Lead time ask:** have ready ~1 month before Phase 5 starts

### VendorProgram
`usvtpnabatchduplicatetable`, `usvtpnaonlinecusteligibility`, `usvtpnaonlinedeliveryreceiptreturnheader`, `usvtpnaonlinedeliveryreceiptreturnline`, `usvtpnaonlinedeliveryreceiptvendornumseq`

*Reuses program/SSP tables from Phase 3 and vendor tables from Phase 2.*

### InvoiceMatching (RWA)
`usvibsinvoicematchdata`, `usvibsparameters`, `usvwarrantyclaimtable`, `usvreturnsparameters`, `returnreasoncode`, `returnreasoncodegroup`, `reasontableref`, `usvvendorcredittable`, `usvvendorcreditline`, `usvvendorcreditreturntable`, `usvvendorcreditreturnline`, `USVVENDORCREDITRETURNHEADERLINESENTITY`

### EDI (Inbound + Outbound)
`extcodetable`, `extcodevaluetable`, `usvinboundqueuelog`

*Reuses Vendor / Customer / PO / Invoice sets from earlier phases.*

---

## Phase 6 — Decommission

No new tables needed. Sources get archived/decommissioned.

---

## Concrete asks for the source/replication team

1. **At Phase 0 kickoff:** request full inventory replication (all 365 `d365.*` tables) — it's the formal Phase 0 → 1 gate. Prioritize the **Phase 0 foundation set** (~75 tables: party/org, logistics, dimensions, HCM, system refs, currency, calendars).
2. **2 weeks before Phase 1 starts:** require **written confirmation + smoke-test** on the Phase 1 table list (~15 tables — Routes, Salesforce, RudiCompass).
3. **2 weeks before each subsequent phase:** require the same per-phase smoke-test sign-off on that phase's table set, per Risk #1 mitigation.
4. **Flag now to source team:** the **Esker quarantine** and **`v_dirpartytable` question** (PROJECT_PLAN §08 decision needed before Phase 0). This is on the critical path for Phase 4 and is explicitly called out as a pre-Phase-0 decision.

---

## Tracking template

Suggested columns for a tracking sheet (Excel / ADO / Confluence):

| Table | Phase needed | Replicated? | Sign-off date | Smoke-test passed? | Owner | Notes |
|---|---|---|---|---|---|---|

---

## Caveats

- The per-API table mapping was derived from **D365 naming conventions and the proc → API mapping in `SPROC_VIEW_API_MAPPING.md`** — not by parsing every legacy proc's `FROM` clauses. There will be edge cases (e.g., a Customer proc that joins to an HCM table) where a "Phase 3" table is actually needed in Phase 2. The **Risk #1 per-phase smoke-test step is what catches these** before they block a team.
- The `usv*` and `v*` files in `integration-idb` are **derived business views**, not raw base-table mirrors — but they still come over from D365 with the same names (e.g., `dbo.usvprogramcustomer` selects from `[d365].[usvprogramcustomer]`). If D365 itself does not expose those USV views into the Fivetran feed, the team will need to either (a) replicate them as queryable objects in AlloyDB, or (b) rebuild them as Platform-owned ports (per PROJECT_PLAN: the ~60 USV business views ARE in Platform's port scope).
- This document covers the views currently present in `integration-idb/src/database/sqlserver/Scripts/views/` as of the date below. If views are added/removed from that folder, this document needs a refresh.

---

*Last reviewed: 2026-05-12*
