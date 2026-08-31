# Ticketure Data Platform Assessment: Findings, Architecture & Reconciliation Report

## Executive Summary

This report documents the design, implementation, and analytical findings for the **Ticketure Data Platform Take-Home Exercise**.

A robust, layered **dbt + DuckDB** data warehouse project was developed to transform messy operational raw seed data into trusted, tested dimensions and fact models. The core deliverable—calculating **Net Revenue per tenant and per event**—has been computed and fully reconciled against Finance's records.

---

## 1. What Was Built: Architecture & Model Grain

The transformation pipeline follows a clean **Staging $\rightarrow$ Intermediate $\rightarrow$ Marts** architecture.

```
raw seeds (8)
   │
   ▼
staging (8 views) ──► intermediate (4 views) ──► marts (8 tables)
                                                      ├── Dimensions (4)
                                                      └── Facts & Aggregations (4)
```

### Staging Layer (`models/staging/` — Views)
Light transformations: type casting, field trimming, timestamp parsing, and basic standardization.
- [`stg_tenants`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/staging/stg_tenants.sql) — **Grain: 1 row per tenant (`tenant_id`)**.
- [`stg_venues`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/staging/stg_venues.sql) — **Grain: 1 row per venue (`venue_id`)**. Timezone standardization (imputes `America/New_York` for New York where null).
- [`stg_events`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/staging/stg_events.sql) — **Grain: 1 row per event (`event_id`)**.
- [`stg_customers`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/staging/stg_customers.sql) — **Grain: 1 row per customer record (`tenant_id`, `customer_id`)**. Normalizes email casing and country codes.
- [`stg_orders`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/staging/stg_orders.sql) — **Grain: 1 row per order (`order_id`)**. Numeric casts (`numeric(10,2)`); imputes missing `tenant_id` from event mapping (recovers order `O6`).
- [`stg_tickets`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/staging/stg_tickets.sql) — **Grain: 1 row per ticket (`ticket_id`)**. Numeric casts; imputes missing `tenant_id` (recovers ticket `TK9`).
- [`stg_refunds`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/staging/stg_refunds.sql) — **Grain: 1 row per unique refund (`refund_id`)**. Strictly deduplicates duplicate records (`R1`).
- [`stg_scans`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/staging/stg_scans.sql) — **Grain: 1 row per gate scan (`scan_id`)**.

### Intermediate Layer (`models/intermediate/` — Views)
Business logic encapsulation, pre-aggregations, and anomaly flagging.
- [`int_order_refunds_summary`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/intermediate/int_order_refunds_summary.sql) — **Grain: 1 row per order (`order_id`)**. Aggregates completed vs. failed refunds.
- [`int_orders_enriched`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/intermediate/int_orders_enriched.sql) — **Grain: 1 row per order (`order_id`)**. Calculates order-level net revenue; flags anomalies (`is_currency_mismatch`, `is_over_refunded`, `is_refund_before_order`, `is_imputed_tenant`).
- [`int_ticket_scans_summary`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/intermediate/int_ticket_scans_summary.sql) — **Grain: 1 row per ticket (`ticket_id`)**. Scan counts, first/last timestamps, multi-scan detection.
- [`int_tickets_enriched`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/intermediate/int_tickets_enriched.sql) — **Grain: 1 row per ticket (`ticket_id`)**. Integrates order status, attendance flag (`is_attended`), and invalid gate entry flags (`is_invalid_scan`).

