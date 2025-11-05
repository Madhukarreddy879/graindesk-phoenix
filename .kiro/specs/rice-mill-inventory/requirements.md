# Requirements Document

## Introduction

This document specifies the requirements for a Rice Mill Inventory Management System designed for rice mill operators in India. The system focuses on stock-in operations (purchases from farmers) and provides basic product management and reporting capabilities. The system is multi-tenant with separate authentication for super admin and company tenants.

## Glossary

- **Rice Mill System**: The inventory management application for tracking paddy stock
- **Tenant**: A company or organization using the system with isolated data
- **Super Admin**: System administrator with access to manage all tenants
- **Stock-In Entry**: A record of paddy purchased from a farmer
- **Quintal**: A unit of mass equal to 100 kilograms, commonly used in India
- **Paddy**: Unmilled rice grain with husk intact
- **SKU**: Stock Keeping Unit, a unique identifier for a product
- **Phoenix Framework**: Elixir web framework used for building the application
- **PostgreSQL Database**: The relational database system used for data storage

## Requirements

### Requirement 1: Multi-tenant Authentication

**User Story:** As a super admin or company tenant user, I want to log in through a single authentication endpoint, so that I can access my organization's inventory data securely.

#### Acceptance Criteria

1. THE Rice Mill System SHALL provide a single login endpoint for authentication
2. WHEN a user submits valid credentials, THE Rice Mill System SHALL authenticate the user and identify their tenant context
3. THE Rice Mill System SHALL isolate data between different tenants
4. THE Rice Mill System SHALL support super admin role with cross-tenant access
5. THE Rice Mill System SHALL support company tenant role with access limited to their own data

### Requirement 2: Product Management

**User Story:** As a rice mill operator, I want to manage product information, so that I can track different types of paddy with their pricing.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow users to create new products with name, SKU code, category, unit, and price per quintal
2. THE Rice Mill System SHALL set the category field to "Paddy" by default and prevent modification to other categories
3. THE Rice Mill System SHALL set the unit field to "quintal" by default
4. WHEN a user requests to update a product, THE Rice Mill System SHALL modify the product details except the category field
5. WHEN a user requests to delete a product, THE Rice Mill System SHALL remove the product from the database

### Requirement 3: Stock-In Transaction Recording

**User Story:** As a rice mill operator, I want to record incoming paddy purchases from farmers, so that I can track inventory and farmer transactions.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow users to create stock-in entries with product ID, date, farmer name, farmer contact, vehicle number, number of bags, and net weight per bag in kilograms
2. WHEN a stock-in entry is created, THE Rice Mill System SHALL calculate total weight in quintals using the formula: (number of bags × net weight per bag in kg) / 100
3. WHEN a stock-in entry is created, THE Rice Mill System SHALL retrieve the price per quintal from the associated product
4. WHEN a stock-in entry is created, THE Rice Mill System SHALL calculate total price using the formula: total quintals × price per quintal
5. THE Rice Mill System SHALL store the calculated total quintals and total price fields in the PostgreSQL Database

### Requirement 4: Auto-fill Product Pricing

**User Story:** As a rice mill operator, I want the system to automatically fill in the price when I select a product, so that I can quickly record transactions without manual price entry.

#### Acceptance Criteria

1. WHEN a user selects a product during stock-in entry creation, THE Rice Mill System SHALL automatically populate the price per quintal field from the selected product
2. THE Rice Mill System SHALL display the auto-filled price to the user before submission

### Requirement 5: Current Stock Level Reporting

**User Story:** As a rice mill operator, I want to view current stock levels for each product, so that I can understand my inventory position.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display a report showing each product with its current stock level
2. WHEN calculating stock levels, THE Rice Mill System SHALL sum all stock-in entry quantities in quintals for each product
3. THE Rice Mill System SHALL display product name, SKU, and total quantity in quintals in the stock level report

### Requirement 6: Stock-In Transaction History

**User Story:** As a rice mill operator, I want to view the history of all stock-in transactions, so that I can review past purchases and farmer interactions.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display a transaction history report showing all stock-in entries
2. THE Rice Mill System SHALL include date, farmer name, farmer contact, vehicle number, quantity in quintals, and total price for each transaction
3. THE Rice Mill System SHALL display transactions in reverse chronological order with most recent first

### Requirement 7: Transaction History Filtering

**User Story:** As a rice mill operator, I want to filter transaction history by date or farmer name, so that I can quickly find specific transactions.

#### Acceptance Criteria

1. WHEN a user enters a date range filter, THE Rice Mill System SHALL display only transactions within that date range
2. WHEN a user enters a farmer name filter, THE Rice Mill System SHALL display only transactions matching that farmer name
3. THE Rice Mill System SHALL support applying both date and farmer name filters simultaneously
4. WHEN no filters are applied, THE Rice Mill System SHALL display all transactions

### Requirement 8: User Interface Design

**User Story:** As a warehouse operator, I want a clean and functional interface, so that I can efficiently perform my daily tasks without confusion.

#### Acceptance Criteria

1. THE Rice Mill System SHALL provide a minimal and clean user interface suitable for warehouse environments
2. THE Rice Mill System SHALL display forms with clear labels and input validation
3. THE Rice Mill System SHALL provide visual feedback for successful operations and errors
4. THE Rice Mill System SHALL ensure all text and labels are readable and appropriately sized

### Requirement 9: Technology Stack Implementation

**User Story:** As a system administrator, I want the system built with Elixir, Phoenix Framework, and PostgreSQL, so that we have a reliable and scalable platform.

#### Acceptance Criteria

1. THE Rice Mill System SHALL be implemented using the Elixir programming language
2. THE Rice Mill System SHALL use the Phoenix Framework for web application structure
3. THE Rice Mill System SHALL use PostgreSQL Database as the data storage layer
4. THE Rice Mill System SHALL follow Phoenix Framework conventions for project structure and organization
