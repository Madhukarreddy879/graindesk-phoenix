# Rice Mill Inventory Management System

A comprehensive, multi-tenant inventory management system built with Phoenix LiveView for rice mill operations.

## 🌟 Features

### Core Functionality
- **Multi-tenant Architecture**: Serve multiple rice mills from a single instance
- **User Management**: Role-based access control (Super Admin, Tenant Admin, Manager, Staff)
- **Product Management**: Track rice varieties, grades, and inventory items
- **Stock Management**: Real-time stock in/out tracking with batch management
- **Dashboard Analytics**: Real-time insights and reporting
- **Audit Logging**: Complete activity tracking for compliance
- **PDF Reports**: Generate inventory and transaction reports
- **Bulk Operations**: Import users and manage inventory at scale
- **Email Notifications**: Automated alerts and user invitations
- **Health Monitoring**: Built-in health checks and telemetry

### Technical Features
- **Real-time UI**: Built with Phoenix LiveView for instant updates
- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile
- **Modern Stack**: Elixir 1.15+, Phoenix 1.8+, PostgreSQL 15+
- **Security**: Authentication, authorization, and data isolation
- **Scalability**: Optimized for production deployment

## 🏗️ Architecture

### Technology Stack
- **Backend**: Phoenix (Elixir)
- **Frontend**: Phoenix LiveView + Tailwind CSS
- **Database**: PostgreSQL
- **Authentication**: Phoenix Auth with bcrypt
- **Real-time**: Phoenix PubSub
- **Caching**: Cachex
- **File Processing**: CSV import/export

### System Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │    │   Mobile App    │    │   API Client    │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │    Phoenix LiveView      │
                    │   (Real-time Updates)    │
                    └─────────────┬─────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │   Phoenix Application    │
                    │   (Business Logic)       │
                    └─────────────┬─────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │     PostgreSQL           │
                    │   (Data Storage)         │
                    └───────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Elixir 1.15+
- PostgreSQL 12+
- Node.js 18+
- Docker (optional)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Madhukarreddy879/graindesk-phoenix.git
   cd graindesk-phoenix
   ```

2. **Install dependencies**
   ```bash
   # Elixir dependencies
   mix local.hex --force
   mix local.rebar --force
   mix deps.get

   # Node.js dependencies
   cd assets && npm install && cd ..
   ```

3. **Configure database**
   ```bash
   # Using Docker (recommended)
   docker-compose up -d

   # Or create database manually
   mix ecto.create

   # Run migrations
   mix ecto.migrate
   ```

4. **Seed initial data**
   ```bash
   # Create super admin user
   SUPER_ADMIN_EMAIL="admin@example.com" \
   SUPER_ADMIN_PASSWORD="secure-password-123" \
   mix run priv/repo/seeds.exs
   ```

5. **Start the application**
   ```bash
   # Start Phoenix server
   mix phx.server

   # Or start with specific environment
   MIX_ENV=dev mix phx.server
   ```

6. **Access the application**
   - Open browser: `http://localhost:4000`
   - Login with super admin credentials

### Default Login Credentials

**Super Admin**:
- Email: `admin@ricemill.com`
- Password: `adminpassword123`

**Tenant User** (Shri Krishna Rice Mill):
- Email: `user@shrikrishna.com`
- Password: `userpassword123`

## 📋 User Guide

### User Roles

#### Super Admin
- Manage all tenants
- Create and manage admin users
- System-wide configuration
- View audit logs across all tenants

#### Tenant Admin
- Manage tenant settings
- Create and manage staff users
- Configure tenant-specific settings
- View tenant audit logs

#### Manager
- Manage inventory operations
- Generate reports
- View analytics
- Manage staff permissions

#### Staff
- Daily inventory operations
- Stock in/out transactions
- View assigned reports

### Core Workflows

#### 1. Tenant Setup
1. Super admin creates tenant
2. Configures tenant settings
3. Creates admin user for tenant
4. Tenant admin sets up organization

#### 2. User Management
1. Admin creates user accounts
2. Assigns appropriate roles
3. Users receive email invitations
4. Users set passwords and login

#### 3. Inventory Management
1. Add products and categories
2. Record stock in transactions
3. Process stock out requests
4. Monitor inventory levels

