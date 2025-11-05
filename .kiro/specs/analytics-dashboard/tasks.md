# Implementation Plan

- [x] 1. Set up Dashboard context and database schema
  - Create Dashboard context module at `lib/rice_mill/dashboard.ex`
  - Create DashboardPreference schema at `lib/rice_mill/dashboard/dashboard_preference.ex`
  - Generate migration for dashboard_preferences table with user_id, widget_order, hidden_widgets, default_time_period fields
  - Generate migrations for performance indexes on stock_ins and stock_outs tables
  - Run migrations and verify schema
  - _Requirements: 1, 18_

- [ ] 2. Implement core Dashboard context functions
  - [x] 2.1 Implement date range calculation functions
    - Write `calculate_date_range/1` function supporting today, this_week, this_month, last_month, this_quarter, this_year
    - Write `calculate_previous_period/1` function for performance comparison
    - Write helper functions for date manipulation
    - _Requirements: 9, 12_
  
  - [x] 2.2 Implement inventory metrics query
    - Write `get_inventory_metrics/1` function to calculate total stock, product count, and inventory value
    - Query stock_ins and stock_outs grouped by product_id
    - Calculate net stock per product (stock_in - stock_out)
    - Join with products table to get current prices
    - Return aggregated metrics map
    - _Requirements: 2_
  
  - [x] 2.3 Implement financial metrics query
    - Write `get_financial_metrics/2` function accepting tenant_id and date range
    - Calculate total purchase value from stock_ins in date range
    - Calculate total sales value from stock_outs in date range
    - Calculate gross margin (sales - purchases)
    - Count stock_in and stock_out transactions
    - Return financial metrics map
    - _Requirements: 3_
  
  - [x] 2.4 Implement recent transactions queries
    - Write `get_recent_stock_ins/2` function to fetch last N stock-in records
    - Write `get_recent_stock_outs/2` function to fetch last N stock-out records
    - Preload product associations
    - Order by date and inserted_at descending
    - _Requirements: 4_
  
  - [x] 2.5 Implement stock movement data query
    - Write `get_stock_movement_data/2` function for chart data
    - Group stock_ins by date within date range
    - Group stock_outs by date within date range
    - Fill missing dates with zero values
    - Return data structure with dates, stock_in_values, stock_out_values arrays
    - _Requirements: 5_
  
  - [x] 2.6 Implement top products queries
    - Write `get_top_products/2` function for top 5 products by volume
    - Query stock_ins grouped by product_id with sum of total_quintals
    - Query stock_outs grouped by product_id with sum of total_quintals
    - Calculate percentage of total volume for each product
    - Join with products table for product names
    - Return sorted list with product name, quantity, percentage
    - _Requirements: 6_
  
  - [x] 2.7 Implement farmer activity query
    - Write `get_top_farmers/2` function for top 10 farmers
    - Group stock_ins by farmer_name within date range
    - Calculate total quantity, total amount, transaction count
    - Calculate average transaction size
    - Sort by total quantity descending
    - Return list with farmer name, metrics
    - _Requirements: 7_
  
  - [x] 2.8 Implement customer activity query
    - Write `get_top_customers/2` function for top 10 customers
    - Group stock_outs by customer_name within date range
    - Calculate total quantity, total amount, transaction count
    - Calculate average transaction size
    - Sort by total quantity descending
    - Return list with customer name, metrics
    - _Requirements: 8_
  
  - [x] 2.9 Implement stock alerts query
    - Write `get_stock_alerts/1` function to identify low stock products
    - Calculate current stock per product (stock_in - stock_out)
    - Filter products with stock < 50 quintals
    - Categorize as low_stock (1-49 quintals) or out_of_stock (0 quintals)
    - Join with products table for product details
    - Return list with product name, current stock, alert severity
    - _Requirements: 11_
  
  - [x] 2.10 Implement performance comparison query
    - Write `get_performance_comparison/2` function
    - Calculate stock_in and stock_out totals for current period
    - Calculate stock_in and stock_out totals for previous equivalent period
    - Calculate percentage change for each metric
    - Return comparison data with current, previous, and change percentages
    - _Requirements: 12_

