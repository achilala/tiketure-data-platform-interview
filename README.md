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
make lint     # run sqlfluff linter
make format   # auto-format SQL models with sqlfluff
```

---

# Your submission

## What I built

I structured the project into a classical layered dbt architecture: **Staging (`models/staging/`)** $\rightarrow$ **Intermediate (`models/intermediate/`)** $\rightarrow$ **Marts (`models/marts/`)**.

### 1. Staging Layer (`models/staging/` — views)
*Strict 1:1 mapping with raw source tables, without multi-table joins:*
- `stg_tenants` — **Grain: 1 row per tenant (`tenant_id`)**. Cleans tenant names, standardizes timestamps, and defines `home_currency` (DRY).
- `stg_venues` — **Grain: 1 row per venue (`venue_id`)**. Imputes missing timezone based on venue city (`America/New_York` for New York).
- `stg_events` — **Grain: 1 row per event (`event_id`)**. Casts event start timestamps and trims event names.
- `stg_customers` — **Grain: 1 row per customer record (`tenant_id`, `customer_id`)**. Normalizes emails (lowercase) and country codes.
- `stg_orders` — **Grain: 1 row per order (`order_id`)**. Casts monetary columns to `numeric(10,2)`; preserves raw nullable `tenant_id`.
- `stg_tickets` — **Grain: 1 row per ticket (`ticket_id`)**. Casts price; preserves raw nullable `tenant_id`.
- `stg_refunds` — **Grain: 1 row per refund (`refund_id`)**. Strictly deduplicates duplicate records (`R1`) using `QUALIFY row_number() = 1`.
- `stg_scans` — **Grain: 1 row per gate scan (`scan_id`)**. Standardizes scan timestamps and gate identifiers.

### 2. Intermediate Layer (`models/intermediate/` — views)
*Encapsulates multi-table joins, business imputation, metric calculation, and anomaly detection:*
- `int_order_refunds_summary` — **Grain: 1 row per order (`order_id`)**. Aggregates completed vs. failed refund amounts and counts (`group by all`).
- `int_orders_enriched` — **Grain: 1 row per order (`order_id`)**. Joins orders with events, tenants, and refund summaries; imputes missing `tenant_id`; calculates `net_revenue_amount` via `calculate_net_revenue` macro; flags operational anomalies (`is_currency_mismatch`, `is_over_refunded`, `is_refund_before_order`, `is_imputed_tenant`).
- `int_ticket_scans_summary` — **Grain: 1 row per ticket (`ticket_id`)**. Aggregates total scan count, earliest/latest scan times, and multi-scan detection (`group by all`).
- `int_tickets_enriched` — **Grain: 1 row per ticket (`ticket_id`)**. Joins tickets with order status and scan activity; resolves `tenant_id`; computes verified attendance (`is_attended`) and invalid scan flags (`is_invalid_scan`).

### 3. Marts Layer (`models/marts/` — tables)
#### Dimensions
- `dim_tenants` — **Grain: 1 row per tenant (`tenant_id`)**. Core tenant metadata and official settlement currency.
- `dim_venues` — **Grain: 1 row per venue (`venue_id`)**. Venue location, capacity, and timezone.
- `dim_events` — **Grain: 1 row per event (`event_id`)**. Event metadata denormalized with venue capacity and timezone.
- `dim_customers` — **Grain: 1 row per tenant customer (`customer_surrogate_key` = `tenant_id || '_' || customer_id`)**. Master Data Management (MDM) dimension resolving canonical customer IDs and identifying intra-tenant duplicate emails.

#### Facts & Aggregations
- `fct_orders` — **Grain: 1 row per order (`order_id`)**. Complete financial transaction fact table containing gross, fees, tax, completed refunds, net revenue, and audit flags.
- `fct_tickets` — **Grain: 1 row per ticket (`ticket_id`)**. Ticket-level inventory, pricing, order status, scan counts, and attendance status.
- `fct_gate_scans` — **Grain: 1 row per scan event (`scan_id`)**. Access control fact table validating ticket validity (identifies unknown barcodes like `TK999` and scans on cancelled/exchanged tickets).
- `fct_tenant_event_revenue` — **Grain: 1 row per `tenant_id`, `event_id`, and `currency`**. The primary reporting mart answering the core business question (`group by all`). Aggregates gross revenue, platform fees, taxes, completed refunds, net revenue, ticket volume, scans, and attendance with data quality alert flags.

---

## Assumptions

1. **Metric Definition & Eligibility**:
   - $\text{Net Revenue} = \text{gross\_amount} - \text{tax\_amount} - \text{completed\_refunds}$.
   - Platform fees (`fee_amount`) are Ticketure platform revenue, not tenant revenue, and are strictly excluded from tenant net revenue.
   - Only `completed` orders generate gross revenue and tax. `cancelled` (`O3`) and `pending` (`O7`) orders contribute `$0.00`.
   - Only `completed` refunds reduce net revenue. `failed` refunds (`R3`) are ignored.
2. **Refund Deduplication**:
   - Raw refund `R1` appears twice in `raw_refunds.csv`. We assume this is an ingestion/replay duplicate and deduplicate by `refund_id` in staging using `QUALIFY`.
3. **Tenant Imputation**:
   - Order `O6` and Ticket `TK9` arrived with `tenant_id = NULL`. Because they reference Event `E3` (which is exclusively owned by Tenant `T2`), we imputed `tenant_id = 'T2'` in intermediate models to prevent revenue leakage, while maintaining an `is_imputed_tenant` audit flag.
4. **Currency Handling (DRY Single Source of Truth)**:
   - `home_currency` is defined once in `stg_tenants` (T1 = `USD`, T2 = `GBP`) and reused downstream. Order `O5` was transacted in `EUR`. Because no exchange rate table was provided, revenue is grouped and reported by `(tenant_id, event_id, currency)` rather than converted using guessed FX rates.
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
| **Duplicate Customer** | `raw_customers` (`C1`, `C5`) | Two customer accounts under `T1` with same email `alice@example.com` | Why are duplicate accounts created on same email? Is there identity deduplication at signup? |
| **Ticket Sum Mismatch** | `raw_orders` (`O9`), `raw_tickets` (`TK13`, `TK14`) | Order gross is £250, but 2 tickets sum to £200 | Where is the £50 difference stored (e.g. VIP fee, donation, merchandise)? |
| **Ghost Ticket Scan** | `raw_scans` (`S6`) | Scan `S6` references `TK999`, which does not exist in `raw_tickets` | Did a scanner scan an offline barcode, test ticket, or counterfeit pass? |
| **Invalid Access Scans** | `raw_scans` (`S5`, `S7`) | `S5` scanned cancelled ticket `TK4`; `S7` scanned exchanged ticket `TK2` | Are gate scanners receiving real-time ticket cancellation webhooks? |
| **Multiple Gate Scans** | `raw_scans` (`S1`, `S2`, `S3`) | Ticket `TK1` scanned 3 times at Gates A & B | Is re-entry permitted, or does the access control system lack anti-passback rules? |
| **Missing Timezone** | `raw_venues` (`V2`) | Venue `V2` (Apollo Annex) has null `timezone` | Can venue timezone be made mandatory during venue setup? |

---

## Trade-offs

1. **Intermediate Imputation vs. Quarantine Queues**: Imputed `tenant_id` from `events` for `O6`/`TK9` in intermediate models to produce complete financial marts, adding boolean audit flags (`is_imputed_tenant`). In a large production setup, unlinked records should be routed to a dead-letter quarantine queue.
2. **Multi-Currency Reporting vs. Synthetic Conversion**: Reported separate rows per `(tenant_id, event_id, currency)` rather than applying assumed exchange rates. This preserves financial auditability.
3. **Order-Level Financial Grain**: Kept revenue, tax, and refund calculations at the order grain (`fct_orders`) rather than allocating refunds fractionally to tickets (`fct_tickets`), avoiding rounding errors and ambiguity from missing ticket line items on `O9`.
4. **DuckDB Local Warehouse**: Materialized models as views/tables locally in DuckDB for instant execution and testability within the time limit.

---

## How I would productionise this

To transition this proof-of-concept into a mission-critical, enterprise-grade Snowflake data platform, I would implement the following architecture:

### 1. Data Contracts & Upstream Ingestion Integrity
- **dbt Model Contracts**: Enforce model contracts (`contract: { enforced: true }`) on public marts and staging layers with strict data types, non-null constraints, and accepted values.
- **Upstream Schema Contracts & Schema Registry**: Implement JSON Schema / Protobuf event contracts in Kafka / AWS EventBridge for upstream application services (orders, scans, refunds) to prevent breaking schema changes from being deployed silently.
- **Enforced Non-Null Foreign Keys**: Require upstream operational databases to enforce `tenant_id NOT NULL` at the database schema level.
- **Dead-Letter Queue (DLQ) & Quarantine Pipeline**: Automatically divert contract-violating records (e.g. ghost ticket scans `TK999`, duplicate refund IDs, or refunds exceeding gross order value) into a quarantine schema (`quarantine.fct_data_quality_exceptions`) with automated alerting to operational teams.

### 2. Service Level Agreements (SLAs) & Service Level Objectives (SLOs)
Define clear, measurable SLOs and error budgets across all data products:
- **Freshness SLO**:
  - Operational raw ingestion (CDC): $P_{95} < 5\text{ minutes}$.
  - Curated Marts (`fct_orders`, `fct_tenant_event_revenue`): Refreshed hourly ($P_{99} < 60\text{ minutes}$ from transaction capture).
  - Gate Scans: Micro-batched every 5 minutes during active live events ($< 5\text{ min}$ latency).
- **Availability / Uptime SLO**: 99.9% uptime for tenant reporting marts, BI dashboards, and Snowflake Data Shares.
- **Data Quality & Reconciliation SLO**:
  - **100% Reconciliation Accuracy**: Zero financial divergence on general ledger reconciliation tests (`assert_t1_net_revenue_reconciles`, `assert_order_financial_balance`) before exposing data to tenant shares.
  - **Zero Orphaned Fact Records**: 0% dangling foreign keys in production marts.
- **Error Budgets & Escalation**:
  - PagerDuty incident automatically triggered if mart freshness exceeds 15 minutes or any financial reconciliation test fails during deployment.

### 3. Tenant Safety & Multi-Tenant Data Isolation (Snowflake)
- **Snowflake Row Access Policies (RAP)**: Attach dynamic row-level security policies to all marts:
  ```sql
  CREATE OR REPLACE ROW ACCESS POLICY tenant_isolation_policy AS (tenant_id VARCHAR) RETURNS BOOLEAN ->
      CURRENT_ROLE() = 'DATA_ADMIN' OR tenant_id = CURRENT_ROLE_TENANT_ID();
  ```
- **Snowflake Secure Data Sharing**: Create secure views for tenant-facing data shares. Tenant A can query live curated marts via Snowflake Data Sharing without seeing Tenant B's data or platform fee margins.
- **PII Data Masking**: Dynamic column masking policies on customer PII (`email`, `full_name`) restricting access based on user role for GDPR/CCPA compliance.

### 4. CI/CD Pipeline & Automated Quality Gates
- **GitHub Actions Workflow**:
  - **Slim CI**: `dbt build --select state:modified+` executed against ephemeral PR schemas in Snowflake (or ephemeral DuckDB databases) using the production manifest artifact.
  - **dbt Unit Tests**: Execute all mock unit tests on PR builds to verify SQL transformation logic before testing against data.
  - **Static Code Analysis**: SQLFluff linting, yamllint, and dbt checkpoint schema validation enforced as required PR checks.
- **Zero-Downtime Deployment**: Use Snowflake zero-copy cloning to build models in a staging database and execute `ALTER TABLE ... SWAP WITH ...` (blue/green deployment) for instantaneous table swaps with zero downtime.

### 5. Orchestration & Incremental Materialization
- **Orchestration**: Managed via **Airflow**, **Dagster**, or **dbt Cloud**, triggered via webhooks upon completion of CDC micro-batches (e.g. Fivetran/Debezium).
- **Incremental Models & SCD Type 2 Snapshots**:
  - Materialize high-volume tables (`fct_orders`, `fct_tickets`, `fct_gate_scans`) incrementally with merge strategies (`unique_key`).
  - Use `dbt snapshot` (SCD Type 2) on raw order and ticket states to preserve historical audit trails of order cancellations, ticket exchanges, and refunds.

### 6. Observability, Alerting & Lineage
- **Data Observability**: Deploy **Elementary** or **Monte Carlo** for real-time monitoring of schema drift, volume anomalies, and test results.
- **Operational Dashboards**: Metaplane/Datadog dashboards tracking data pipeline runtimes, test failures, and freshness metrics against defined SLOs.

---

## What I would do with more time

1. **Automated FX Dimension & Multi-Currency Normalization**: Integrate daily exchange rates (ECB/OANDA) to support dual-reporting in both Tenant Home Currency and Platform USD.
2. **Automated Quarantine & Data Quality Marts**: Build dedicated exception marts (`fct_data_quality_anomalies`) for ghost scans (`TK999`), over-refunds (`R5`), and orphaned orders with automated alerts to venue ops.
3. **Semantic Layer & MetricFlow Setup**: Define metrics (`gross_revenue`, `net_revenue`, `attendance_rate`) in the dbt Semantic Layer for seamless BI integration (Hex/Tableau/PowerBI) and AI/LLM natural language querying.
4. **Incremental Models & SCD Type 2 Snapshots**: Convert high-volume models (`fct_orders`, `fct_gate_scans`, `fct_tickets`) to incremental materialization with `dbt snapshot` tracking order status and refund lifecycles over time.
5. **PII Masking & Role-Based Access Control (RBAC)**: Implement Snowflake column-level masking policies on customer PII (`email`, `full_name`) for GDPR/CCPA compliance.
