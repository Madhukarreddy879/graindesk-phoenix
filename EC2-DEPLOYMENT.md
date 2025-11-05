# EC2 Deployment Guide - Rice Mill Inventory System

Complete guide for deploying the Rice Mill Inventory Management System on AWS EC2.

## Prerequisites

- AWS Account with EC2 access
- Domain name (optional but recommended)
- Basic knowledge of Linux and SSH
- AWS CLI installed locally (optional)

## Table of Contents

1. [EC2 Instance Setup](#ec2-instance-setup)
2. [Server Configuration](#server-configuration)
3. [Application Deployment](#application-deployment)
4. [Database Setup](#database-setup)
5. [SSL/HTTPS Configuration](#ssl-https-configuration)
6. [Process Management](#process-management)
7. [Monitoring & Maintenance](#monitoring--maintenance)
8. [Troubleshooting](#troubleshooting)

---

## EC2 Instance Setup

### 1. Launch EC2 Instance

#### Recommended Instance Type
- **Development/Testing**: t3.small (2 vCPU, 2 GB RAM)
- **Production (Small)**: t3.medium (2 vCPU, 4 GB RAM)
- **Production (Medium)**: t3.large (2 vCPU, 8 GB RAM)
- **Production (Large)**: t3.xlarge (4 vCPU, 16 GB RAM)

#### Instance Configuration

1. **Choose AMI**: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
2. **Instance Type**: Select based on your needs (t3.medium recommended)
3. **Configure Instance**:
   - Network: Default VPC or custom VPC
   - Auto-assign Public IP: Enable
4. **Add Storage**: 
   - Root volume: 30 GB (minimum)
   - Add additional EBS volume for database: 50-100 GB (recommended)
5. **Add Tags**:
   - Name: rice-mill-production
   - Environment: production
6. **Configure Security Group**:
   ```
   Type            Protocol    Port Range    Source
   SSH             TCP         22            Your IP/0.0.0.0/0
   HTTP            TCP         80            0.0.0.0/0
   HTTPS           TCP         443           0.0.0.0/0
   Custom TCP      TCP         4000          0.0.0.0/0 (temporary)
   PostgreSQL      TCP         5432          Security Group ID (self)
   ```

7. **Key Pair**: Create new or use existing key pair (save the .pem file securely)

### 2. Connect to EC2 Instance

```bash
# Set correct permissions for key file
chmod 400 your-key.pem

# Connect to instance
ssh -i your-key.pem ubuntu@your-ec2-public-ip

# Update system packages
sudo apt update && sudo apt upgrade -y
```

---

## Server Configuration

### 1. Install Required Dependencies

```bash
# Install essential build tools
sudo apt install -y build-essential git curl wget unzip

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib libpq-dev

# Install Erlang and Elixir
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt update
sudo apt install -y esl-erlang elixir

# Verify installations
elixir --version
psql --version

# Install Node.js (for asset compilation)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js
node --version
npm --version

# Install Nginx (reverse proxy)
sudo apt install -y nginx

# Install wkhtmltopdf (for PDF generation)
sudo apt install -y wkhtmltopdf
```

### 2. Configure Firewall

```bash
# Enable UFW firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable

# Check status
sudo ufw status
```

### 3. Create Application User

```bash
# Create dedicated user for the application
sudo adduser --disabled-password --gecos "" ricemill

# Add to sudo group (optional, for maintenance)
sudo usermod -aG sudo ricemill

# Switch to application user
sudo su - ricemill
```

---

## Database Setup

### 1. Configure PostgreSQL

```bash
# Switch to postgres user
sudo -u postgres psql

# In PostgreSQL prompt:
CREATE USER ricemill WITH PASSWORD 'your-secure-password';
CREATE DATABASE rice_mill_prod OWNER ricemill;
GRANT ALL PRIVILEGES ON DATABASE rice_mill_prod TO ricemill;

# Enable extensions
\c rice_mill_prod
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";

# Exit PostgreSQL
\q
```

### 2. Secure PostgreSQL

```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/14/main/postgresql.conf

# Update these settings:
listen_addresses = 'localhost'
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 2621kB
min_wal_size = 1GB
max_wal_size = 4GB

# Save and exit (Ctrl+X, Y, Enter)

# Edit pg_hba.conf for authentication
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Add/modify this line:
local   all             ricemill                                md5

# Restart PostgreSQL
sudo systemctl restart postgresql
sudo systemctl enable postgresql
```

### 3. Test Database Connection

```bash
# Test connection as ricemill user
psql -U ricemill -d rice_mill_prod -h localhost

# If successful, exit
\q
```

---

## Application Deployment

### 1. Clone Repository

```bash
# Switch to application user
sudo su - ricemill

# Create application directory
mkdir -p /home/ricemill/app
cd /home/ricemill/app

# Clone repository
git clone https://github.com/Madhukarreddy879/graindesk-phoenix.git .

# Or upload code via SCP from local machine:
# scp -i your-key.pem -r /path/to/local/app ubuntu@your-ec2-ip:/home/ubuntu/
# Then move to ricemill user directory
```

### 2. Install Application Dependencies

```bash
cd /home/ricemill/app

# Install Hex and Rebar
mix local.hex --force
mix local.rebar --force

# Install Elixir dependencies
mix deps.get --only prod

# Install Node.js dependencies
cd assets
npm install
cd ..
```

### 3. Configure Environment Variables

```bash
# Create environment file
nano /home/ricemill/app/.env.prod

# Add the following (replace with your values):
```

```bash
# Database Configuration
export DATABASE_URL="ecto://ricemill:your-secure-password@localhost/rice_mill_prod"
export POOL_SIZE=10

# Application Configuration
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export PHX_HOST="your-domain.com"
export PHX_SERVER=true
export PORT=4000

# Environment
export MIX_ENV=prod

# Email Configuration (optional - configure based on your provider)
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT=587
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="your-app-password"

# Logging
export LOG_LEVEL=info
```

```bash
# Generate SECRET_KEY_BASE
mix phx.gen.secret

# Copy the output and paste it in .env.prod file

# Make environment file executable
chmod +x /home/ricemill/app/.env.prod

# Load environment variables
source /home/ricemill/app/.env.prod
```

### 4. Compile Application

```bash
cd /home/ricemill/app

# Load environment
source .env.prod

# Compile assets
mix assets.deploy

# Compile application
MIX_ENV=prod mix compile

# Run database migrations
MIX_ENV=prod mix ecto.create
MIX_ENV=prod mix ecto.migrate

# Seed initial data (optional)
SUPER_ADMIN_EMAIL="admin@yourdomain.com" \
SUPER_ADMIN_PASSWORD="your-admin-password" \
MIX_ENV=prod mix run priv/repo/seeds.exs
```

### 5. Build Release (Recommended for Production)

```bash
cd /home/ricemill/app

# Build production release
MIX_ENV=prod mix release

# The release will be created at:
# _build/prod/rel/rice_mill/

# Test the release
_build/prod/rel/rice_mill/bin/rice_mill start
```

---

## Process Management

### Option 1: Systemd Service (Recommended)

```bash
# Create systemd service file
sudo nano /etc/systemd/system/ricemill.service
```

Add the following content:

```ini
[Unit]
Description=Rice Mill Inventory System
After=network.target postgresql.service

[Service]
Type=simple
User=ricemill
Group=ricemill
WorkingDirectory=/home/ricemill/app
EnvironmentFile=/home/ricemill/app/.env.prod
ExecStart=/home/ricemill/app/_build/prod/rel/rice_mill/bin/rice_mill start
ExecStop=/home/ricemill/app/_build/prod/rel/rice_mill/bin/rice_mill stop
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ricemill

[Install]
WantedBy=multi-user.target
```

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable ricemill

# Start the service
sudo systemctl start ricemill

# Check status
sudo systemctl status ricemill

# View logs
sudo journalctl -u ricemill -f
```

### Option 2: Using Mix (Development/Testing)

```bash
# Create a simple start script
nano /home/ricemill/app/start.sh
```

```bash
#!/bin/bash
cd /home/ricemill/app
source .env.prod
MIX_ENV=prod mix phx.server
```

```bash
# Make executable
chmod +x /home/ricemill/app/start.sh

# Run in background with nohup
nohup /home/ricemill/app/start.sh > /home/ricemill/app/app.log 2>&1 &
```

---

## SSL/HTTPS Configuration

### Option 1: Using Certbot (Let's Encrypt - Free)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

### Option 2: Configure Nginx as Reverse Proxy

```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/ricemill
```

Add the following configuration:

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name your-domain.com www.your-domain.com;
    
    return 301 https://$server_name$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    # SSL Configuration (Certbot will add these)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/ricemill_access.log;
    error_log /var/log/nginx/ricemill_error.log;

    # Proxy Settings
    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket Support for LiveView
    location /live {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }

    # Static Files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://localhost:4000;
        proxy_cache_valid 200 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/ricemill /etc/nginx/sites-enabled/

# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

---

## Monitoring & Maintenance

### 1. Application Monitoring

```bash
# View application logs
sudo journalctl -u ricemill -f

# View last 100 lines
sudo journalctl -u ricemill -n 100

# View logs from today
sudo journalctl -u ricemill --since today

# Check application status
sudo systemctl status ricemill
```

### 2. Database Monitoring

```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Monitor active connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"

# Check database size
sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('rice_mill_prod'));"

# View slow queries
sudo -u postgres psql rice_mill_prod -c "
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;"
```

### 3. System Monitoring

```bash
# Check disk usage
df -h

# Check memory usage
free -h

# Check CPU usage
top

# Check running processes
ps aux | grep beam

# Monitor network connections
sudo netstat -tulpn | grep LISTEN
```

### 4. Automated Backups

```bash
# Create backup script
sudo nano /home/ricemill/backup.sh
```

```bash
#!/bin/bash

# Configuration
BACKUP_DIR="/home/ricemill/backups"
DB_NAME="rice_mill_prod"
DB_USER="ricemill"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Create backup directory
mkdir -p $BACKUP_DIR

# Database backup
PGPASSWORD='your-secure-password' pg_dump -U $DB_USER -h localhost $DB_NAME | gzip > $BACKUP_DIR/db_backup_$DATE.sql.gz

# Application files backup (optional)
tar -czf $BACKUP_DIR/app_backup_$DATE.tar.gz /home/ricemill/app/priv/static/uploads

# Remove old backups
find $BACKUP_DIR -name "db_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "app_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $DATE"
```

```bash
# Make executable
chmod +x /home/ricemill/backup.sh

# Add to crontab (daily at 2 AM)
crontab -e

# Add this line:
0 2 * * * /home/ricemill/backup.sh >> /home/ricemill/backup.log 2>&1
```

### 5. Log Rotation

```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/ricemill
```

```
/home/ricemill/app/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 ricemill ricemill
    sharedscripts
    postrotate
        systemctl reload ricemill > /dev/null 2>&1 || true
    endscript
}
```

---

## Deployment Updates

### Zero-Downtime Deployment

```bash
# Create deployment script
nano /home/ricemill/deploy.sh
```

```bash
#!/bin/bash

set -e

APP_DIR="/home/ricemill/app"
cd $APP_DIR

echo "Starting deployment..."

# Pull latest code
git pull origin main

# Load environment
source .env.prod

# Install dependencies
mix deps.get --only prod
cd assets && npm install && cd ..

# Compile assets
mix assets.deploy

# Compile application
MIX_ENV=prod mix compile

# Run migrations
MIX_ENV=prod mix ecto.migrate

# Build new release
MIX_ENV=prod mix release --overwrite

# Restart application
sudo systemctl restart ricemill

echo "Deployment completed!"
echo "Checking application status..."
sleep 5
sudo systemctl status ricemill
```

```bash
# Make executable
chmod +x /home/ricemill/deploy.sh

# Run deployment
./deploy.sh
```

---

## Troubleshooting

### Common Issues

#### 1. Application Won't Start

```bash
# Check logs
sudo journalctl -u ricemill -n 50

# Check if port is in use
sudo lsof -i :4000

# Verify environment variables
source /home/ricemill/app/.env.prod
echo $DATABASE_URL
echo $SECRET_KEY_BASE

# Test database connection
psql -U ricemill -d rice_mill_prod -h localhost
```

#### 2. Database Connection Issues

```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# Verify database exists
sudo -u postgres psql -l | grep rice_mill

# Test connection
psql -U ricemill -d rice_mill_prod -h localhost -W
```

#### 3. Nginx Issues

```bash
# Check Nginx status
sudo systemctl status nginx

# Test configuration
sudo nginx -t

# Check error logs
sudo tail -f /var/log/nginx/ricemill_error.log

# Restart Nginx
sudo systemctl restart nginx
```

#### 4. SSL Certificate Issues

```bash
# Check certificate expiry
sudo certbot certificates

# Renew certificate manually
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run
```

#### 5. Memory Issues

```bash
# Check memory usage
free -h

# Check swap
sudo swapon --show

# Add swap if needed (2GB example)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Performance Optimization

```bash
# Increase file descriptors
sudo nano /etc/security/limits.conf

# Add:
ricemill soft nofile 65536
ricemill hard nofile 65536

# Optimize PostgreSQL
sudo nano /etc/postgresql/14/main/postgresql.conf

# Adjust based on your instance size:
shared_buffers = 25% of RAM
effective_cache_size = 75% of RAM
maintenance_work_mem = RAM / 16
work_mem = RAM / (max_connections * 3)
```

---

## Security Hardening

### 1. SSH Security

```bash
# Disable password authentication
sudo nano /etc/ssh/sshd_config

# Set:
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes

# Restart SSH
sudo systemctl restart sshd
```

### 2. Fail2Ban

```bash
# Install Fail2Ban
sudo apt install -y fail2ban

# Configure
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
```

```bash
# Start Fail2Ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 3. Automatic Security Updates

```bash
# Install unattended-upgrades
sudo apt install -y unattended-upgrades

# Enable automatic updates
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## Cost Optimization

### 1. Use Reserved Instances
- Save up to 72% with 1 or 3-year commitments
- Recommended for production workloads

### 2. Right-Size Your Instance
- Monitor CPU and memory usage
- Downgrade if consistently under 40% utilization
- Upgrade if consistently over 80% utilization

### 3. Use EBS Snapshots
- Automated backups to S3
- Cheaper than maintaining large EBS volumes
- Enable lifecycle policies

### 4. Enable CloudWatch Alarms
- Monitor costs and usage
- Set billing alerts
- Track resource utilization

---

## Checklist

### Pre-Deployment
- [ ] EC2 instance launched and accessible
- [ ] Security groups configured
- [ ] Domain name configured (optional)
- [ ] SSL certificate obtained
- [ ] Database password generated

### Deployment
- [ ] All dependencies installed
- [ ] PostgreSQL configured and secured
- [ ] Application code deployed
- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] Application compiled successfully

### Post-Deployment
- [ ] Application accessible via domain
- [ ] HTTPS working correctly
- [ ] Systemd service running
- [ ] Nginx reverse proxy configured
- [ ] Backups configured
- [ ] Monitoring setup
- [ ] Log rotation configured
- [ ] Security hardening completed

---

## Support & Resources

- **Phoenix Deployment Guide**: https://hexdocs.pm/phoenix/deployment.html
- **AWS EC2 Documentation**: https://docs.aws.amazon.com/ec2/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **Nginx Documentation**: https://nginx.org/en/docs/

---

**Deployment completed! Your Rice Mill Inventory System is now running on EC2.**

For issues or questions, refer to the troubleshooting section or check application logs.