- [x] 3. Create Dashboard LiveView module
  - [x] 3.1 Create LiveView file and basic structure
    - Create `lib/rice_mill_web/live/dashboard_live/index.ex`
    - Implement `mount/3` callback with tenant_id extraction
    - Set up initial assigns for time_period, loading state
    - Subscribe to PubSub topic for real-time updates in connected?/1 block
    - _Requirements: 1, 13_
  
  - [x] 3.2 Implement data loading function
    - Write `load_dashboard_data/1` private function
    - Call all Dashboard context functions to fetch metrics
    - Assign all data to socket (inventory_metrics, financial_metrics, etc.)
    - Handle loading state transitions
    - Add error handling for failed queries
    - _Requirements: 1, 17_
  
  - [x] 3.3 Implement time period filter handler
    - Write `handle_event("change_period", ...)` callback
    - Update time_period assign
    - Reload dashboard data with new period
    - Persist selected period to session
    - _Requirements: 9_
  
  - [x] 3.4 Implement real-time update handler
    - Write `handle_info({:transaction_created, ...})` callback
    - Reload affected dashboard metrics
    - Use assign_async for non-blocking updates
    - Add visual indicator for updated widgets
    - _Requirements: 13_
  
  - [x] 3.5 Implement export handler
    - Write `handle_event("export_dashboard", ...)` callback
    - Generate PDF report with current dashboard data
    - Include tenant info, time period, and timestamp
    - Return file download response
    - _Requirements: 15_
  
  - [x] 3.6 Implement widget customization handlers
    - Write `handle_event("reorder_widgets", ...)` for drag-and-drop
    - Write `handle_event("toggle_widget", ...)` for show/hide
    - Write `handle_event("reset_layout", ...)` for default reset
    - Save preferences to dashboard_preferences table
    - _Requirements: 18_

- [x] 4. Create Dashboard template and components
  - [x] 4.1 Create main dashboard template
    - Create `lib/rice_mill_web/live/dashboard_live/index.html.heex`
    - Add header with page title and time period filter dropdown
    - Add quick action buttons (New Stock-In, New Stock-Out, View Reports, Manage Products)
    - Create responsive grid layout with Tailwind CSS
    - Add loading skeleton placeholders
    - _Requirements: 1, 10, 17_
  
  - [x] 4.2 Create inventory summary widget component
    - Create widget displaying total stock quantity
    - Display product count
    - Display total inventory value
    - Add icon indicators for metrics
    - Style with card layout and proper spacing
    - _Requirements: 2_
  
  - [x] 4.3 Create financial metrics widget component
    - Display total purchase value
    - Display total sales value
    - Display gross margin with color coding (green if positive, red if negative)
    - Display transaction counts
    - Add currency formatting
    - _Requirements: 3_
  
  - [x] 4.4 Create recent transactions widget component
    - Add tabs for Stock-In and Stock-Out views
    - Display table with date, farmer/customer name, product, quantity
    - Format dates as relative time ("2 hours ago")
    - Make rows clickable to navigate to transaction details
    - Show empty state when no transactions
    - _Requirements: 4_
  
  - [x] 4.5 Create stock movement chart component
    - Create Chart.js line chart with dual lines
    - Plot stock-in data in green line
    - Plot stock-out data in red line
    - Add tooltips showing exact values on hover
    - Make chart responsive to container width
    - Add legend and axis labels
    - _Requirements: 5_
  
  - [x] 4.6 Create top products widget component
    - Display horizontal bar chart for top 5 products
    - Show product name, quantity, and percentage
    - Use different colors for stock-in vs stock-out bars
    - Add tabs to switch between stock-in and stock-out views
    - _Requirements: 6_
  
  - [x] 4.7 Create farmer activity widget component
    - Display table with farmer name, transaction count, total quantity, total amount, average size
    - Make farmer names clickable to filter transaction history
    - Sort by total quantity descending
    - Show top 10 farmers
    - Add empty state for no data
    - _Requirements: 7_
  
  - [x] 4.8 Create customer activity widget component
    - Display table with customer name, transaction count, total quantity, total amount, average size
    - Make customer names clickable to filter transaction history
    - Sort by total quantity descending
    - Show top 10 customers
    - Add empty state for no data
    - _Requirements: 8_
  
  - [x] 4.9 Create stock alerts widget component
    - Display list of products with low or out-of-stock status
    - Use yellow badge for low stock (< 50 quintals)
    - Use red badge for out of stock (0 quintals)
    - Show product name and current stock level
    - Display alert count badge in widget header
    - _Requirements: 11_
  
  - [x] 4.10 Create performance comparison widget component
    - Display current period metrics
    - Display previous period metrics
    - Show percentage change with up/down arrows
    - Use green for positive growth, red for negative
    - Format percentages with + or - sign
    - _Requirements: 12_