#### 4. Reporting
1. Generate inventory reports
2. Export transaction history
3. Analyze dashboard metrics
4. Schedule automated reports

## 🔧 Configuration

### Environment Variables

#### Required Variables
```bash
# Database
DATABASE_URL=ecto://user:password@localhost/database

# Security
SECRET_KEY_BASE=<64-character-secret>
PHX_HOST=your-domain.com

# Server
PORT=4000
POOL_SIZE=10
```

#### Optional Variables
```bash
# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# Application Settings
ECTO_IPV6=false
LOG_LEVEL=info
```

## 🏢 Deployment

### Production Deployment

#### 1. Build Application
```bash
# Install production dependencies
mix deps.get --only prod

# Compile assets
mix assets.deploy

# Compile application
MIX_ENV=prod mix compile
```

#### 2. Database Setup
```bash
# Create production database
createdb rice_mill_prod

# Run migrations
MIX_ENV=prod mix ecto.migrate

# Seed data
MIX_ENV=prod mix run priv/repo/seeds.exs
```

#### 3. Start Production Server
```bash
# Using Mix
MIX_ENV=prod mix phx.server

# Using Releases (recommended)
mix release
./_build/prod/rel/rice_mill/bin/rice_mill start
```

### Docker Deployment

#### Quick Start with Docker
```bash
# Build and run with Docker Compose
docker-compose up --build

# Or use production Dockerfile
docker build -t rice-mill .
docker run -p 4000:4000 rice-mill
```

### Cloud Deployment

#### AWS EC2
See **[EC2-DEPLOYMENT.md](EC2-DEPLOYMENT.md)** for complete EC2 deployment guide.

#### Production Checklist
- [ ] Environment variables configured
- [ ] Database SSL enabled
- [ ] HTTPS certificates installed
- [ ] Backup strategy implemented
- [ ] Monitoring configured
- [ ] Security hardening completed

## 🧪 Testing

### Running Tests

#### Unit Tests
```bash
# Run all tests
mix test

# Run specific test file
mix test test/rice_mill/accounts_test.exs

# Run with coverage
mix test --cover
```

#### Integration Tests
```bash
# Run authentication tests
mix test test/rice_mill_web/user_auth_test.exs

# Run LiveView tests
mix test test/rice_mill_web/live/user_live/login_test.exs
```

#### Performance Tests
```bash
# Run database performance tests
mix test test/rice_mill_web/live/dashboard_live_test.exs

# Check query performance
mix run priv/repo/test_query_performance.exs
```

### Test Coverage

The test suite covers:
- ✅ User authentication and authorization
- ✅ Multi-tenant functionality
- ✅ Inventory management operations
- ✅ LiveView interactions
- ✅ Database operations
- ✅ Email functionality
- ✅ CSV import/export

## 📊 Monitoring & Analytics

### Health Checks

#### Application Health
```bash
# Check application status
curl http://localhost:4000/health

# Response
{"status":"ok","timestamp":"2024-01-01T00:00:00Z"}
```

#### Database Health
```bash
# Test database connection
mix ecto.create --dry-run

# Check connection pool
mix run -e "IO.inspect(RiceMill.Repo.config())"
```

### Telemetry Events

The application emits telemetry events for:
- User authentication attempts
- Database query performance
- HTTP request metrics
- LiveView interactions
- Background job execution

## 🔒 Security

### Security Features

#### Authentication
- Password hashing with bcrypt
- Session-based authentication
- Password reset functionality
- Multi-factor authentication (optional)

#### Authorization
- Role-based access control
- Tenant data isolation
- API rate limiting
- CSRF protection

#### Data Protection
- Encrypted data transmission
- SQL injection prevention
- XSS protection
- Secure file uploads

### Security Checklist

- [ ] SECRET_KEY_BASE is at least 64 characters
- [ ] Database uses SSL in production
- [ ] HTTPS is enforced
- [ ] Strong password policies
- [ ] Rate limiting configured
- [ ] Security headers enabled
- [ ] Regular security updates
- [ ] Audit logging enabled

## 📈 Performance Optimization

### Database Optimization

