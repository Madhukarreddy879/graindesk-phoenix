# Rice Mill Inventory Management System - Setup Guide

This guide will help you set up and run the Rice Mill Inventory Management System on your local machine.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Elixir** 1.15 or higher ([Installation Guide](https://elixir-lang.org/install.html))
- **Erlang/OTP** 25 or higher (usually installed with Elixir)
- **Docker** and **Docker Compose** ([Installation Guide](https://docs.docker.com/get-docker/))
- **Node.js** 18 or higher (for asset compilation)

## Technology Stack

- **Language**: Elixir 1.15+
- **Web Framework**: Phoenix 1.8+
- **Database**: PostgreSQL 15 (via Docker)
- **ORM**: Ecto 3.13+
- **UI**: Phoenix LiveView with Tailwind CSS

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd rice_mill
```

### 2. Install Dependencies

Install Elixir dependencies:

```bash
mix deps.get
```

Install Node.js dependencies for assets:

```bash
cd assets && npm install && cd ..
```

### 3. Start PostgreSQL Database

The project uses Docker for PostgreSQL. Start the database container:

```bash
docker-compose up -d
```

This will start a PostgreSQL 15 container with the following configuration:
- **Host**: localhost
- **Port**: 5432
- **Database**: rice_mill_inventory_dev
- **Username**: postgres
- **Password**: postgres

To verify the database is running:

```bash
docker ps
```

You should see a container named `rice_mill_inventory_db` running.

### 4. Create and Migrate Database

Create the database and run migrations:

```bash
mix ecto.create
mix ecto.migrate
```

### 5. Seed the Database

Populate the database with initial data:

```bash
mix run priv/repo/seeds.exs
```

This will create:
- A super admin user (configurable via environment variables)
- A sample tenant (Shri Krishna Rice Mill)
- A tenant user (company admin)
- 5 sample products (different types of paddy)
- 6 sample stock-in entries

#### Configuring Super Admin Credentials

You can customize the super admin credentials using environment variables:

```bash
SUPER_ADMIN_EMAIL="your-email@example.com" \
SUPER_ADMIN_PASSWORD="your-secure-password" \
mix run priv/repo/seeds.exs
```

**Default values:**
- `SUPER_ADMIN_EMAIL`: admin@ricemill.com
- `SUPER_ADMIN_PASSWORD`: adminpassword123

**Note:** The seed script is idempotent - it checks if data already exists before creating it, so you can run it multiple times safely.

### 6. Start the Phoenix Server

Start the development server:

```bash
mix phx.server
```

Or start it inside IEx (Interactive Elixir):

```bash
iex -S mix phx.server
```

The application will be available at: **http://localhost:4000**

## Login Credentials

### Super Admin Account
- **Email**: admin@ricemill.com (or custom value from `SUPER_ADMIN_EMAIL`)
- **Password**: adminpassword123 (or custom value from `SUPER_ADMIN_PASSWORD`)
- **Role**: Super Admin
- **Access**: Can manage all tenants, create new tenants, manage users across all tenants, and view audit logs

### Company Admin Account (Shri Krishna Rice Mill)
- **Email**: user@shrikrishna.com
- **Password**: userpassword123
- **Role**: Company Admin
- **Access**: Can manage users within their tenant, configure tenant settings, and access all inventory features

## Database Management

### Reset Database

To drop, recreate, migrate, and seed the database:

```bash
mix ecto.reset
```

### Run Migrations Only

```bash
mix ecto.migrate
```

### Rollback Last Migration

```bash
mix ecto.rollback
```

### Check Migration Status

```bash
mix ecto.migrations
```

## Docker Commands

### Stop PostgreSQL Container

```bash
docker-compose down
```

### Stop and Remove Data

```bash
docker-compose down -v
```

### View Container Logs

```bash
docker-compose logs -f postgres
```

### Access PostgreSQL Shell

```bash
docker exec -it rice_mill_inventory_db psql -U postgres -d rice_mill_inventory_dev
```

## Application Features

Once logged in, you can access the following features:

### Products Management
- Navigate to **Products** from the main menu
- Create, edit, and delete paddy products
- Each product has: name, SKU, category (locked to "Paddy"), unit (quintal), and price per quintal

### Stock-In Management
- Navigate to **Stock-In** from the main menu
- Record incoming paddy purchases from farmers
- Auto-calculation of total quintals and total price
- Auto-fill of price when selecting a product

### Reports
- **Stock Levels**: View current inventory levels for each product
- **Transaction History**: View all stock-in transactions with filtering by date range and farmer name

## Project Structure

```
rice_mill/
├── assets/              # Frontend assets (CSS, JS)
├── config/              # Application configuration
├── lib/
│   ├── rice_mill/       # Business logic contexts
│   │   ├── accounts/    # User and tenant management
│   │   ├── inventory/   # Products and stock-in management
│   │   └── reports.ex   # Reporting functions
│   └── rice_mill_web/   # Web interface
│       ├── components/  # Reusable UI components
│       ├── controllers/ # HTTP controllers
│       └── live/        # LiveView modules
├── priv/
│   └── repo/
│       ├── migrations/  # Database migrations
│       └── seeds.exs    # Seed data script
├── test/                # Test files
├── docker-compose.yml   # Docker configuration
└── mix.exs             # Project dependencies
```

## Troubleshooting

### Port 5432 Already in Use

If you have PostgreSQL already running on your machine:

1. Stop your local PostgreSQL service
2. Or change the port in `docker-compose.yml` and `config/dev.exs`

### Database Connection Error

Ensure Docker container is running:

```bash
docker ps
```

If not running, start it:

```bash
docker-compose up -d
```

### Asset Compilation Issues

If you encounter asset compilation errors:

```bash
mix assets.setup
mix assets.build
```

### Permission Denied on Docker

On Linux, you may need to run Docker commands with `sudo` or add your user to the docker group:

```bash
sudo usermod -aG docker $USER
```

Then log out and log back in.

## Running Tests

Run the test suite:

```bash
mix test
```

## Development Workflow

1. Make code changes
2. The Phoenix server will automatically recompile and reload (live reload)
3. View changes in your browser at http://localhost:4000
4. Check for compilation errors in the terminal

## Additional Commands

### Format Code

```bash
mix format
```

### Check for Unused Dependencies

```bash
mix deps.unlock --unused
```

### Interactive Elixir Shell

```bash
iex -S mix
```

Then you can interact with your application:

```elixir
# Get all tenants
RiceMill.Accounts.list_tenants()

# Get all products for a tenant
RiceMill.Inventory.list_products(tenant_id)
```

## Production Deployment

For production deployment, refer to the Phoenix deployment guides:
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Fly.io Deployment](https://fly.io/docs/elixir/getting-started/)
- [Gigalixir Deployment](https://gigalixir.readthedocs.io/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Phoenix documentation: https://hexdocs.pm/phoenix
3. Review Ecto documentation: https://hexdocs.pm/ecto

## License

[Add your license information here]
