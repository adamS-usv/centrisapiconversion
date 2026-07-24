# Project Atlas Phase 2 — Boomi/Salesforce Integration Plan

This document captures the planned API structure for the `boomi.*` schema (in `boomisql/`), the integration boundary that brokers data between AX/D365 and Salesforce via Boomi. Format mirrors the `aissql/` plan.

---

## A. Inventory

11 files, no triage needed (no `_BAK`/`_ORIG`/`_old`/`vN`/dated variants present). Two distinct categories — **API-exposed** (the views) and **infrastructure-only** (xref tables + their loaders, no API surface).

| Type | Count | Files | API-exposed? |
|---|---|---|---|
| Cross-reference tables (DDL) | 3 | `0001_boomi.SalesforceXrefCustomer`, `0002_boomi.SalesforceXrefProgram`, `0003_boomi.SalesforceXrefUser` | **No** — internal join tables |
| Truncate procs | 3 | `Truncate_SalesforceXref{Customer,Program,User}` → `boomi.usp_Truncate_SalesforceXref*` | **No** — Boomi-managed load |
| Salesforce-shaped views (read side) | 4 | `5004_boomi.SalesforceEmployeeResponsible`, `5006_boomi.SalesforceCustomerV2`, `boomi.SalesforceCaseDetail`, `boomi.SalesforceWarehouse` | Yes |
| Inventory-check view | 1 | `boomi.FlexInventCheck_DefaultWarehouse` | Yes |

**Xref tables are infrastructure**, not data products. They exist solely to resolve Salesforce GUIDs (for users, programs, customers) inside the view queries — e.g. `SalesforceCustomerV2` joins `boomi.SalesforceXrefUser` to get a personnel number's Salesforce ID. They will live in AlloyDB as native Postgres tables; Boomi continues to populate them via its existing wipe-and-reload pipeline (truncate proc + bulk insert) writing directly to the database. The Atlas API never reads or writes them through an endpoint.

This means: **the truncate procs are out of scope for the API**, but the xref-table DDL must still be ported to AlloyDB so the views can join to them.

---

## B. Domain map

This whole folder is **one bounded context** — the Salesforce sync surface. There's no value in splitting these views across multiple APIs because:

- The 5 views all serve the same consumer (Boomi → Salesforce sync flows).
- `SalesforceCustomerV2` directly references `boomi.SalesforceEmployeeResponsible` and `boomi.SalesforceXrefUser`, so they're already inter-coupled at the SQL level.
- The xref tables only exist to support these views — they have no independent business meaning.

