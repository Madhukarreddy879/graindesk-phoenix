# Rice Mill Inventory Management System

A multi-tenant web application for rice mill operators in India to manage paddy inventory, track stock-in operations from farmer purchases, and generate reports.

## Features

- **Multi-tenant Architecture**: Separate data isolation for different rice mill organizations
- **Product Management**: Manage different types of paddy products with pricing
- **Stock-In Tracking**: Record incoming paddy purchases from farmers with automatic calculations
- **Inventory Reports**: View current stock levels and transaction history
- **Filtering & Search**: Filter transactions by date range and farmer name
- **Auto-calculations**: Automatic calculation of total quintals and pricing

## Technology Stack

- **Elixir** 1.15+ with **Phoenix Framework** 1.8+
- **PostgreSQL** 15 (via Docker)
- **Phoenix LiveView** for real-time UI
- **Tailwind CSS** for styling

## Quick Start

### Prerequisites

- Elixir 1.15+
- Docker and Docker Compose
- Node.js 18+

### Setup

1. **Start PostgreSQL**:
   ```bash
   docker-compose up -d
   ```

2. **Install dependencies and setup database**:
   ```bash
   mix setup
   ```

3. **Start the server**:
   ```bash
   mix phx.server
   ```

4. **Visit the application**: http://localhost:4000

### Login Credentials

**Super Admin**:
- Email: `admin@ricemill.com`
- Password: ``adminpassword123

**Tenant User** (Shri Krishna Rice Mill):
- Email: `user@shrikrishna.com`
- Password: `userpassword123`

## Detailed Setup Guide

For comprehensive setup instructions, troubleshooting, and development workflow, see **[SETUP.md](SETUP.md)**.

## Project Structure

```
rice_mill/
├── lib/
│   ├── rice_mill/          # Business logic
│   │   ├── accounts/       # User & tenant management
│   │   ├── inventory/      # Products & stock-in
│   │   └── reports.ex      # Reporting functions
│   └── rice_mill_web/      # Web interface
│       └── live/           # LiveView modules
├── priv/repo/
│   ├── migrations/         # Database migrations
│   └── seeds.exs          # Seed data
└── docker-compose.yml     # PostgreSQL setup
```

## Key Concepts

### Multi-Tenancy
The system uses a shared database with tenant isolation. All data is scoped to the authenticated user's tenant, ensuring complete data separation between organizations.

### Stock-In Calculations
When recording a stock-in entry:
- **Total Quintals** = (Number of Bags × Net Weight per Bag in kg) / 100
- **Total Price** = Total Quintals × Price per Quintal

### Product Categories
All products are locked to the "Paddy" category with "quintal" as the unit of measurement, following Indian rice mill conventions.

## Development

### Run Tests
```bash
mix test
```

### Format Code
```bash
mix format
```

### Reset Database
```bash
mix ecto.reset
```

### Access Database Shell
```bash
docker exec -it rice_mill_inventory_db psql -U postgres -d rice_mill_inventory_dev
```

## Learn More

* Phoenix Framework: https://www.phoenixframework.org/
* Phoenix Guides: https://hexdocs.pm/phoenix/overview.html
* Ecto Documentation: https://hexdocs.pm/ecto
* Elixir: https://elixir-lang.org/
