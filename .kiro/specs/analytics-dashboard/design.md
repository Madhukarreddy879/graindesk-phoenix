# Design Document

## Overview

The Analytics Dashboard is a comprehensive, real-time data visualization interface built using Phoenix LiveView. It serves as the primary landing page for rice mill operators, providing instant visibility into inventory levels, financial performance, transaction trends, and operational metrics. The dashboard leverages LiveView's real-time capabilities to push updates to connected clients, ensuring users always see current data without manual refresh.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Browser (Client)                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         DashboardLive (LiveView)                       │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │ │
│  │  │ Inventory│ │Financial │ │  Charts  │ │  Tables  │ │ │
│  │  │  Widget  │ │  Widget  │ │  Widget  │ │  Widget  │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↕ WebSocket
┌─────────────────────────────────────────────────────────────┐
│                   Phoenix Server (Elixir)                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         RiceMill.Dashboard Context                     │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │ │
│  │  │   Metrics    │  │  Analytics   │  │   Queries   │ │ │
│  │  │   Module     │  │   Module     │  │   Module    │ │ │
│  │  └──────────────┘  └──────────────┘  └─────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         RiceMill.Inventory Context                     │ │
│  │         RiceMill.Accounts Context                      │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL Database                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │ Products │ │StockIns  │ │StockOuts │ │DashboardPrefs│  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Component Structure

1. **LiveView Layer** (`RiceMillWeb.DashboardLive.Index`)
   - Main dashboard LiveView handling user interactions
   - Manages dashboard state and time period filters
   - Coordinates widget updates and real-time data push

2. **Context Layer** (`RiceMill.Dashboard`)
   - New context module for dashboard-specific business logic
   - Aggregates data from Inventory and Accounts contexts
   - Provides optimized queries for dashboard metrics

3. **Data Layer**
   - Leverages existing Product, StockIn, StockOut schemas
   - New DashboardPreference schema for user customization
   - Efficient database queries with proper indexing

## Components and Interfaces

### 1. Dashboard LiveView Module

**File:** `lib/rice_mill_web/live/dashboard_live/index.ex`

```elixir
defmodule RiceMillWeb.DashboardLive.Index do
  use RiceMillWeb, :live_view
  
  alias RiceMill.Dashboard
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(RiceMill.PubSub, "tenant:#{socket.assigns.current_scope.tenant_id}:transactions")
    end
    
    socket =
      socket
      |> assign(:time_period, "this_month")
      |> assign(:loading, true)
      |> load_dashboard_data()
    
    {:ok, socket}
  end
  
  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    socket =
      socket
      |> assign(:time_period, period)
      |> load_dashboard_data()
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:transaction_created, _transaction}, socket) do
    {:noreply, load_dashboard_data(socket)}
  end
  
  defp load_dashboard_data(socket) do
    tenant_id = socket.assigns.current_scope.tenant_id
    time_period = socket.assigns.time_period
    date_range = Dashboard.calculate_date_range(time_period)
    
    socket
    |> assign(:inventory_metrics, Dashboard.get_inventory_metrics(tenant_id))
    |> assign(:financial_metrics, Dashboard.get_financial_metrics(tenant_id, date_range))
    |> assign(:recent_stock_ins, Dashboard.get_recent_stock_ins(tenant_id, 10))
    |> assign(:recent_stock_outs, Dashboard.get_recent_stock_outs(tenant_id, 10))
    |> assign(:stock_movement_data, Dashboard.get_stock_movement_data(tenant_id, date_range))
    |> assign(:top_products, Dashboard.get_top_products(tenant_id, date_range))
    |> assign(:top_farmers, Dashboard.get_top_farmers(tenant_id, date_range))
    |> assign(:top_customers, Dashboard.get_top_customers(tenant_id, date_range))
    |> assign(:stock_alerts, Dashboard.get_stock_alerts(tenant_id))
    |> assign(:performance_comparison, Dashboard.get_performance_comparison(tenant_id, date_range))
    |> assign(:loading, false)
  end
end
```

### 2. Dashboard Context Module

**File:** `lib/rice_mill/dashboard.ex`