Even `FlexInventCheck_DefaultWarehouse` (which doesn't have "Salesforce" in the name) lives in the `boomi` schema and is a Boomi-consumed projection of customer/warehouse data — same consumer, same conduit.

### 17. `SalesforceIntegration` — Boomi/Salesforce sync surface

**Project**: `Services.SalesforceIntegration.Api` (alternative names worth considering: `Services.BoomiSync.Api`, `Services.SalesforceSync.Api` — pick based on team naming convention).

**Scope**: Read-only API exposing Salesforce-shaped projections of AX/D365 master data (customer, case, warehouse, employee responsible) plus the inventory-check default-warehouse lookup. All output uses Central Standard Time conversion to match Salesforce's storage convention.

**Source objects**:
- **Views (API-exposed)**: `SalesforceCustomerV2`, `SalesforceCaseDetail`, `SalesforceWarehouse`, `SalesforceEmployeeResponsible`, `FlexInventCheck_DefaultWarehouse`
- **Internal tables (queries join to them; not API-exposed)**: `SalesforceXrefCustomer`, `SalesforceXrefProgram`, `SalesforceXrefUser`

**Proposed endpoints**:

| Logical Op | HTTP | Endpoint |
|---|---|---|
| Get Salesforce-shaped customer projections (filters: customer account, modified-since for delta-pull, paging) | GET | `/salesforce/customers` |
| Get a single Salesforce customer projection | GET | `/salesforce/customers/{customerAccount}` |
| Get Salesforce case detail (filters: case id, status, modified-since) | GET | `/salesforce/cases` |
| Get Salesforce warehouse projection (filters: warehouse id, modified-since) | GET | `/salesforce/warehouses` |
| Get employee-responsible mapping (filters: customer account, responsibility id) | GET | `/salesforce/employee-responsible` |
| Get default warehouse for customer (FlexInventCheck) | GET | `/salesforce/flex-invent-check/default-warehouse` |

**Endpoint count**: 6 (all read; no commands).

**Note on xref tables**: `SalesforceXrefCustomer`, `SalesforceXrefProgram`, and `SalesforceXrefUser` are joined to inside repository SQL (e.g. `SalesforceCustomerV2` resolves owner Salesforce IDs via `SalesforceXrefUser`) but are **not** exposed via API. Boomi continues to populate them by writing directly to AlloyDB using the existing wipe-and-reload pattern. Their DDL must be included in the AlloyDB schema migration; the truncate procs (`usp_Truncate_SalesforceXref*`) remain as DB objects for Boomi to call, but the API does not surface either the tables or the procs.

**Depends on**: nothing within Atlas. Could be deployed independently.

---

## C. Updated total

| # | Domain | Project | Endpoints | Source count |
|---|---|---|---|---|
| 1–16 | (see `aissql/` plan if/when re-created) | … | ~135 | ~145 procs |
| 17 | SalesforceIntegration | `Services.SalesforceIntegration.Api` | 6 | 5 views (+ 3 internal xref tables, no endpoints) |
| **Total** | | **17 APIs** | **~141** | **~150 objects** |

---

## D. Cross-cutting concerns specific to this domain

1. **Timezone conversion**. Every datetime column in the Salesforce-shaped views runs through:
   ```sql
   CONVERT(datetime, SWITCHOFFSET(col, DATEPART(TZOFFSET, col AT TIME ZONE 'Central Standard Time')))
   ```
   Salesforce expects all timestamps in CST (not UTC). The Postgres equivalent is `col AT TIME ZONE 'America/Chicago'`. This must be preserved verbatim — a UTC port will silently drift Salesforce records by 5–6 hours depending on DST.

2. **Hardcoded fallback owner ID** in `SalesforceCustomerV2`: `'0056e00000BuxsJ'` is used as the default `SalesforceID_OwnerID` when no specific BC (Business Consultant) match is found. **Promote to configuration** (`appsettings.json` → `SalesforceIntegration:DefaultOwnerId`) — these IDs differ between Salesforce sandboxes and production, and a hardcoded value will silently miswire ownership in non-prod environments.

3. **Responsibility-ID priority chain** in `SalesforceCustomerV2`: owner is resolved by checking `'USAF BC'` → `'USAF Car Dealer BC'` → `'Lubes BC'` in that order. Encode this priority list in configuration (or a dedicated lookup table) rather than inlining in the SQL — it's almost certain to grow.

4. **`COLLATE DATABASE_DEFAULT` joins**. The xref tables use `nchar(50)` for `PersonnelNumber` while `HCMWORKER.PersonnelNumber` is collated differently, hence the explicit `COLLATE DATABASE_DEFAULT` on every join. In Postgres/AlloyDB this disappears (no per-column collation by default), so the repository SQL is cleaner — but flag for the data team that the AlloyDB target should use `text` (not `char(N)`) to avoid trailing-space surprises during the wipe-and-reload.

5. **`DataAreaId = '40'` filter** is consistent with the rest of the project — same legalEntity discussion applies. Surface as a parameter (or thread through claims).

6. **`SalesforceCustomerV2` is heavy** (~50 columns, 14 joins, GROUP BY of 50 columns, with cross-references to `boomi.SalesforceEmployeeResponsible` and `boomi.SalesforceXrefUser`). Likely the slowest endpoint in this domain. **Recommend** wrapping it in a materialized view at the AlloyDB layer with a `modified_since`-driven refresh, then exposing the API as a delta-pull endpoint (`?modifiedSince=2026-04-29T00:00:00Z`). Boomi flows almost certainly already do this delta pattern.

7. **`SalesforceCaseDetail` joins to `casedetailbase` and `casedetail`** — these are AX case-management tables not used elsewhere in the Atlas plan. New table coupling to add to the AlloyDB parity check.

8. **CDC / change-tracking**. Every view returns a per-table `*ModifiedDateTime` column (the CST-converted modified timestamp). This is the change-tracking signal Boomi uses for delta sync. Make sure the AlloyDB ports preserve these — losing one of them silently breaks one delta channel.

9. **The xref tables don't have audit columns** (no `created_by`, `created_on`, `last_updated_*`, `version`, `sort_order` per the USV Stack convention) because they're truncate-and-reload tables, not business tables. Document this explicitly in the AlloyDB migration so reviewers don't try to add them. They live in the `boomi` Postgres schema as plain `text`-typed tables; Boomi writes to them directly.

10. **Read-only API**. All 6 endpoints are GET — no commands, no validators. `Domain.SalesforceIntegration/Commands/` and `Domain.SalesforceIntegration/Validators/` folders won't exist in this project. The only Domain-layer artifact is the Autofac module + repository registrations.

---

## E. Phasing recommendation

Insert as an **early** API:

- **Independent of Atlas internals** — the views and xref tables don't depend on any other Atlas API. Could ship before Customer/Vendor/etc.
- **Read-only and bounded** — 6 GET endpoints, no commands, no validators. Smallest API surface in the project after the Routes (eta) work.
- **Salesforce sync is business-critical** — Boomi flows currently hit the DB directly; cutover requires Boomi-side reconfiguration, but the API contract is straightforward.

Suggested slot: **right after Routes (#1) and Platform (#2)** in the prior phasing — it's a clean second-/third-up API for validating the USV Stack template against view-only data sources (no proc bodies to port, just `SELECT` statements to wrap in handlers).

---

## F. Open questions

1. **API name**: `SalesforceIntegration`, `BoomiSync`, or `SalesforceSync`? Naming convention preference?
2. **Salesforce Owner ID fallback** (`'0056e00000BuxsJ'`): which Salesforce environment is that ID valid in? Confirm whether to promote to per-environment config or leave as a shared default.
3. **Materialized-view strategy for `SalesforceCustomerV2`**: is this acceptable in AlloyDB, or do we need a different change-data-capture story (e.g. logical replication)?
4. **Inbound Salesforce → AX** flows: this folder only covers AX → Salesforce projections. If Boomi also writes back to AX from Salesforce events, those procs/tables aren't in this folder — confirm whether a future API surface needs to cover inbound too.
5. **Boomi xref-load access path**: confirm Boomi will continue writing directly to AlloyDB (same model as today, just a different DB engine) and that no API/service intermediation is wanted for the xref load. If so, the AlloyDB migration needs to provision a Boomi-owned DB role with INSERT/TRUNCATE permissions on the `boomi.SalesforceXref*` tables.