#### Indexes
```sql
-- Performance indexes
CREATE INDEX idx_users_tenant_id ON users(tenant_id);
CREATE INDEX idx_products_tenant_id ON products(tenant_id);
CREATE INDEX idx_stock_ins_product_id ON stock_ins(product_id);
CREATE INDEX idx_stock_outs_product_id ON stock_outs(product_id);
```

#### Query Optimization
```elixir
# Use database indexes efficiently
from(p in Product,
  where: p.tenant_id == ^tenant_id,
  order_by: [desc: p.inserted_at],
  limit: 50
)
```

### Application Optimization

#### Caching
```elixir
# Dashboard caching
{Cachex, name: :dashboard_cache, limit: 1000}

# Cache expensive operations
Cachex.get(:dashboard_cache, key, fallback: fn -> 
  expensive_operation() 
end)
```

#### Connection Pooling
```elixir
# Optimize pool size
config :rice_mill, RiceMill.Repo,
  pool_size: 20,
  queue_target: 5000,
  queue_interval: 1000
```

## 🐛 Troubleshooting

### Common Issues

#### Database Connection
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test connection
psql -h localhost -U postgres -d rice_mill_dev
```

#### Application Startup
```bash
# Check logs
mix phx.server

# Debug mode
MIX_ENV=dev mix phx.server
```

#### Performance Issues
```bash
# Monitor memory usage
:observer.start()

# Check slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
```

### Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| 401 | Unauthorized | Check authentication |
| 403 | Forbidden | Verify user permissions |
| 404 | Not Found | Check resource exists |
| 422 | Unprocessable | Validate input data |
| 500 | Server Error | Check application logs |

## 🤝 Contributing

### Development Workflow

1. **Fork the repository**
2. **Create feature branch**
   ```bash
   git checkout -b feature/new-feature
   ```
3. **Make changes**
4. **Run tests**
   ```bash
   mix test
   mix format --check-formatted
   mix credo --strict
   ```
5. **Commit changes**
   ```bash
   git commit -m "Add new feature"
   ```
6. **Push and create PR**

### Code Standards

#### Elixir
- Follow Elixir style guide
- Use `mix format` for formatting
- Run `mix credo` for linting
- Write comprehensive tests

#### JavaScript
- Use ES6+ syntax
- Follow Airbnb style guide
- Use ESLint for linting
- Test with Jest

#### Documentation
- Document public functions
- Update README for new features
- Include examples in docs
- Maintain CHANGELOG

## 📝 Project Structure

```
rice_mill/
├── lib/
│   ├── rice_mill/          # Business logic
│   │   ├── accounts/       # User & tenant management
│   │   ├── inventory/      # Products & stock management
│   │   ├── dashboard/      # Dashboard analytics
│   │   └── reports/        # Reporting functions
│   └── rice_mill_web/      # Web interface
│       ├── components/     # UI components
│       ├── controllers/    # HTTP controllers
│       ├── live/           # LiveView modules
│       └── plugs/          # Authentication plugs
├── priv/
│   ├── repo/
│   │   ├── migrations/     # Database migrations
│   │   └── seeds.exs       # Seed data
│   └── static/            # Static assets
├── test/                  # Test files
├── assets/                # Frontend assets
├── config/                # Configuration files
├── docker-compose.yml     # PostgreSQL setup
├── DEPLOYMENT.md          # Deployment guide
├── EC2-DEPLOYMENT.md      # EC2 deployment guide
└── SETUP.md              # Detailed setup guide
```

## 📞 Support

### Getting Help

- **Documentation**: Check this README and inline docs
- **Issues**: Create GitHub issue for bugs
- **Features**: Request features via GitHub discussions
- **Security**: Report security issues privately

### Community

- **GitHub**: https://github.com/Madhukarreddy879/graindesk-phoenix
- **Discussions**: Use GitHub Discussions for questions
- **Issues**: Report bugs via GitHub Issues

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Phoenix Framework team for excellent web framework
- Elixir community for amazing language and ecosystem
- Tailwind CSS for utility-first CSS framework
- PostgreSQL for reliable database
- All contributors and users of this project

---

**Built with ❤️ using Phoenix LiveView**

## Learn More

* Phoenix Framework: https://www.phoenixframework.org/
* Phoenix Guides: https://hexdocs.pm/phoenix/overview.html
* Ecto Documentation: https://hexdocs.pm/ecto
* Elixir: https://elixir-lang.org/