```elixir
defmodule RiceMill.Dashboard do
  @moduledoc """
  The Dashboard context for analytics and metrics.
  """
  
  import Ecto.Query
  alias RiceMill.Repo
  alias RiceMill.Inventory.{Product, StockIn, StockOut}
  
  @doc """
  Returns inventory metrics including total stock, product count, and total value.
  """
  def get_inventory_metrics(tenant_id) do
    # Query to calculate current stock levels
    stock_in_query = from s in StockIn,
      where: s.tenant_id == ^tenant_id,
      group_by: s.product_id,
      select: %{product_id: s.product_id, total_in: sum(s.total_quintals)}
    
    stock_out_query = from s in StockOut,
      where: s.tenant_id == ^tenant_id,
      group_by: s.product_id,
      select: %{product_id: s.product_id, total_out: sum(s.total_quintals)}
    
    # Calculate net stock per product
    # Join with products to get current prices
    # Return aggregated metrics
  end
  
  @doc """
  Returns financial metrics for the given date range.
  """
  def get_financial_metrics(tenant_id, {start_date, end_date}) do
    # Calculate total purchases (stock-ins)
    # Calculate total sales (stock-outs)
    # Calculate gross margin
    # Count transactions
  end
  
  @doc """
  Returns stock movement data for charting.
  """
  def get_stock_movement_data(tenant_id, {start_date, end_date}) do
    # Group stock-ins by date
    # Group stock-outs by date
    # Return data structure suitable for chart rendering
  end
  
  @doc """
  Returns top products by volume for the date range.
  """
  def get_top_products(tenant_id, {start_date, end_date}) do
    # Query top 5 products by stock-in volume
    # Query top 5 products by stock-out volume
    # Calculate percentages
  end
  
  @doc """
  Returns top farmers by purchase volume.
  """
  def get_top_farmers(tenant_id, {start_date, end_date}) do
    # Group stock-ins by farmer_name
    # Calculate total quantity and amount
    # Calculate transaction count and average
    # Return top 10
  end
  
  @doc """
  Returns top customers by sales volume.
  """
  def get_top_customers(tenant_id, {start_date, end_date}) do
    # Group stock-outs by customer_name
    # Calculate total quantity and amount
    # Calculate transaction count and average
    # Return top 10
  end
  
  @doc """
  Returns stock alerts for low and out-of-stock products.
  """
  def get_stock_alerts(tenant_id) do
    # Calculate current stock per product
    # Filter products with stock < 50 quintals
    # Categorize as low_stock or out_of_stock
  end
  
  @doc """
  Returns performance comparison between current and previous period.
  """
  def get_performance_comparison(tenant_id, {start_date, end_date}) do
    # Calculate metrics for current period
    # Calculate metrics for previous equivalent period
    # Calculate percentage changes
  end
  
  @doc """
  Calculates date range from time period string.
  """
  def calculate_date_range("today"), do: {Date.utc_today(), Date.utc_today()}
  def calculate_date_range("this_week"), do: {Date.beginning_of_week(Date.utc_today()), Date.utc_today()}
  def calculate_date_range("this_month"), do: {Date.beginning_of_month(Date.utc_today()), Date.utc_today()}
  # ... other period calculations
end
```

### 3. Dashboard Preference Schema

**File:** `lib/rice_mill/dashboard/dashboard_preference.ex`

```elixir
defmodule RiceMill.Dashboard.DashboardPreference do
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "dashboard_preferences" do
    field :user_id, :id
    field :widget_order, {:array, :string}, default: []
    field :hidden_widgets, {:array, :string}, default: []
    field :default_time_period, :string, default: "this_month"
    
    timestamps()
  end
  
  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:user_id, :widget_order, :hidden_widgets, :default_time_period])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end
end
```

### 4. Dashboard Template

**File:** `lib/rice_mill_web/live/dashboard_live/index.html.heex`

Structure:
- Header with time period filter and quick action buttons
- Grid layout with responsive columns
- Widget components for each metric section
- Loading states and error handling
- Chart components using Chart.js or similar

## Data Models

### Existing Schemas (No Changes)
- `Product` - Product information with pricing
- `StockIn` - Purchase transactions from farmers
- `StockOut` - Sales transactions to customers

### New Schema: DashboardPreference

