# Raw Data Entity-Relationship Diagram (ERD)

This document diagrams the raw tables landed in `/seeds` and describes their schema, relationships, and raw data anomalies.

---

## Entity-Relationship Diagram

```mermaid
erDiagram
    RAW_TENANTS ||--o{ RAW_VENUES : "owns / manages"
    RAW_TENANTS ||--o{ RAW_EVENTS : "hosts"
    RAW_TENANTS ||--o{ RAW_CUSTOMERS : "has"
    RAW_TENANTS ||--o{ RAW_ORDERS : "receives (nullable in O6)"
    RAW_TENANTS ||--o{ RAW_TICKETS : "issues (nullable in TK9)"
    RAW_TENANTS ||--o{ RAW_REFUNDS : "processes"
    RAW_TENANTS ||--o{ RAW_SCANS : "records at venue"

    RAW_VENUES ||--o{ RAW_EVENTS : "located at"

    RAW_EVENTS ||--o{ RAW_ORDERS : "purchased for"
    RAW_EVENTS ||--o{ RAW_TICKETS : "admission for"

    RAW_CUSTOMERS ||--o{ RAW_ORDERS : "places"

    RAW_ORDERS ||--o{ RAW_TICKETS : "contains line items"
    RAW_ORDERS ||--o{ RAW_REFUNDS : "refunded against"

    RAW_TICKETS ||--o{ RAW_SCANS : "scanned at gate"

    RAW_TENANTS {
        string tenant_id PK "T1, T2"
        string tenant_name "Apollo Arena, Beacon Festivals"
        timestamp created_at_utc "Tenant onboarding timestamp"
    }

    RAW_VENUES {
        string venue_id PK "V1, V2, V3"
        string tenant_id FK "References RAW_TENANTS"
        string venue_name "Apollo Main Hall, Apollo Annex, Beacon Park"
        string city "New York, London"
        string timezone "America/New_York, Europe/London (null in V2)"
        int capacity "200, 100, 500"
    }

    RAW_EVENTS {
        string event_id PK "E1, E2, E3, E4"
        string tenant_id FK "References RAW_TENANTS"
        string venue_id FK "References RAW_VENUES"
        string event_name "Spring Opening Night, Acoustic Evening, etc."
        timestamp event_start_utc "Event start time"
    }

    RAW_CUSTOMERS {
        string customer_id PK "C1, C2, C3, C4, C5 (scoped per tenant)"
        string tenant_id FK "References RAW_TENANTS"
        string email "Customer email address"
        string full_name "Customer display name"
        string country "US, GB"
        timestamp created_at_utc "Customer signup timestamp"
    }

    RAW_ORDERS {
        string order_id PK "O1, O2, ... O10"
        string tenant_id FK "References RAW_TENANTS (NULL in O6)"
        string customer_id FK "References RAW_CUSTOMERS"
        string event_id FK "References RAW_EVENTS"
        string order_status "completed, cancelled, pending"
        decimal gross_amount "Total order charge"
        decimal fee_amount "Platform fee (Ticketure revenue)"
        decimal tax_amount "Taxes collected"
        string currency "USD, GBP, EUR (EUR mismatch in O5)"
        timestamp created_at_utc "Order placement timestamp"
    }

    RAW_TICKETS {
        string ticket_id PK "TK1, TK2, ... TK15"
        string order_id FK "References RAW_ORDERS"
        string tenant_id FK "References RAW_TENANTS (NULL in TK9)"
        string event_id FK "References RAW_EVENTS"
        string ticket_status "valid, cancelled, exchanged, comp"
        decimal price "Ticket unit price"
    }

    RAW_REFUNDS {
        string refund_id PK "R1, R2, ... R5 (R1 duplicated in raw)"
        string order_id FK "References RAW_ORDERS"
        string tenant_id FK "References RAW_TENANTS"
        decimal refund_amount "Refund amount (R5 > O5 gross)"
        string refund_status "completed, failed (R3 failed)"
        timestamp created_at_utc "Refund timestamp (R4 precedes O1)"
    }

    RAW_SCANS {
        string scan_id PK "S1, S2, ... S11"
        string ticket_id FK "References RAW_TICKETS (TK999 ghost ticket)"
        string tenant_id FK "References RAW_TENANTS"
        timestamp scanned_at_utc "Turnstile scan timestamp"
        string gate "A, B, Main"
    }
```

---

## Key Data Anomalies Noted in Raw Seeds

1. **`raw_refunds`**:
   - `R1`: Exact duplicate row present in raw CSV.
   - `R4`: Timestamp `2025-02-19 08:00:00` precedes the order `O1` timestamp `2025-02-20 11:00:00`.
   - `R5`: Refund amount (`150.00`) exceeds the gross order amount of `O5` (`100.00`).
   - `R3`: Status is `failed` and must not reduce net revenue.

2. **`raw_orders`**:
   - `O6`: `tenant_id` is `NULL` (inferred from Event `E3` $\rightarrow$ `T2`).
   - `O5`: Currency is `EUR` whereas Tenant `T2` home currency is `GBP`.
   - `O3` (`cancelled`) and `O7` (`pending`): Non-completed orders excluded from net revenue.
   - `O9`: Gross amount is `250.00`, but its 2 tickets (`TK13`, `TK14`) sum to `200.00` ($50 gap).

3. **`raw_tickets`**:
   - `TK9`: `tenant_id` is `NULL` (inferred from Event `E3` $\rightarrow$ `T2`).
   - `TK2`: Status `exchanged`.
   - `TK4`: Status `cancelled` (from cancelled order `O3`).
   - `TK11`, `TK12`: Status `comp` with price `0.00`.

4. **`raw_scans`**:
   - `S6`: Scans `TK999` which does not exist in `raw_tickets` (ghost/unregistered ticket).
   - `S5`: Scans `TK4` (cancelled ticket).
   - `S7`: Scans `TK2` (exchanged ticket).
   - `TK1`: Scanned 3 times across Gates A and B (`S1`, `S2`, `S3`).

5. **`raw_venues`**:
   - `V2`: `timezone` is empty/null (inferred as `America/New_York` based on `city = 'New York'`).