- [x] 5. Implement Chart.js integration
  - [x] 5.1 Add Chart.js dependency
    - Add chart.js to assets/package.json
    - Run npm install in assets directory
    - Import Chart.js in assets/js/app.js
    - _Requirements: 5, 6_
  
  - [x] 5.2 Create Phoenix hook for line chart
    - Create assets/js/hooks/line_chart_hook.js
    - Implement mounted() callback to initialize Chart.js
    - Implement updated() callback to update chart data
    - Handle responsive resizing
    - Export hook in app.js
    - _Requirements: 5_
  
  - [x] 5.3 Create Phoenix hook for bar chart
    - Create assets/js/hooks/bar_chart_hook.js
    - Implement mounted() callback for horizontal bar chart
    - Implement updated() callback for data updates
    - Configure chart options for horizontal orientation
    - Export hook in app.js
    - _Requirements: 6_

- [x] 6. Add router configuration
  - [x] 6.1 Add dashboard route
    - Add `/dashboard` route to router in tenant_inventory live_session
    - Map route to DashboardLive.Index
    - Update redirect logic to send operators to dashboard instead of products
    - _Requirements: 1_
  
  - [x] 6.2 Update navigation menu
    - Add "Dashboard" link to main navigation
    - Make Dashboard the first menu item
    - Highlight Dashboard link when active
    - _Requirements: 1_

- [x] 7. Implement real-time updates with PubSub
  - [x] 7.1 Add PubSub broadcasts to Inventory context
    - Update `create_stock_in/2` to broadcast transaction_created event
    - Update `create_stock_out/2` to broadcast transaction_created event
    - Broadcast to tenant-specific topic "tenant:{tenant_id}:transactions"
    - _Requirements: 13_
  
  - [x] 7.2 Add PubSub broadcasts to Products context
    - Update `create_product/2` to broadcast product_updated event
    - Update `update_product/2` to broadcast product_updated event
    - Broadcast to tenant-specific topic "tenant:{tenant_id}:products"
    - _Requirements: 13_

- [x] 8. Implement caching for performance
  - [x] 8.1 Add Cachex dependency
    - Add cachex to mix.exs dependencies
    - Run mix deps.get
    - Add Cachex to application supervision tree
    - Configure :dashboard_cache with 30-second TTL
    - _Requirements: Performance optimization_
  
  - [x] 8.2 Add caching to Dashboard context
    - Create `get_cached_metrics/3` helper function
    - Wrap expensive queries with cache lookup
    - Invalidate cache on transaction_created events
    - Add cache key namespacing by tenant_id
    - _Requirements: Performance optimization_

- [x] 9. Implement role-based permissions
  - [x] 9.1 Add authorization checks in LiveView
    - Verify user role in mount/3
    - Hide financial metrics for viewer role
    - Disable action buttons for viewer role
    - Prevent navigation to restricted pages
    - _Requirements: 16_
  
  - [x] 9.2 Add role-based widget visibility
    - Create helper function to determine widget visibility by role
    - Conditionally render widgets based on role
    - Show appropriate empty states for hidden widgets
    - _Requirements: 16_

- [x] 10. Implement responsive design
  - [x] 10.1 Add responsive grid layout
    - Use Tailwind grid classes for 3-column desktop layout
    - Switch to 2-column layout for tablet (768px-1023px)
    - Switch to 1-column stack for mobile (< 768px)
    - Test layout on different screen sizes
    - _Requirements: 14_
  
  - [x] 10.2 Optimize charts for mobile
    - Adjust chart dimensions for small screens
    - Reduce number of data points on mobile
    - Make chart legends scrollable on mobile
    - Test touch interactions
    - _Requirements: 14_
  
  - [x] 10.3 Optimize tables for mobile
    - Use card layout instead of tables on mobile
    - Stack table columns vertically
    - Ensure touch-friendly tap targets (44x44px minimum)
    - Test scrolling behavior
    - _Requirements: 14_

