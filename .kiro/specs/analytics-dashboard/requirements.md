# Requirements Document

## Introduction

This document specifies the requirements for an Analytics Dashboard for the Rice Mill Inventory Management System. The dashboard provides rice mill operators with real-time insights into their operations, including inventory levels, financial metrics, transaction trends, and key performance indicators. The dashboard is designed to be the primary landing page for tenant users, offering at-a-glance visibility into business health and operational efficiency.

## Glossary

- **Rice Mill System**: The inventory management application for tracking paddy stock
- **Dashboard**: A visual interface displaying key metrics, charts, and summaries of business operations
- **KPI**: Key Performance Indicator, a measurable value demonstrating operational effectiveness
- **Stock Turnover**: The rate at which inventory is sold and replaced over a period
- **Tenant**: A company or organization using the system with isolated data
- **Widget**: A self-contained dashboard component displaying specific metrics or data
- **Time Period Filter**: A date range selector allowing users to view metrics for specific timeframes
- **Real-time Data**: Information updated dynamically without page refresh
- **Phoenix LiveView**: Elixir framework component enabling real-time updates
- **Quintal**: A unit of mass equal to 100 kilograms, commonly used in India

## Requirements

### Requirement 1: Dashboard Landing Page

**User Story:** As a rice mill operator, I want to see a comprehensive dashboard when I log in, so that I can quickly understand my business status without navigating multiple pages.

#### Acceptance Criteria

1. WHEN a user with role company_admin, operator, or viewer logs in, THE Rice Mill System SHALL redirect the user to the dashboard page
2. THE Rice Mill System SHALL display the dashboard at the route `/dashboard`
3. THE Rice Mill System SHALL organize dashboard content in a responsive grid layout
4. THE Rice Mill System SHALL display dashboard widgets in priority order with most critical metrics at the top
5. THE Rice Mill System SHALL load dashboard data within 2 seconds for tenants with up to 10000 transactions

### Requirement 2: Inventory Summary Widget

**User Story:** As a rice mill operator, I want to see current inventory levels at a glance, so that I can quickly assess stock availability.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display total stock quantity across all products in quintals
2. THE Rice Mill System SHALL display the number of distinct products currently in stock
3. THE Rice Mill System SHALL display total inventory value calculated as sum of stock quantity multiplied by current product price
4. THE Rice Mill System SHALL highlight products with stock levels below 50 quintals with a warning indicator
5. THE Rice Mill System SHALL update inventory metrics in real-time when stock transactions occur

### Requirement 3: Financial Metrics Widget

**User Story:** As a rice mill operator, I want to see financial performance metrics, so that I can track revenue and profitability.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display total purchase value for the selected time period
2. THE Rice Mill System SHALL display total sales value for the selected time period
3. THE Rice Mill System SHALL calculate and display gross margin as the difference between sales value and purchase value
4. THE Rice Mill System SHALL display the number of stock-in transactions for the selected time period
5. THE Rice Mill System SHALL display the number of stock-out transactions for the selected time period

### Requirement 4: Recent Transactions Widget

**User Story:** As a rice mill operator, I want to see recent transactions, so that I can monitor daily operations and quickly access transaction details.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display the 10 most recent stock-in transactions with date, farmer name, product, and quantity
2. THE Rice Mill System SHALL display the 10 most recent stock-out transactions with date, customer name, product, and quantity
3. THE Rice Mill System SHALL provide tabs to switch between stock-in and stock-out transaction views
4. WHEN a user clicks on a transaction, THE Rice Mill System SHALL navigate to the detailed transaction view
5. THE Rice Mill System SHALL display transaction timestamps in relative format such as "2 hours ago" or "3 days ago"

### Requirement 5: Stock Movement Trends Chart

**User Story:** As a rice mill operator, I want to visualize stock movement trends over time, so that I can identify patterns and plan inventory accordingly.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display a line chart showing daily stock-in quantities for the selected time period
2. THE Rice Mill System SHALL display a line chart showing daily stock-out quantities for the selected time period
3. THE Rice Mill System SHALL overlay both stock-in and stock-out lines on the same chart for comparison
4. THE Rice Mill System SHALL use distinct colors for stock-in line in green and stock-out line in red
5. THE Rice Mill System SHALL display chart data points with tooltips showing exact values on hover

