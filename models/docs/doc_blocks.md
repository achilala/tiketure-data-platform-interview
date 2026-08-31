{% docs tenant_id %}
Unique identifier for a tenant (e.g. `T1`, `T2`). Serves as the partition key for tenant data isolation.
{% enddocs %}

{% docs event_id %}
Unique identifier for an event hosted by a tenant (e.g. `E1`, `E2`, `E3`).
{% enddocs %}

{% docs venue_id %}
Unique identifier for the physical or virtual venue hosting an event (e.g. `V1`, `V2`).
{% enddocs %}

{% docs customer_id %}
Tenant-scoped identifier for the customer placing orders or holding tickets.
{% enddocs %}

{% docs order_id %}
Unique identifier for an order transaction placed by a customer.
{% enddocs %}

{% docs ticket_id %}
Unique identifier for an admission ticket line item associated with an order.
{% enddocs %}

{% docs refund_id %}
Unique identifier for a refund transaction issued against an order.
{% enddocs %}

{% docs scan_id %}
Unique identifier for a barcode turnstile gate scan event.
{% enddocs %}

{% docs currency %}
ISO 3-letter currency code in which the transaction was processed (e.g. `USD`, `GBP`, `EUR`).
{% enddocs %}

{% docs home_currency %}
The official settlement home currency of the tenant (`USD` for T1, `GBP` for T2).
{% enddocs %}

{% docs gross_amount %}
Total gross amount charged for the order before taxes, platform fees, and refunds.
{% enddocs %}

{% docs fee_amount %}
Platform processing fee retained by Ticketure. Excluded from tenant net revenue.
{% enddocs %}

{% docs tax_amount %}
Total sales/VAT tax collected on the order.
{% enddocs %}

{% docs completed_refund_amount %}
Total monetary value of successfully completed refunds associated with the order.
{% enddocs %}

{% docs net_revenue_amount %}
Net tenant revenue, calculated as: `gross_amount - tax_amount - completed_refunds` for completed orders ($0 for non-completed).
{% enddocs %}

{% docs order_status %}
Lifecycle status of the order (`completed`, `cancelled`, `pending`). Only `completed` orders generate net revenue.
{% enddocs %}

{% docs ticket_status %}
Current validity status of the ticket (`valid`, `cancelled`, `exchanged`, `comp`).
{% enddocs %}

{% docs refund_status %}
Processing status of the refund (`completed`, `failed`). Only `completed` refunds reduce net revenue.
{% enddocs %}

{% docs created_at_utc %}
Timestamp in UTC when the record was created.
{% enddocs %}

{% docs scanned_at_utc %}
Timestamp in UTC when the ticket barcode was scanned at the venue gate.
{% enddocs %}

{% docs gate %}
Designated turnstile/entrance gate at the venue (e.g. `Gate A`, `Gate B`, `Main`).
{% enddocs %}

{% docs is_currency_mismatch %}
Boolean flag indicating whether the transaction currency differs from the tenant's home settlement currency.
{% enddocs %}

{% docs is_over_refunded %}
Data quality flag indicating whether total completed refunds exceed the order's gross amount.
{% enddocs %}

{% docs is_imputed_tenant %}
Audit flag indicating whether the tenant_id was missing in raw operational data and imputed from the associated event.
{% enddocs %}

{% docs is_attended %}
Boolean flag indicating verified attendance (ticket is valid, order is completed, and scanned at least once).
{% enddocs %}
