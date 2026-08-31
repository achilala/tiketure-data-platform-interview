# Data Engineering Take Home Exercise

We care about your judgement and how you communicate it far more than about volume of output.

## Time and logistics

- Please spend no more than 2 hours of focused work. If you run out of time, stop and write down what you would have done next; that note is part of what we score.
- Submit as a Git repo (preferred) or a zip.

## Using AI

Use whatever AI tooling you would normally use day to day.

## The scenario

We run a multi-tenant ticketing platform. Each tenant sells tickets to events. Raw operational data lands in our warehouse. We want trusted data products that can power:

- internal analytics,
- tenant-facing reporting,
- Snowflake data shares,
- usage-based billing, and
- natural-language / AI querying over curated data.

The direction is Snowflake + dbt, or an equivalent code-first modelling approach. For this exercise you will work locally with dbt + DuckDB.

The raw data lives in [`/seeds`](./seeds) as CSVs: tenants, venues, events, customers, orders, tickets, refunds, and gate scans. It is realistic data, which means it is messy. Part of the exercise is noticing how.

Some business context - metric rules, currencies and Finance's reconciliation figures is in [`docs/BUSINESS_CONTEXT.md`](./docs/BUSINESS_CONTEXT.md).

## Your task

Build a small, code-first project that turns this raw data into trusted, reusable models that a BI tool or a data share could sit on top of. Your models should let someone reliably answer one question:

* Net revenue per tenant and per event.

Then reconcile your net revenue to the Finance figures in [`docs/BUSINESS_CONTEXT.md`](./docs/BUSINESS_CONTEXT.md), and explain any difference.

You decide the layering, the grain of each model, the dimensions, and the
tests. We care more about why than about how much you produce.

## Deliverables

1. A runnable project. `make build` should load the data, build your models, and run your tests.
2. Your models, organised into layers, with the grain of each model stated (in `schema.yml` descriptions or comments).
3. Tests - schema and business-logic.
4. This README, completed.

---

## Quickstart

Requires Python 3.9+ and `make`.

```bash
make setup    # creates a virtualenv, installs dbt-duckdb, installs dbt packages
make build    # runs `dbt build` (seeds + models + tests)
make docs     # generate and serve the dbt docs site locally: visualises model/column descriptions, tests and lineage graphs.
```

---

# Your submission

## What I built

I structured the project into a classical layered dbt architecture: **Staging (`models/staging/`)** $\rightarrow$ **Intermediate (`models/intermediate/`)** $\rightarrow$ **Marts (`models/marts/`)**.

### 1. Staging Layer (`models/staging/` — views)
- `stg_tenants` — **Grain: 1 row per tenant (`tenant_id`)**. Cleans tenant names, standardizes timestamps.
- `stg_venues` — **Grain: 1 row per venue (`venue_id`)**. Imputes missing timezone based on venue city (`America/New_York` for New York).
- `stg_events` — **Grain: 1 row per event (`event_id`)**. Casts event start timestamps and trims event names.
- `stg_customers` — **Grain: 1 row per customer record (`tenant_id`, `customer_id`)**. Normalizes emails (lowercase) and country codes.
- `stg_orders` — **Grain: 1 row per order (`order_id`)**. Casts monetary columns to `numeric(10,2)`; imputes missing `tenant_id` from `events` (for `O6`).
- `stg_tickets` — **Grain: 1 row per ticket (`ticket_id`)**. Casts price; imputes missing `tenant_id` from `events` (for `TK9`).
- `stg_refunds` — **Grain: 1 row per refund (`refund_id`)**. Strictly deduplicates raw duplicate rows (e.g., duplicated `R1`) and casts amounts.
- `stg_scans` — **Grain: 1 row per gate scan (`scan_id`)**. Standardizes scan timestamps and gate identifiers.