- [x] 11. Implement export functionality
  - [x] 11.1 Add PDF generation library
    - Research and select PDF library (PdfGenerator or similar)
    - Add dependency to mix.exs
    - Configure PDF generation settings
    - _Requirements: 15_
  
  - [x] 11.2 Create PDF export template
    - Create HTML template for PDF report
    - Include all dashboard metrics in report
    - Add tenant branding and logo
    - Format for print layout
    - _Requirements: 15_
  
  - [x] 11.3 Implement export handler
    - Generate PDF from template with current data
    - Set filename as "dashboard-report-YYYY-MM-DD.pdf"
    - Return file download response
    - Add loading indicator during generation
    - _Requirements: 15_

- [x] 12. Implement dashboard customization
  - [x] 12.1 Add drag-and-drop functionality
    - Add Sortable.js or similar library for drag-and-drop
    - Create Phoenix hook for drag-and-drop events
    - Update widget_order in dashboard_preferences on drop
    - Persist order to database
    - _Requirements: 18_
  
  - [x] 12.2 Add show/hide widget controls
    - Add toggle button to each widget header
    - Update hidden_widgets in dashboard_preferences
    - Persist visibility state to database
    - Show "Add Widget" button for hidden widgets
    - _Requirements: 18_
  
  - [x] 12.3 Add reset to default functionality
    - Add "Reset Layout" button in dashboard settings
    - Clear widget_order and hidden_widgets from preferences
    - Reload dashboard with default layout
    - Show confirmation dialog before reset
    - _Requirements: 18_

- [x] 13. Add error handling and loading states
  - [x] 13.1 Implement skeleton loaders
    - Create skeleton components for each widget type
    - Show skeletons while data is loading
    - Animate skeletons with pulse effect
    - _Requirements: 17_
  
  - [x] 13.2 Add error boundaries
    - Wrap each widget in error boundary
    - Display friendly error message on query failure
    - Add "Retry" button for failed widgets
    - Log errors for debugging
    - _Requirements: 17_
  
  - [x] 13.3 Add connection status indicator
    - Show indicator when WebSocket disconnected
    - Display reconnection attempts
    - Allow manual refresh when disconnected
    - _Requirements: 13_

- [x] 14. Optimize database queries
  - [x] 14.1 Add database indexes
    - Create index on stock_ins(tenant_id, date DESC)
    - Create index on stock_outs(tenant_id, date DESC)
    - Create index on stock_ins(tenant_id, farmer_name)
    - Create index on stock_outs(tenant_id, customer_name)
    - Create index on stock_ins(product_id, tenant_id)
    - Create index on stock_outs(product_id, tenant_id)
    - _Requirements: Performance optimization_
  
  - [x] 14.2 Optimize query performance
    - Use select to fetch only required fields
    - Aggregate in database rather than application
    - Use subqueries for complex calculations
    - Test query execution plans with EXPLAIN
    - _Requirements: Performance optimization_

- [ ]* 15. Write tests for Dashboard context
  - Write unit tests for calculate_date_range/1 function
  - Write unit tests for get_inventory_metrics/1 with various stock levels
  - Write unit tests for get_financial_metrics/2 with different date ranges
  - Write unit tests for get_stock_alerts/1 with low and out-of-stock scenarios
  - Write unit tests for get_performance_comparison/2 with growth and decline
  - Write tests for edge cases (empty data, division by zero)
  - _Requirements: Testing_

- [ ]* 16. Write tests for Dashboard LiveView
  - Write integration test for dashboard mount with different roles
  - Write test for time period filter changes
  - Write test for real-time updates when transactions created
  - Write test for widget visibility based on role
  - Write test for export functionality
  - Write test for error handling
  - _Requirements: Testing_

- [ ] 17. Update documentation
  - Update README with dashboard feature description
  - Add dashboard screenshots to documentation
  - Document dashboard customization options
  - Add troubleshooting guide for common issues
  - _Requirements: Documentation_

- [ ] 18. Deploy and monitor
  - Run database migrations in production
  - Monitor dashboard load times
  - Monitor PubSub message queue
  - Set up alerts for slow queries (> 2 seconds)
  - Verify real-time updates working in production
  - _Requirements: Deployment_
