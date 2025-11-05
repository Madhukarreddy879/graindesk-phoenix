# Dashboard Query Optimizations

This document describes the query optimizations implemented for the Analytics Dashboard to improve performance.

## Database Indexes

The following indexes have been created to optimize dashboard queries:

### Stock-Ins Table
- `stock_ins_tenant_date_desc_index` - Composite index on (tenant_id ASC, date DESC)
  - Optimizes queries that filter by tenant and order by date descending
  - Used by: Recent transactions, stock movement data, performance comparison

- `stock_ins_tenant_farmer_index` - Composite index on (tenant_id, farmer_name)
  - Optimizes farmer activity queries
  - Used by: Top farmers widget

- `stock_ins_product_tenant_index` - Composite index on (product_id, tenant_id)
  - Optimizes product-based aggregations
  - Used by: Inventory metrics, top products, stock alerts

### Stock-Outs Table
- `stock_outs_tenant_date_desc_index` - Composite index on (tenant_id ASC, date DESC)
  - Optimizes queries that filter by tenant and order by date descending
  - Used by: Recent transactions, stock movement data, performance comparison

- `stock_outs_tenant_customer_index` - Composite index on (tenant_id, customer_name)
  - Optimizes customer activity queries
  - Used by: Top customers widget

- `stock_outs_product_tenant_index` - Composite index on (product_id, tenant_id)
  - Optimizes product-based aggregations
  - Used by: Inventory metrics, top products, stock alerts

## Query Optimizations

### 1. Inventory Metrics Query
**Before:** Multiple queries with application-level aggregation
**After:** Single query with database-level aggregation using window functions

**Improvements:**
- Reduced from 3 queries to 1 query
- All aggregations (sum, count) performed in database
- Uses SQL fragments for complex calculations
- Eliminates Elixir-level enumeration and reduction

### 2. Financial Metrics Query
**Before:** 2 separate queries for stock-ins and stock-outs
**After:** Single query using UNION ALL

**Improvements:**
- Reduced from 2 queries to 1 query
- Combined aggregation in single database operation
- Reduced network round trips

### 3. Recent Transactions Queries
**Before:** Used preload for product associations
**After:** Uses JOIN with explicit field selection

**Improvements:**
- Eliminates N+1 query problem
- Fetches only required fields (id, name) from products
- Single query instead of 1 + N queries

### 4. Stock Movement Data Query
**Before:** 2 separate queries for stock-ins and stock-outs by date
**After:** Single query using UNION ALL with combined aggregation

**Improvements:**
- Reduced from 2 queries to 1 query
- Combined date grouping in single operation
- Reduced memory usage by processing in database

### 5. Top Products Query
**Before:** Percentage calculation in Elixir after fetching data
**After:** Percentage calculation using SQL window functions

**Improvements:**
- Eliminates post-processing in Elixir
- Uses `SUM() OVER ()` window function for total calculation
- Percentage calculated in single database pass
- More accurate with NULLIF to handle division by zero

### 6. Top Farmers/Customers Queries
**Before:** Already optimized with database aggregation
**After:** Added explicit comments, no changes needed

**Improvements:**
- Already using database-level aggregation
- All calculations (sum, count, avg) in database
- Proper use of GROUP BY and ORDER BY

### 7. Stock Alerts Query
**Before:** Filter and severity calculation in Elixir
**After:** Filter and severity calculation in database using SQL CASE

**Improvements:**
- Filtering (< 50 quintals) done in WHERE clause
- Severity determination using SQL CASE expression
- Sorting done in database with ORDER BY
- Reduced data transfer from database to application

### 8. Performance Comparison Query
**Before:** 4 separate queries for current/previous periods
**After:** Single query using multiple UNION ALL operations

**Improvements:**
- Reduced from 4 queries to 1 query
- All period calculations combined in single operation
- Significant reduction in database round trips
- Better performance for date range comparisons

## Performance Benefits

### Reduced Database Round Trips
- Inventory Metrics: 3 → 1 query (66% reduction)
- Financial Metrics: 2 → 1 query (50% reduction)
- Stock Movement: 2 → 1 query (50% reduction)
- Performance Comparison: 4 → 1 query (75% reduction)

### Database-Level Aggregation
All aggregation operations (SUM, COUNT, AVG) are now performed in the database rather than in the application, which:
- Reduces memory usage in the application
- Reduces data transfer over the network
- Leverages database optimization capabilities
- Improves query execution speed

### Index Utilization
All queries now benefit from composite indexes that match the query patterns:
- Tenant filtering + date ordering
- Tenant filtering + name grouping
- Product + tenant aggregations

### Caching Strategy
All expensive queries are cached for 30 seconds using Cachex:
- Reduces database load for frequently accessed data
- Improves response time for dashboard loads
- Cache invalidation on transaction creation

## Query Execution Time Targets

Based on the requirements, all dashboard queries should complete within:
- Individual widget queries: < 500ms
- Full dashboard load: < 2 seconds (for tenants with up to 10,000 transactions)

## Testing Query Performance

To test query performance, you can use the EXPLAIN ANALYZE command in PostgreSQL:

```sql
-- Example: Test inventory metrics query
EXPLAIN ANALYZE
SELECT 
  SUM(COALESCE(si.total_in, 0) - COALESCE(so.total_out, 0)) as total_stock,
  COUNT(CASE WHEN (COALESCE(si.total_in, 0) - COALESCE(so.total_out, 0)) > 0 THEN 1 END) as product_count,
  SUM((COALESCE(si.total_in, 0) - COALESCE(so.total_out, 0)) * p.price_per_quintal) as inventory_value
FROM products p
LEFT JOIN (
  SELECT product_id, SUM(total_quintals) as total_in
  FROM stock_ins
  WHERE tenant_id = 'your-tenant-id'
  GROUP BY product_id
) si ON p.id = si.product_id
LEFT JOIN (
  SELECT product_id, SUM(total_quintals) as total_out
  FROM stock_outs
  WHERE tenant_id = 'your-tenant-id'
  GROUP BY product_id
) so ON p.id = so.product_id
WHERE p.tenant_id = 'your-tenant-id';
```

## Monitoring Recommendations

1. **Query Execution Time**: Monitor dashboard query execution times in production
2. **Cache Hit Rate**: Track Cachex hit/miss rates for dashboard metrics
3. **Index Usage**: Verify indexes are being used with EXPLAIN ANALYZE
4. **Slow Query Log**: Enable PostgreSQL slow query log for queries > 1 second

## Future Optimization Opportunities

1. **Materialized Views**: Consider materialized views for complex aggregations if data freshness requirements allow
2. **Partial Indexes**: Add partial indexes for specific query patterns if needed
3. **Query Result Pagination**: Implement pagination for large result sets
4. **Background Jobs**: Move heavy calculations to background jobs if real-time isn't required