### 2. Intermediate Layer (`models/intermediate/` — views)
- `int_order_refunds_summary` — **Grain: 1 row per order (`order_id`)**. Aggregates completed vs. failed refund amounts and counts.
- `int_orders_enriched` — **Grain: 1 row per order (`order_id`)**. Joins orders with events, tenants, and refund summaries; calculates order-level `net_revenue_amount`; flags operational anomalies (`is_currency_mismatch`, `is_over_refunded`, `is_refund_before_order`, `is_imputed_tenant`).
- `int_ticket_scans_summary` — **Grain: 1 row per ticket (`ticket_id`)**. Aggregates total scan count, earliest/latest scan times, and multi-scan flags.
- `int_tickets_enriched` — **Grain: 1 row per ticket (`ticket_id`)**. Joins tickets with order status and scan activity; computes attendance flags (`is_attended`) and invalid scan flags (`is_invalid_scan`).

### 3. Marts Layer (`models/marts/` — tables)
#### Dimensions
- `dim_tenants` — **Grain: 1 row per tenant (`tenant_id`)**. Core tenant metadata and official settlement currency.
- `dim_venues` — **Grain: 1 row per venue (`venue_id`)**. Venue location, capacity, and timezone.
- `dim_events` — **Grain: 1 row per event (`event_id`)**. Event metadata denormalized with venue capacity and timezone.
- `dim_customers` — **Grain: 1 row per tenant customer (`customer_surrogate_key` = `tenant_id || '_' || customer_id`)**. Tenant-scoped customer profile.

#### Facts & Aggregations
- `fct_orders` — **Grain: 1 row per order (`order_id`)**. Complete financial transaction fact table containing gross, fees, tax, completed refunds, net revenue, and audit flags.
- `fct_tickets` — **Grain: 1 row per ticket (`ticket_id`)**. Ticket-level inventory, pricing, order status, scan counts, and attendance status.
- `fct_gate_scans` — **Grain: 1 row per scan event (`scan_id`)**. Access control fact table validating ticket validity (identifies unknown barcodes like `TK999` and scans on cancelled/exchanged tickets).
- `fct_tenant_event_revenue` — **Grain: 1 row per `tenant_id`, `event_id`, and `currency`**. The primary reporting mart answering the core business question. Aggregates gross revenue, platform fees, taxes, completed refunds, net revenue, ticket volume, scans, and attendance with data quality alert flags.

---

## Assumptions

1. **Metric Definition & Eligibility**:
   - $\text{Net Revenue} = \text{gross\_amount} - \text{tax\_amount} - \text{completed\_refunds}$.
   - Platform fees (`fee_amount`) are Ticketure platform revenue, not tenant revenue, and are strictly excluded from tenant net revenue.
   - Only `completed` orders generate gross revenue and tax. `cancelled` (`O3`) and `pending` (`O7`) orders contribute `$0.00`.
   - Only `completed` refunds reduce net revenue. `failed` refunds (`R3`) are ignored.
2. **Refund Deduplication**:
   - Raw refund `R1` appears twice in `raw_refunds.csv`. We assume this is an ingestion/replay duplicate and deduplicate by `refund_id` in staging.
3. **Tenant Imputation**:
   - Order `O6` and Ticket `TK9` arrived with `tenant_id = NULL`. Because they reference Event `E3` (which is exclusively owned by Tenant `T2`), we imputed `tenant_id = 'T2'` in staging to prevent revenue leakage, while maintaining an `is_imputed_tenant` audit flag.
4. **Currency Handling**:
   - T1 settles in `USD`, T2 settles in `GBP`. Order `O5` was transacted in `EUR`. Because no exchange rate table was provided, revenue is grouped and reported by `(tenant_id, event_id, currency)` rather than converted using guessed FX rates.
5. **Refund Timestamp Anomaly (`R4`)**:
   - Refund `R4` has timestamp `2025-02-19`, which is prior to order `O1` timestamp `2025-02-20`. We assume this is an upstream clock drift or manual backdated entry, but treat it as financially valid against `O1`.

---

## Reconciliation

### Apollo Arena (T1) — Reconciled: **$271.00 USD** (Exact Match)
Our models match Finance's `$271.00` figure exactly.

#### Breakdown by Event:
| Event ID | Event Name | Currency | Completed Orders | Gross Revenue | Tax Amount | Completed Refunds | Net Revenue |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **E1** | Spring Opening Night | USD | 3 (O1, O2, O8) | $300.00 | $23.00 | $80.00 (R1 $50 + R4 $30) | **$197.00** |
| **E2** | Acoustic Evening | USD | 0 (O3 cancelled, O7 pending) | $0.00 | $0.00 | $0.00 | **$0.00** |
| **E4** | Late March Show | USD | 1 (O10) | $80.00 | $6.00 | $0.00 | **$74.00** |
| **Total T1** | | **USD** | **4** | **$380.00** | **$29.00** | **$80.00** | **$271.00** |