```sql
CREATE TABLE dashboard_preferences (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  widget_order TEXT[] DEFAULT '{}',
  hidden_widgets TEXT[] DEFAULT '{}',
  default_time_period VARCHAR(50) DEFAULT 'this_month',
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(user_id)
);

CREATE INDEX dashboard_preferences_user_id_index ON dashboard_preferences(user_id);
```

### Database Indexes for Performance

Add indexes to optimize dashboard queries:

```sql
-- Index for date-based filtering on stock_ins
CREATE INDEX stock_ins_tenant_date_index ON stock_ins(tenant_id, date DESC);

-- Index for date-based filtering on stock_outs
CREATE INDEX stock_outs_tenant_date_index ON stock_outs(tenant_id, date DESC);

-- Index for farmer name filtering
CREATE INDEX stock_ins_farmer_name_index ON stock_ins(tenant_id, farmer_name);

-- Index for customer name filtering
CREATE INDEX stock_outs_customer_name_index ON stock_outs(tenant_id, customer_name);

-- Index for product-based aggregations
CREATE INDEX stock_ins_product_tenant_index ON stock_ins(product_id, tenant_id);
CREATE INDEX stock_outs_product_tenant_index ON stock_outs(product_id, tenant_id);
```

## Error Handling

### Query Timeouts
- Set query timeout to 5 seconds for dashboard queries
- Display friendly error message if timeout occurs
- Provide "Retry" button for failed queries

### Missing Data
- Display "No data available" message for empty widgets
- Show helpful hints for new tenants with no transactions
- Gracefully handle division by zero in percentage calculations

### Real-time Update Failures
- Implement exponential backoff for reconnection attempts
- Display connection status indicator
- Allow manual refresh if real-time updates fail

### Permission Errors
- Verify tenant_id matches current user's tenant
- Return empty results for unauthorized access attempts
- Log security violations for audit

## Testing Strategy

### Unit Tests

**Dashboard Context Tests** (`test/rice_mill/dashboard_test.exs`)
- Test `get_inventory_metrics/1` with various stock levels
- Test `get_financial_metrics/2` with different date ranges
- Test `calculate_date_range/1` for all period options
- Test `get_stock_alerts/1` with low and out-of-stock scenarios
- Test `get_performance_comparison/2` with growth and decline scenarios

**Query Performance Tests**
- Benchmark dashboard queries with 1000, 10000, 100000 records
- Ensure queries complete within 2 seconds
- Test index effectiveness

### Integration Tests

**LiveView Tests** (`test/rice_mill_web/live/dashboard_live_test.exs`)
- Test dashboard mount for different user roles
- Test time period filter changes
- Test real-time updates when transactions are created
- Test widget visibility based on role permissions
- Test export functionality

**End-to-End Tests**
- Test complete dashboard load flow
- Test navigation from dashboard to detail pages
- Test mobile responsive behavior
- Test concurrent user sessions

### Performance Tests
- Load test with 100 concurrent users viewing dashboard
- Measure memory usage with real-time updates
- Test database query performance under load

## UI/UX Design

### Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│  Header: Dashboard | [Time Period Filter] [Export] [Actions]│
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │  Inventory   │ │  Financial   │ │Stock Alerts  │        │
│  │   Summary    │ │   Metrics    │ │   (3)        │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐│
│  │         Stock Movement Trends (Line Chart)              ││
│  └─────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────┐ ┌──────────────────────┐         │
│  │   Top Products       │ │  Recent Transactions │         │
│  │   (Bar Chart)        │ │  [Stock-In|Stock-Out]│         │
│  └──────────────────────┘ └──────────────────────┘         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────┐ ┌──────────────────────┐         │
│  │   Top Farmers        │ │  Top Customers       │         │
│  │   (Table)            │ │  (Table)             │         │
│  └──────────────────────┘ └──────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### Color Scheme
- Primary: Blue (#3B82F6) for headers and primary actions
- Success: Green (#10B981) for positive metrics and stock-in
- Warning: Yellow (#F59E0B) for low stock alerts
- Danger: Red (#EF4444) for out-of-stock and stock-out
- Neutral: Gray (#6B7280) for secondary text

### Typography
- Headers: Font size 24px, weight 600
- Metric values: Font size 32px, weight 700
- Labels: Font size 14px, weight 500
- Body text: Font size 16px, weight 400

### Responsive Breakpoints
- Desktop: >= 1024px (3-column grid)
- Tablet: 768px - 1023px (2-column grid)
- Mobile: < 768px (1-column stack)

### Chart Library
Use **Chart.js** via Phoenix hooks for interactive charts:
- Line charts for trends
- Bar charts for comparisons
- Doughnut charts for distributions
- Responsive and touch-friendly

## Real-time Updates

### PubSub Topics
- `tenant:{tenant_id}:transactions` - Broadcast when stock-in or stock-out created
- `tenant:{tenant_id}:products` - Broadcast when products updated

### Update Strategy
1. When transaction created, broadcast event to tenant topic
2. Connected dashboard LiveViews receive event
3. LiveView reloads affected metrics only (not full page)
4. Use `assign_async` for non-blocking updates
5. Display subtle animation on updated widgets

### Broadcast Implementation

```elixir
# In Inventory context after creating stock-in
def create_stock_in(tenant_id, attrs) do
  case do_create_stock_in(tenant_id, attrs) do
    {:ok, stock_in} ->
      Phoenix.PubSub.broadcast(
        RiceMill.PubSub,
        "tenant:#{tenant_id}:transactions",
        {:transaction_created, stock_in}
      )
      {:ok, stock_in}
    error -> error
  end
end
```

## Performance Optimization

### Query Optimization
1. Use database indexes on frequently filtered columns
2. Implement query result caching with 30-second TTL
3. Use `select` to fetch only required fields
4. Aggregate in database rather than in application code

### Caching Strategy
```elixir
defp get_cached_metrics(tenant_id, cache_key, fetch_fn) do
  case Cachex.get(:dashboard_cache, "#{tenant_id}:#{cache_key}") do
    {:ok, nil} ->
      result = fetch_fn.()
      Cachex.put(:dashboard_cache, "#{tenant_id}:#{cache_key}", result, ttl: :timer.seconds(30))
      result
    {:ok, cached} ->
      cached
  end
end
```

### Lazy Loading
- Load critical widgets (inventory, financial) immediately
- Defer loading of charts and tables by 500ms
- Use skeleton loaders for better perceived performance

## Security Considerations

### Authorization
- Verify user belongs to tenant before loading dashboard
- Filter all queries by tenant_id
- Respect role-based permissions for widget visibility

### Data Privacy
- Never expose data from other tenants
- Sanitize farmer/customer names in exports
- Log dashboard access for audit trail

### Rate Limiting
- Limit dashboard refreshes to once per 5 seconds per user
- Limit export generation to 10 per hour per user
- Throttle real-time update broadcasts

## Migration Path

### Phase 1: Core Dashboard (Week 1)
- Create Dashboard context and basic queries
- Implement main LiveView with inventory and financial widgets
- Add time period filtering
- Basic responsive layout

### Phase 2: Charts and Analytics (Week 2)
- Integrate Chart.js
- Implement stock movement trends chart
- Add top products and top farmers/customers widgets
- Implement stock alerts

### Phase 3: Real-time and Polish (Week 3)
- Add PubSub integration for real-time updates
- Implement performance comparison widget
- Add export functionality
- Optimize queries and add caching

### Phase 4: Customization (Week 4)
- Implement dashboard preferences
- Add drag-and-drop widget reordering
- Add show/hide widget functionality
- Polish UI and add animations

## Dependencies

### New Dependencies to Add
```elixir
# mix.exs
defp deps do
  [
    # Existing deps...
    {:cachex, "~> 3.6"},  # For dashboard caching
    {:nimble_csv, "~> 1.2"}  # For CSV export if needed
  ]
end
```

### Frontend Dependencies
```json
// assets/package.json
{
  "dependencies": {
    "chart.js": "^4.4.0",
    "date-fns": "^2.30.0"
  }
}
```

## Deployment Considerations

### Database Migrations
- Run index creation migrations during low-traffic period
- Monitor index creation progress for large tables
- Test query performance before and after indexes

### Monitoring
- Track dashboard load times in production
- Monitor PubSub message queue depth
- Alert on slow dashboard queries (> 2 seconds)

### Rollback Plan
- Keep old landing page route available
- Feature flag for dashboard vs old landing page
- Gradual rollout to tenants (10%, 50%, 100%)
