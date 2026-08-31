# Business Context

## Tenants

| Tenant | Name | Home currency |
|--------|------|---------------|
| T1 | Apollo Arena | USD |
| T2 | Beacon Festivals | GBP |

> All monetary amounts for a tenant are recorded in that tenant's home currency.

## Metric rules

**Net revenue**
- Net revenue = `gross_amount` − `tax_amount` − completed refunds.
- Fees (`fee_amount`) are Ticketure's revenue, not the tenant's, and are **not**
  part of tenant net revenue.
- Only `completed` orders count. Refunds count only when the refund is
  `completed`.

## Finance reconciliation

Finance closes the books independently of the data warehouse. For the period covered by this data:

- Apollo Arena (T1) net revenue = `$271.00`.
- Beacon Festivals (T2): Finance has not been able to reconcile T2.