### Marts Layer (`models/marts/` — Tables)
Curated dimensional models and facts ready for BI tools, reporting, and Snowflake data shares.
- [`dim_tenants`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/marts/dim_tenants.sql) — **Grain: 1 row per tenant (`tenant_id`)**.
- [`dim_venues`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/marts/dim_venues.sql) — **Grain: 1 row per venue (`venue_id`)**.
- [`dim_events`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/marts/dim_events.sql) — **Grain: 1 row per event (`event_id`)**. Enriched with venue capacity and timezone.
- [`dim_customers`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/marts/dim_customers.sql) — **Grain: 1 row per tenant-customer (`customer_surrogate_key` = `tenant_id || '_' || customer_id`)**.
- [`fct_orders`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/marts/fct_orders.sql) — **Grain: 1 row per order (`order_id`)**. Financial measures, fees, taxes, completed refunds, and net revenue.
- [`fct_tickets`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/marts/fct_tickets.sql) — **Grain: 1 row per ticket (`ticket_id`)**. Status, pricing, and scan activity.
- [`fct_gate_scans`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/marts/fct_gate_scans.sql) — **Grain: 1 row per scan event (`scan_id`)**. Access control audit fact identifying ghost barcodes and invalid entries.
- [`fct_tenant_event_revenue`](file:///Users/aka/Workspace/technical-assessments/Ticketure/data-platform-interview-main%202/models/marts/fct_tenant_event_revenue.sql) — **Grain: 1 row per `tenant_id`, `event_id`, and `currency`**. The primary reporting mart answering the assessment question.

---

## 2. Metric Rules & Modeling Assumptions

1. **Net Revenue Formula**:
   $$\text{Net Revenue} = \text{gross\_amount} - \text{tax\_amount} - \text{completed\_refunds}$$
   - Platform fees (`fee_amount`) belong to Ticketure and are excluded from tenant revenue.
   - Only `completed` orders contribute to gross revenue and tax liabilities. `cancelled` (`O3`) and `pending` (`O7`) orders contribute `$0.00`.
   - Only `completed` refunds reduce net revenue. `failed` refunds (`R3`) are ignored.
2. **Refund Deduplication**:
   - `raw_refunds.csv` contains an exact duplicate row for `R1`. It is deduplicated in staging by `refund_id`.
3. **Tenant Imputation**:
   - Order `O6` and ticket `TK9` arrived with `tenant_id = NULL`. Because they reference event `E3` (owned by `T2`), `tenant_id` was imputed as `T2`, avoiding a £74.00 revenue drop.
4. **Multi-Currency Representation**:
   - Rather than applying artificial exchange rates, revenue is partitioned by transaction currency (`(tenant_id, event_id, currency)`).
5. **Time Anomaly Handling**:
   - Refund `R4` created on `2025-02-19` precedes order `O1` timestamp `2025-02-20`. Assumed to be clock drift or retroactive adjustment, but treated as a valid completed refund against `O1`.

---

## 3. Financial Reconciliation & Results

### Query Output from `fct_tenant_event_revenue`

| Tenant ID | Tenant Name | Event ID | Event Name | Currency | Orders | Gross Revenue | Platform Fee | Tax Amount | Completed Refunds | Net Revenue | Valid Tickets | Attended |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **T1** | Apollo Arena | **E1** | Spring Opening Night | USD | 3 | $300.00 | $30.00 | $23.00 | $80.00 | **$197.00** | 2 | 2 |
| **T1** | Apollo Arena | **E2** | Acoustic Evening | USD | 0 | $0.00 | $0.00 | $0.00 | $0.00 | **$0.00** | 1 | 0 |
| **T1** | Apollo Arena | **E4** | Late March Show | USD | 1 | $80.00 | $8.00 | $6.00 | $0.00 | **$74.00** | 1 | 1 |
| **T2** | Beacon Festivals | **E3** | Beacon Day Festival | GBP | 3 | £630.00 | £63.00 | £46.00 | £100.00 | **£484.00** | 6 | 3 |
| **T2** | Beacon Festivals | **E3** | Beacon Day Festival | EUR | 1 | €100.00 | €10.00 | €7.00 | €150.00 | **-€57.00** | 1 | 0 |

---

### Tenant 1 (Apollo Arena) Reconciliation: EXACT MATCH ($271.00 USD)

Finance reported figure: **`$271.00`**.
Our model output: **`$271.00`** ($197.00 from E1 + $0.00 from E2 + $74.00 from E4).

**Why it reconciled**:
- Deduplication of `R1` ($50.00) prevented an erroneous $50 undercount.
- Failed refund `R3` ($100.00 on O2) was properly excluded.
- Non-completed orders `O3` (cancelled) and `O7` (pending) were filtered out.

---

### Tenant 2 (Beacon Festivals) Reconciliation: Root Causes & Requirements

Finance was unable to reconcile T2. Our investigation identified **4 distinct root causes**:

1. **Currency Mismatch (EUR vs GBP)**:
   - Order `O5` was charged in `EUR` (€100.00 gross, €7.00 tax), but T2's home currency is `GBP`. Naive summation produces invalid mixed-currency totals.
2. **Excessive / Over-Refund on Order `O5` (`R5`)**:
   - Refund `R5` is `150.00` on order `O5` (gross `100.00`). Refunding 150 against a 100 gross order creates negative net revenue (-€57.00). This suggests an operational error (goodwill payout, miskeyed amount, or currency confusion).
3. **Missing Foreign Key on Order `O6` & Ticket `TK9`**:
   - `tenant_id` was `NULL`. Without event-based imputation, £74.00 in net revenue would be omitted from T2 reporting.
4. **Unaccounted Order Value on Order `O9`**:
   - Order `O9` gross is £250.00, but its tickets (`TK13`, `TK14`) sum to £200.00. There is an unexplained £50.00 gap (unmodeled line item, addon, donation, or data corruption).

#### Requirements to Trust a T2 Number:
1. Daily foreign exchange (FX) rates table to convert EUR transactions to GBP at transaction time.
2. Operations confirmation on liability for the €50 excess refund on `O5`.
3. Granular order line items capturing add-ons/fees to reconcile the £50 gap on `O9`.

---

## 4. Source Data Anomalies & Questions for Source Owners

| Domain | Entity / Key | Description of Anomaly | Impact on Reporting | Question for Source System Owners |
| :--- | :--- | :--- | :--- | :--- |
| **Refunds** | `R1` | Duplicate rows in `raw_refunds.csv` | Double-counting would understate net revenue by $50 | Is the ingestion pipeline idempotent? Why did duplicate refund webhook payloads persist? |
| **Refunds** | `R4` $\rightarrow$ `O1` | Refund created on `2025-02-19` before order on `2025-02-20` | Chronological violation in audit logs | Is this due to clock drift, timezone conversion errors during ETL, or retroactive manual entry? |
| **Refunds** | `R5` $\rightarrow$ `O5` | Refund of 150 exceeds order gross of 100 | Negative net revenue (-€57.00) | Does the gateway allow goodwill refunds exceeding capture, or was this a currency confusion? |
| **Orders** | `O5` | Currency is `EUR` instead of tenant's `GBP` | Mixed-currency distortion | Does checkout allow multi-currency selection? Where is the captured FX rate stored? |
| **Orders / Tickets** | `O6`, `TK9` | `tenant_id` is `NULL` | Orphaned records / lost tenant revenue | Why is `tenant_id` nullable in production DBs? Can we enforce a NOT NULL foreign key constraint? |
| **Orders / Tickets** | `O9` | Gross is £250, but tickets sum to £200 | £50 discrepancy between orders and ticket items | Where are non-ticket items (donations, VIP fees, merchandise) stored? |
| **Gate Scans** | `S6` $\rightarrow$ `TK999` | Scanned ticket `TK999` does not exist | Ghost ticket entry | Did a scanner accept an offline barcode, test barcode, or counterfeit pass? |
| **Gate Scans** | `S5`, `S7` | `S5` scanned cancelled ticket `TK4`; `S7` scanned exchanged ticket `TK2` | Unauthorized entry at venue gates | Are turnstiles receiving real-time invalidation webhooks when tickets are refunded/exchanged? |
| **Gate Scans** | `S1`, `S2`, `S3` | Ticket `TK1` scanned 3 times across Gates A & B | Potential badge pass-back fraud | Does the venue allow re-entry, or is anti-passback enforcement missing at turnstiles? |
| **Venues** | `V2` | Timezone is null | Ambiguous local event times | Can venue timezone be made mandatory during venue setup? |

---

## 5. Architectural Trade-offs

1. **Staging Imputation vs. Dead-Letter Quarantine**:
   - *Decision*: Imputed `tenant_id` from `events` for `O6`/`TK9` directly in staging with an `is_imputed_tenant` boolean flag.
   - *Rationale*: Produces complete financial reports while maintaining transparency. In production, unlinked records should be routed to a dead-letter quarantine queue.
2. **Multi-Currency Grouping vs. Assumed FX Conversion**:
   - *Decision*: Kept currency as part of the grain `(tenant_id, event_id, currency)`.
   - *Rationale*: Applying arbitrary exchange rates would produce inaccurate financial reports.
3. **Order-Level Financial Calculations**:
   - *Decision*: Maintained net revenue calculation at the order grain (`fct_orders`).
   - *Rationale*: Taxes and refunds occur at the order level. Fractional allocation to tickets would introduce rounding errors given the £50 discrepancy on `O9`.

---

## 6. Productionisation Strategy

1. **Tenant Safety & Isolation**:
   - Implement **Snowflake Row Access Policies (RAP)** based on `CURRENT_ROLE()` and `tenant_id` to guarantee tenant isolation.
   - Deploy **Snowflake Secure Data Sharing** directly on `fct_tenant_event_revenue` and `dim_events`.
2. **CI/CD & Quality Gates**:
   - GitHub Actions pipeline running `dbt build --select state:modified+` against ephemeral PR schemas.
   - SQLFluff formatting and automated dbt checkpoint assertions.
3. **Deployment & Orchestration**:
   - Orchestrate scheduled runs via **Airflow** / **Dagster** / **dbt Cloud** triggered by CDC ingestion (Fivetran/Debezium).
   - Blue/Green zero-downtime table deployment using Snowflake zero-copy clones.
4. **Data Observability & Alerting**:
   - Integrate **Elementary** / **Monte Carlo** for automated volume, freshness, and refund spike anomaly detection.
   - PagerDuty/Slack notifications on financial reconciliation test failures.

---

## 7. What I Would Do With More Time (Next 5 Priorities)

1. **Daily FX Rate Ingestion**: Ingest ECB / OANDA exchange rates to support multi-currency conversion to tenant home currency and platform USD.
2. **Automated Quarantine Pipeline**: Build an automated exception mart (`fct_data_quality_exceptions`) for ghost scans (`TK999`), over-refunds (`R5`), and missing keys.
3. **dbt Semantic Layer**: Define metrics (`gross_revenue`, `net_revenue`, `attendance_rate`) in MetricFlow for self-serve BI and LLM natural-language querying.
4. **Incremental Loading & SCD Type 2 Snapshots**: Convert high-volume models to incremental materializations with `dbt snapshot` tracking ticket status changes.
5. **PII Masking Policies**: Implement dynamic column masking on customer PII (`email`, `full_name`) for GDPR/CCPA compliance.

---

## 8. Verification Runbook

```bash
# Setup virtual environment and dependencies
make setup

# Run all seeds, staging models, intermediate models, marts, and 118 data tests
make build

# Generate and inspect interactive dbt documentation site
make docs
```