*Key factors*:
- Deduplicated `R1` ($50.00) so it wasn't counted twice.
- Ignored failed refund `R3` ($100.00 on O2).
- Excluded cancelled order `O3` and pending order `O7`.

---

### Beacon Festivals (T2) — Unreconciled Analysis & Requirements

Our model produces the following numbers for T2:
- **GBP (Home Currency)**: **£484.00** (Event `E3`: Gross £630.00 − Tax £46.00 − Refund £100.00 on O4).
- **EUR (Foreign Currency)**: **-€57.00** (Event `E3`: Gross €100.00 − Tax €7.00 − Refund €150.00 on O5).

#### Why Finance Cannot Reconcile T2:
1. **Multi-Currency Mismatch**: Order `O5` was charged in `EUR` (€100.00) while T2 settles in `GBP`. Summing EUR with GBP creates an un-reconcilable currency distortion.
2. **Over-Refund / Excess Refund (`R5`)**: Refund `R5` is `€150.00` against order `O5` which had a gross amount of `€100.00`. An order cannot legitimately have refunds exceeding gross charges without operational errors (goodwill payout, miskeyed amount, or currency confusion). This creates negative net revenue (-€57.00).
3. **Missing `tenant_id` (`O6`, `TK9`)**: Order `O6` (£80 gross, £6 tax) arrived without `tenant_id`. Naive grouping drops this £74.00 net revenue from T2.
4. **Order vs. Ticket Amount Gap (`O9`)**: Order `O9` gross is £250.00 (tax £18, fee £25), but tickets `TK13` (£100) and `TK14` (£100) sum to £200.00. There is an unexplained £50 discrepancy (unmodeled line item, addon, or data error).

#### What I Would Need to Trust a T2 Number:
1. **Authoritative FX Rate Service**: Daily exchange rate feed (e.g., ECB/OANDA) to convert `O5` from EUR to GBP on the order transaction date.
2. **Finance/Operations Clarification on `R5`**: Confirmation on whether `R5` was €150 or £150, and whether Ticketure or the tenant is liable for the €50 excess refund.
3. **Itemized Order Line Items**: Data model expansion for order line items (donations, VIP upgrades, merchandise) explaining the £50 gap on `O9`.

---

## Data I would question

| Issue | Table / Records | What Looks Wrong | Question for Source-System Owners |
| :--- | :--- | :--- | :--- |
| **Duplicate Records** | `raw_refunds` (`R1`) | Exact duplicate row for `R1` ($50.00) | Is the ingestion pipeline idempotent? Why are refund webhooks emitting duplicate events? |
| **Time Inversion** | `raw_refunds` (`R4`), `raw_orders` (`O1`) | Refund `R4` created on `2025-02-19`, order `O1` created on `2025-02-20` | Is this clock skew, timezone recording inconsistency, or an offline/retroactive refund entry? |
| **Refund > Gross** | `raw_refunds` (`R5`), `raw_orders` (`O5`) | Refund `R5` ($150) exceeds order `O5` gross ($100) | Does the gateway allow goodwill refunds exceeding original capture, or was currency mislabeled? |
| **Currency Mismatch** | `raw_orders` (`O5`) | Order `O5` is in `EUR`, but tenant `T2` home currency is `GBP` | Does checkout allow multi-currency selection? Where is the captured FX rate stored? |
| **Missing Foreign Key** | `raw_orders` (`O6`), `raw_tickets` (`TK9`) | `tenant_id` is `NULL` on valid orders/tickets | Why is `tenant_id` nullable in operational databases? Can we enforce a NOT NULL constraint? |
| **Ticket Sum Mismatch** | `raw_orders` (`O9`), `raw_tickets` (`TK13`, `TK14`) | Order gross is £250, but 2 tickets sum to £200 | Where is the £50 difference stored (e.g. VIP fee, donation, merchandise)? |
| **Ghost Ticket Scan** | `raw_scans` (`S6`) | Scan `S6` references `TK999`, which does not exist in `raw_tickets` | Did a scanner scan an offline barcode, test ticket, or counterfeit pass? |
| **Invalid Access Scans** | `raw_scans` (`S5`, `S7`) | `S5` scanned cancelled ticket `TK4`; `S7` scanned exchanged ticket `TK2` | Are gate scanners receiving real-time ticket cancellation webhooks? |
| **Multiple Gate Scans** | `raw_scans` (`S1`, `S2`, `S3`) | Ticket `TK1` scanned 3 times at Gates A & B | Is re-entry permitted, or does the access control system lack anti-passback rules? |
| **Missing Timezone** | `raw_venues` (`V2`) | Venue `V2` (Apollo Annex) has null `timezone` | Can venue timezone be made mandatory during venue setup? |