### Requirement 6: Top Products Widget

**User Story:** As a rice mill operator, I want to see which products have the highest activity, so that I can focus on key inventory items.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display the top 5 products by total stock-in quantity for the selected time period
2. THE Rice Mill System SHALL display the top 5 products by total stock-out quantity for the selected time period
3. THE Rice Mill System SHALL show product name, total quantity, and percentage of total volume for each product
4. THE Rice Mill System SHALL display products in descending order by quantity
5. THE Rice Mill System SHALL use horizontal bar charts for visual representation of product volumes

### Requirement 7: Farmer Activity Summary

**User Story:** As a rice mill operator, I want to see farmer transaction summaries, so that I can identify key suppliers and manage farmer relationships.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display the top 10 farmers by total purchase quantity for the selected time period
2. THE Rice Mill System SHALL show farmer name, number of transactions, total quantity purchased, and total amount paid
3. THE Rice Mill System SHALL calculate average transaction size for each farmer
4. WHEN a user clicks on a farmer name, THE Rice Mill System SHALL navigate to filtered transaction history for that farmer
5. THE Rice Mill System SHALL sort farmers by total purchase quantity in descending order

### Requirement 8: Customer Activity Summary

**User Story:** As a rice mill operator, I want to see customer transaction summaries, so that I can identify key buyers and manage customer relationships.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display the top 10 customers by total sales quantity for the selected time period
2. THE Rice Mill System SHALL show customer name, number of transactions, total quantity sold, and total sales amount
3. THE Rice Mill System SHALL calculate average transaction size for each customer
4. WHEN a user clicks on a customer name, THE Rice Mill System SHALL navigate to filtered transaction history for that customer
5. THE Rice Mill System SHALL sort customers by total sales quantity in descending order

### Requirement 9: Time Period Filtering

**User Story:** As a rice mill operator, I want to filter dashboard metrics by time period, so that I can analyze performance for specific date ranges.

#### Acceptance Criteria

1. THE Rice Mill System SHALL provide preset time period filters for Today, This Week, This Month, Last Month, This Quarter, and This Year
2. THE Rice Mill System SHALL provide a custom date range selector allowing users to specify start and end dates
3. WHEN a user selects a time period filter, THE Rice Mill System SHALL update all dashboard widgets to reflect the selected period
4. THE Rice Mill System SHALL persist the selected time period filter in the user session
5. THE Rice Mill System SHALL default to "This Month" time period on initial dashboard load

### Requirement 10: Quick Action Buttons

**User Story:** As a rice mill operator, I want quick access to common actions from the dashboard, so that I can efficiently perform daily tasks.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display a "New Stock-In" button that navigates to the stock-in entry form
2. THE Rice Mill System SHALL display a "New Stock-Out" button that navigates to the stock-out entry form
3. THE Rice Mill System SHALL display a "View Reports" button that navigates to the reports page
4. THE Rice Mill System SHALL display a "Manage Products" button that navigates to the products page
5. THE Rice Mill System SHALL position quick action buttons prominently at the top of the dashboard

### Requirement 11: Stock Alerts Widget

**User Story:** As a rice mill operator, I want to see inventory alerts, so that I can proactively manage stock levels and avoid stockouts.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display products with current stock below 50 quintals as low stock alerts
2. THE Rice Mill System SHALL display products with zero current stock as out of stock alerts
3. THE Rice Mill System SHALL show product name, current stock level, and alert severity for each alert
4. THE Rice Mill System SHALL use color coding with yellow for low stock and red for out of stock
5. THE Rice Mill System SHALL display the total count of active alerts with a badge indicator

### Requirement 12: Performance Comparison Widget

**User Story:** As a rice mill operator, I want to compare current period performance with previous periods, so that I can track business growth and trends.

#### Acceptance Criteria

