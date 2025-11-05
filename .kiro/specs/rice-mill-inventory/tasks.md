# Implementation Plan

- [x] 1. Set up Phoenix project with PostgreSQL and authentication
  - Generate new Phoenix project with Ecto and LiveView
  - Configure PostgreSQL database connection
  - Generate authentication system using `mix phx.gen.auth`
  - Set up Tailwind CSS for styling
  - Use docker for postgres
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 2. Implement multi-tenancy foundation
  - [x] 2.1 Create Tenant schema and migration
    - Create `tenants` table with id, name, slug, active fields
    - Add unique index on slug
    - _Requirements: 1.3_
  
  - [x] 2.2 Modify User schema for multi-tenancy
    - Add `tenant_id` foreign key to users table
    - Add `role` enum field (:super_admin, :tenant_user)
    - Update User schema and changeset
    - _Requirements: 1.4, 1.5_
  
  - [x] 2.3 Create tenant context plug
    - Implement plug to set tenant context from authenticated user
    - Add tenant scoping helper functions
    - Update router pipeline to include tenant context plug
    - _Requirements: 1.2, 1.3_

- [x] 3. Implement Product management
  - [x] 3.1 Create Product schema and migration
    - Create `products` table with tenant_id, name, sku, category, unit, price_per_quintal
    - Add indexes on tenant_id and unique index on (tenant_id, sku)
    - Set default values for category ("Paddy") and unit ("quintal")
    - _Requirements: 2.1, 2.2, 2.3_
  
  - [x] 3.2 Implement Product context functions
    - Create `RiceMill.Inventory` context
    - Implement list_products/1 with tenant scoping
    - Implement get_product!/2 with tenant scoping
    - Implement create_product/2 with validations
    - Implement update_product/2 with category lock
    - Implement delete_product/1
    - _Requirements: 2.1, 2.4, 2.5_
  
  - [x] 3.3 Create Product LiveView interface
    - Generate ProductLive.Index for listing products
    - Create ProductLive.FormComponent for add/edit modal
    - Implement product list table with edit and delete actions
    - Add form validations and error display
    - _Requirements: 2.1, 2.4, 2.5, 8.1, 8.2, 8.3_

- [x] 4. Implement Stock-In management
  - [x] 4.1 Create StockIn schema and migration
    - Create `stock_ins` table with all required fields
    - Add indexes on tenant_id, product_id, date, farmer_name
    - Add foreign key constraints
    - _Requirements: 3.1_
  
  - [x] 4.2 Implement StockIn context functions with calculations
    - Implement create_stock_in/2 with automatic calculations
    - Create calculate_totals/1 function for total_quintals and total_price
    - Implement list_stock_ins/2 with tenant scoping
    - Implement get_stock_in!/2 with tenant scoping
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  
  - [x] 4.3 Create StockIn LiveView interface
    - Generate StockInLive.Index for listing stock-in entries
    - Create StockInLive.FormComponent for stock-in form
    - Implement product selection dropdown
    - Add auto-fill for price_per_quintal when product is selected
    - Display calculated totals in form before submission
    - Add form validations and error display
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 8.1, 8.2, 8.3_

- [x] 5. Implement reporting features
  - [x] 5.1 Create Reports context for stock levels
    - Implement current_stock_levels/1 function with aggregation query
    - Return product details with total stock in quintals
    - _Requirements: 5.1, 5.2, 5.3_
  
  - [x] 5.2 Create stock levels report LiveView
    - Generate ReportLive.StockLevels
    - Display table with product name, SKU, and total stock
    - Style report table for readability
    - _Requirements: 5.1, 5.2, 5.3, 8.1, 8.4_
  
  - [x] 5.3 Implement transaction history with filtering
    - Add stock_in_history/2 function with date and farmer name filters
    - Implement filter logic in Reports context
    - _Requirements: 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 7.4_
  
  - [x] 5.4 Create transaction history report LiveView
    - Generate ReportLive.History
    - Display table with date, farmer details, vehicle, quantity, price
    - Add filter form for date range and farmer name
    - Implement live filtering without page reload
    - Sort transactions in reverse chronological order
    - _Requirements: 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 7.4, 8.1, 8.4_

- [x] 6. Implement navigation and layout
  - [x] 6.1 Create main navigation menu
    - Add navigation links to Products, Stock-In, and Reports sections
    - Display current user email and logout button
    - Style navigation bar with Tailwind CSS
    - _Requirements: 8.1, 8.4_
  
  - [x] 6.2 Apply consistent styling across application
    - Configure Tailwind CSS color scheme (blue, green, red, gray)
    - Style forms with labels, placeholders, and buttons
    - Style tables with striped rows and action buttons
    - Ensure responsive design for different screen sizes
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [x] 7. Add seed data and setup instructions
  - [x] 7.1 Create database seeds
    - Add seed data for super admin user
    - Add seed data for sample tenant
    - Add seed data for sample tenant user
    - Add seed data for sample products
    - _Requirements: 1.4, 1.5_
  
  - [x] 7.2 Create setup documentation
    - Document database setup steps
    - Document how to run migrations
    - Document how to seed initial data
    - Document login credentials for testing
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ]* 8. Write tests for core functionality
  - [ ]* 8.1 Write context tests
    - Test Inventory context functions (products and stock-ins)
    - Test Reports context functions
    - Test tenant scoping in all queries
    - Test calculation logic for totals
    - _Requirements: 3.2, 3.3, 3.4, 3.5, 5.2_
  
  - [ ]* 8.2 Write LiveView tests
    - Test ProductLive interactions
    - Test StockInLive interactions and auto-fill
    - Test ReportLive filtering
    - _Requirements: 4.1, 4.2, 7.1, 7.2, 7.3_
  
  - [ ]* 8.3 Write authentication and authorization tests
    - Test login flow
    - Test tenant isolation
    - Test role-based access
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