---

## Trade-offs

1. **Staging Imputation vs. Dead-Letter Routing**: Imputed `tenant_id` from `events` for `O6`/`TK9` directly in staging to produce complete financial marts, adding boolean audit flags (`is_imputed_tenant`). In a large production setup, unlinked records should be routed to a dead-letter quarantine table for manual triage.
2. **Multi-Currency Reporting vs. Synthetic Conversion**: Reported separate rows per `(tenant_id, event_id, currency)` rather than applying assumed exchange rates. This preserves financial auditability.
3. **Order-Level Financial Grain**: Kept revenue, tax, and refund calculations at the order grain (`fct_orders`) rather than allocating refunds fractionally to tickets (`fct_tickets`), avoiding rounding errors and ambiguity from missing ticket line items on `O9`.
4. **DuckDB Local Warehouse**: Materialized models as views/tables locally in DuckDB for instant execution and testability within the time limit.

---

## How I would productionise this

1. **Tenant Isolation & Snowflake Data Sharing**:
   - Implement **Snowflake Row Access Policies (RAP)** based on `CURRENT_ROLE()` / `tenant_id` to guarantee tenant data isolation.
   - Set up **Snowflake Secure Data Shares** directly pointing to `fct_tenant_event_revenue` and `dim_events` so tenants query their live data without pipeline replication.
2. **CI/CD & Testing Automation**:
   - GitHub Actions workflow executing `dbt build --select state:modified+` against ephemeral PR schemas.
   - Enforce SQLFluff linting, dbt checkpoint, and PR branch validation before merging to `main`.
3. **Environments & Zero-Downtime Deployment**:
   - Separate `dev`, `staging`, and `prod` databases in Snowflake using zero-copy cloning for staging test runs.
   - Blue/Green table swap strategy for zero-downtime mart refreshes.
4. **Orchestration & CDC Ingestion**:
   - Ingest transactional operational data via CDC (Debezium/Fivetran) into Snowflake Bronze raw tables.
   - Orchestrate hourly or micro-batch dbt runs using **Airflow** / **Dagster** / **dbt Cloud**.
5. **Observability & Anomaly Alerting**:
   - Deploy **Elementary** or **Monte Carlo** for data observability (volume anomalies, refund spike detection, fresh data SLOs).
   - Automated Slack/PagerDuty alerts triggered on reconciliation test failures.

---

## What I would do with more time

1. **Automated FX Dimension & Multi-Currency Normalization**: Integrate daily exchange rates (ECB/OANDA) to support dual-reporting in both Tenant Home Currency and Platform USD.
2. **Automated Quarantine & Data Quality Marts**: Build dedicated exception marts (`fct_data_quality_anomalies`) for ghost scans (`TK999`), over-refunds (`R5`), and orphaned orders with automated alerts to venue ops.
3. **Semantic Layer & MetricFlow Setup**: Define metrics (`gross_revenue`, `net_revenue`, `attendance_rate`) in the dbt Semantic Layer for seamless BI integration (Hex/Tableau/PowerBI) and AI/LLM natural language querying.
4. **Incremental Models & SCD Type 2 Snapshots**: Convert high-volume models (`fct_orders`, `fct_gate_scans`, `fct_tickets`) to incremental materialization with `dbt snapshot` tracking order status and refund lifecycles over time.
5. **PII Masking & Role-Based Access Control (RBAC)**: Implement Snowflake column-level masking policies on customer PII (`email`, `full_name`) for GDPR/CCPA compliance.