1. THE Rice Mill System SHALL calculate total stock-in quantity for the selected period and the previous equivalent period
2. THE Rice Mill System SHALL calculate total stock-out quantity for the selected period and the previous equivalent period
3. THE Rice Mill System SHALL display percentage change between current and previous period for stock-in quantity
4. THE Rice Mill System SHALL display percentage change between current and previous period for stock-out quantity
5. THE Rice Mill System SHALL use green color for positive growth and red color for negative growth indicators

### Requirement 13: Dashboard Data Refresh

**User Story:** As a rice mill operator, I want dashboard data to update automatically, so that I always see current information without manual refresh.

#### Acceptance Criteria

1. THE Rice Mill System SHALL update dashboard metrics automatically when stock transactions are created by any user in the tenant
2. THE Rice Mill System SHALL use Phoenix LiveView to push real-time updates to connected dashboard sessions
3. THE Rice Mill System SHALL display a visual indicator when dashboard data is being refreshed
4. THE Rice Mill System SHALL complete data refresh within 1 second for typical dashboard updates
5. THE Rice Mill System SHALL maintain user-selected filters and scroll position during automatic refresh

### Requirement 14: Responsive Dashboard Layout

**User Story:** As a rice mill operator using mobile devices, I want the dashboard to work on my phone or tablet, so that I can monitor operations while moving around the facility.

#### Acceptance Criteria

1. WHEN viewport width is below 768px, THE Rice Mill System SHALL stack dashboard widgets vertically
2. WHEN viewport width is below 768px, THE Rice Mill System SHALL adjust chart dimensions for mobile viewing
3. THE Rice Mill System SHALL maintain touch-friendly button sizes with minimum 44x44 pixels on mobile devices
4. THE Rice Mill System SHALL ensure all dashboard text remains readable on small screens
5. THE Rice Mill System SHALL hide less critical widgets on mobile and provide a "Show More" option

### Requirement 15: Export Dashboard Data

**User Story:** As a rice mill operator, I want to export dashboard data, so that I can share reports with stakeholders or perform offline analysis.

#### Acceptance Criteria

1. THE Rice Mill System SHALL provide an "Export" button on the dashboard
2. WHEN a user clicks the export button, THE Rice Mill System SHALL generate a PDF report containing all dashboard metrics
3. THE Rice Mill System SHALL include the selected time period and generation timestamp in the exported report
4. THE Rice Mill System SHALL format the exported report with company branding and tenant information
5. THE Rice Mill System SHALL download the exported file with filename format "dashboard-report-YYYY-MM-DD.pdf"

### Requirement 16: Role-Based Dashboard Views

**User Story:** As a system administrator, I want different user roles to see appropriate dashboard content, so that users access relevant information for their responsibilities.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display full dashboard with all widgets for company_admin and operator roles
2. THE Rice Mill System SHALL display read-only dashboard without action buttons for viewer role
3. THE Rice Mill System SHALL hide financial metrics from viewer role users
4. THE Rice Mill System SHALL prevent viewer role users from accessing transaction detail pages from dashboard links
5. THE Rice Mill System SHALL display role-appropriate navigation options in the dashboard header

### Requirement 17: Dashboard Loading States

**User Story:** As a rice mill operator, I want clear feedback while the dashboard loads, so that I know the system is working and data is being retrieved.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display skeleton loading placeholders for each widget while data is being fetched
2. THE Rice Mill System SHALL show a loading spinner for charts while data is being processed
3. WHEN dashboard data fails to load, THE Rice Mill System SHALL display an error message with retry option
4. THE Rice Mill System SHALL load critical widgets first and defer loading of less important widgets
5. THE Rice Mill System SHALL display a progress indicator showing percentage of widgets loaded

### Requirement 18: Dashboard Customization

**User Story:** As a rice mill operator, I want to customize my dashboard layout, so that I can prioritize the information most relevant to my workflow.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow users to reorder dashboard widgets by drag and drop
2. THE Rice Mill System SHALL allow users to show or hide individual widgets based on preference
3. THE Rice Mill System SHALL persist user dashboard customization preferences in the database
4. THE Rice Mill System SHALL provide a "Reset to Default" option to restore original dashboard layout
5. THE Rice Mill System SHALL apply customization preferences only to the current user without affecting other tenant users
