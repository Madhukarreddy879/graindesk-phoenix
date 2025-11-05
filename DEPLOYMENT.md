# Deployment Guide

## Production Deployment Checklist

### 1. Environment Variables

Ensure the following environment variables are set:

```bash
# Required
DATABASE_URL=ecto://user:password@host/database
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>
PHX_HOST=your-domain.com

# Optional
PORT=4000
POOL_SIZE=10
ECTO_IPV6=false

# Email configuration (if using external SMTP)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your-username
SMTP_PASSWORD=your-password
```

### 2. Database Setup

```bash
# Run migrations
mix ecto.migrate

# Seed initial data (requires SUPER_ADMIN_EMAIL and SUPER_ADMIN_PASSWORD)
SUPER_ADMIN_EMAIL="admin@example.com" \
SUPER_ADMIN_PASSWORD="your-secure-password-min-12-chars" \
mix run priv/repo/seeds.exs
```

### 3. Asset Compilation

```bash
# Install dependencies
mix deps.get --only prod

# Compile assets
mix assets.deploy

# Compile application
MIX_ENV=prod mix compile
```

### 4. Database Backup Strategy

#### Automated Backups

Set up automated PostgreSQL backups using `pg_dump`:

```bash
# Daily backup script (save as /usr/local/bin/backup-rice-mill.sh)
#!/bin/bash
BACKUP_DIR="/var/backups/rice_mill"
DATE=$(date +%Y%m%d_%H%M%S)
FILENAME="rice_mill_backup_$DATE.sql.gz"

mkdir -p $BACKUP_DIR
pg_dump $DATABASE_URL | gzip > "$BACKUP_DIR/$FILENAME"

# Keep only last 30 days of backups
find $BACKUP_DIR -name "rice_mill_backup_*.sql.gz" -mtime +30 -delete

echo "Backup completed: $FILENAME"
```

Add to crontab:
```bash
# Run daily at 2 AM
0 2 * * * /usr/local/bin/backup-rice-mill.sh
```

#### Manual Backup

```bash
# Create backup
pg_dump $DATABASE_URL > rice_mill_backup.sql

# Restore backup
psql $DATABASE_URL < rice_mill_backup.sql
```

#### Cloud Backup (AWS S3)

```bash
# Install AWS CLI
# Configure with: aws configure

# Backup to S3
pg_dump $DATABASE_URL | gzip | aws s3 cp - s3://your-bucket/backups/rice_mill_$(date +%Y%m%d).sql.gz

# Restore from S3
aws s3 cp s3://your-bucket/backups/rice_mill_20240101.sql.gz - | gunzip | psql $DATABASE_URL
```

### 5. Health Monitoring

The application provides a health check endpoint:

```bash
# Check application health
curl https://your-domain.com/health

# Expected response:
# {"status":"ok","timestamp":"2024-01-01T00:00:00Z"}
```

Configure your load balancer to use `/health` for health checks.

### 6. Security Checklist

- [ ] SECRET_KEY_BASE is at least 64 characters
- [ ] Database uses SSL connection in production
- [ ] HTTPS is enforced (use `force_ssl` in endpoint config)
- [ ] Super admin password is strong (minimum 12 characters)
- [ ] Rate limiting is enabled on authentication endpoints
- [ ] Database backups are automated and tested
- [ ] Firewall rules restrict database access
- [ ] Application logs are monitored
- [ ] Security headers are configured

### 7. Performance Tuning

#### Database Connection Pool

Adjust based on your server resources:

```bash
# For 2 CPU cores
POOL_SIZE=10

# For 4 CPU cores
POOL_SIZE=20

# For 8+ CPU cores
POOL_SIZE=40
```

#### Cachex Configuration

The dashboard uses Cachex for caching. Adjust cache size in `application.ex`:

```elixir
{Cachex, name: :dashboard_cache, limit: 1000}  # Increase for more cache
```

### 8. Monitoring and Logging

#### Application Logs

```bash
# View logs in production
tail -f /var/log/rice_mill/error.log
tail -f /var/log/rice_mill/access.log
```

#### Telemetry Events

The application emits telemetry events for:
- User creation/deletion
- Authentication attempts
- Database queries
- HTTP requests

Configure telemetry reporters in `lib/rice_mill_web/telemetry.ex`.

### 9. Scaling Considerations

#### Horizontal Scaling

When running multiple instances:

1. Use a shared database (PostgreSQL)
2. Use Redis for distributed caching (replace Cachex)
3. Configure PubSub to use Redis adapter
4. Use a load balancer (nginx, HAProxy, or cloud LB)

#### Vertical Scaling

- Increase database connection pool size
- Increase Erlang VM memory: `--erl "+hms 2048"`
- Increase max processes: `--erl "+P 1000000"`

### 10. Rollback Procedure

If deployment fails:

```bash
# 1. Rollback database migrations
mix ecto.rollback --step 1

# 2. Deploy previous version
git checkout <previous-tag>
mix deps.get --only prod
mix assets.deploy
MIX_ENV=prod mix compile

# 3. Restart application
systemctl restart rice_mill
```

### 11. Zero-Downtime Deployment

For zero-downtime deployments:

1. Use database migrations that are backward compatible
2. Deploy new version alongside old version
3. Run migrations before switching traffic
4. Use load balancer to gradually shift traffic
5. Monitor error rates during deployment

## Troubleshooting

### Database Connection Issues

```bash
# Test database connection
psql $DATABASE_URL -c "SELECT 1"

# Check connection pool
mix run -e "IO.inspect(RiceMill.Repo.config())"
```

### Memory Issues

```bash
# Check Erlang VM memory usage
:observer.start()

# Or use remote console
iex --name debug@127.0.0.1 --cookie <cookie> --remsh rice_mill@127.0.0.1
```

### Performance Issues

```bash
# Enable query logging
config :rice_mill, RiceMill.Repo, log: :debug

# Check slow queries in PostgreSQL
SELECT * FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;
```

## Support

For issues or questions:
- Check application logs
- Review health check endpoint
- Check database connectivity
- Verify environment variables are set correctly
