# Design Document

## Overview

This design document describes the architecture and implementation approach for deploying the RiceMill application in production using Docker containers orchestrated by Docker Compose, with Traefik as a reverse proxy providing automatic SSL certificate management through Let's Encrypt for the domain graindesk.in.

The solution provides a production-ready, scalable, and secure deployment that can be easily maintained and updated.

## Architecture

### High-Level Architecture

```
Internet
    |
    | (HTTP/HTTPS)
    v
Traefik (Reverse Proxy + SSL Termination)
    |
    | (HTTP - Internal Network)
    v
RiceMill Application (Phoenix/Elixir)
    |
    | (PostgreSQL Protocol - Internal Network)
    v
PostgreSQL Database
```

### Container Architecture

The deployment consists of three main containers:

1. **Traefik Container**
   - Acts as the edge router and reverse proxy
   - Handles SSL/TLS termination
   - Automatically obtains and renews Let's Encrypt certificates
   - Routes traffic to the application container
   - Exposes ports 80 (HTTP) and 443 (HTTPS) to the internet

2. **Application Container**
   - Runs the RiceMill Phoenix application
   - Exposes port 4000 internally (not to the internet)
   - Connects to PostgreSQL via internal Docker network
   - Runs database migrations on startup
   - Includes health check endpoint

3. **PostgreSQL Container**
   - Runs PostgreSQL 15
   - Stores data in a persistent volume
   - Only accessible via internal Docker network
   - Includes health checks using pg_isready

### Network Architecture

Two Docker networks are used:

1. **web** (external network)
   - Connects Traefik to the application
   - Allows Traefik to route traffic to the application

2. **backend** (internal network)
   - Connects the application to PostgreSQL
   - Isolated from external access
   - Provides secure database communication

## Components and Interfaces

### 1. Dockerfile (Multi-Stage Build)

The Dockerfile uses a multi-stage build approach:

**Stage 1: Builder**
- Base image: `hexpm/elixir:1.17.3-erlang-27.1.2-ubuntu-jammy-20240808`
- Installs build dependencies (git, build-essential, curl, nodejs, npm)
- Installs Hex and Rebar
- Compiles dependencies
- Compiles assets (Tailwind, esbuild)
- Compiles the application
- Creates a production release

**Stage 2: Runner**
- Base image: `ubuntu:jammy-20240808`
- Installs runtime dependencies (openssl, libssl3, libncurses6, locales, ca-certificates, wkhtmltopdf for PDF generation)
- Creates a non-root user (appuser)
- Copies the release from the builder stage
- Sets up entrypoint script for migrations
- Exposes port 4000
- Runs as non-root user

### 2. Docker Compose Configuration

**docker-compose.prod.yml** defines three services:

#### Traefik Service
```yaml
traefik:
  image: traefik:v3.2
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - /var/run/docker.sock (Docker API access)
    - traefik-certificates (SSL certificates)
  labels:
    - Traefik configuration via labels
  environment:
    - Let's Encrypt email configuration
```

#### Application Service
```yaml
app:
  build: .
  environment:
    - DATABASE_URL
    - SECRET_KEY_BASE
    - PHX_HOST=graindesk.in
    - PORT=4000
  labels:
    - Traefik routing rules
    - SSL configuration
  depends_on:
    - postgres
  healthcheck:
    - HTTP check on /health endpoint
```

#### PostgreSQL Service
```yaml
postgres:
  image: postgres:15
  environment:
    - POSTGRES_USER
    - POSTGRES_PASSWORD
    - POSTGRES_DB
  volumes:
    - postgres-data (persistent storage)
  healthcheck:
    - pg_isready check
```

### 3. Entrypoint Script

The entrypoint script (`entrypoint.sh`) handles:
- Waiting for PostgreSQL to be ready
- Running database migrations
- Starting the Phoenix application
- Proper signal handling for graceful shutdown

### 4. Environment Configuration

**.env.production** file contains:
- Database credentials
- Application secrets
- Domain configuration
- Let's Encrypt email
- Optional SMTP settings

### 5. Traefik Configuration

Traefik is configured entirely through Docker labels:

**Routing:**
- Routes `graindesk.in` to the application container
- HTTP to HTTPS redirect
- Host-based routing rules

**SSL/TLS:**
- Automatic certificate resolver using Let's Encrypt
- HTTP-01 challenge for domain validation
- Certificate storage in persistent volume
- TLS version and cipher configuration

**Middleware:**
- Security headers
- Compression
- Rate limiting (optional)

## Data Models

### Volume Mappings

1. **postgres-data**
   - Purpose: Persistent PostgreSQL database storage
   - Mount point: `/var/lib/postgresql/data`
   - Backup strategy: Regular pg_dump to external storage

2. **traefik-certificates**
   - Purpose: Let's Encrypt SSL certificates
   - Mount point: `/letsencrypt`
   - Contains: `acme.json` with certificates and account info

### Environment Variables

**Required:**
- `DATABASE_URL`: PostgreSQL connection string
- `SECRET_KEY_BASE`: Phoenix secret key (64+ characters)
- `PHX_HOST`: Application hostname (graindesk.in)
- `POSTGRES_USER`: Database username
- `POSTGRES_PASSWORD`: Database password
- `POSTGRES_DB`: Database name
- `LETSENCRYPT_EMAIL`: Email for Let's Encrypt notifications

**Optional:**
- `PORT`: Application port (default: 4000)
- `POOL_SIZE`: Database connection pool size (default: 10)
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`: Email configuration

## Error Handling

### Container Failures

1. **Application Container Failure**
   - Docker restart policy: `unless-stopped`
   - Health check failures trigger automatic restart
   - Logs available via `docker logs`

2. **PostgreSQL Container Failure**
   - Restart policy ensures automatic recovery
   - Data persists in volume
   - Application waits for database before starting

3. **Traefik Container Failure**
   - Restart policy ensures automatic recovery
   - Certificates persist in volume
   - Minimal downtime during restart

### SSL Certificate Issues

1. **Initial Certificate Acquisition**
   - Traefik automatically requests certificate on first request
   - HTTP-01 challenge requires port 80 to be accessible
   - Fallback to self-signed certificate if Let's Encrypt fails

2. **Certificate Renewal**
   - Automatic renewal 30 days before expiration
   - Retry logic for failed renewals
   - Email notifications to LETSENCRYPT_EMAIL

### Migration Failures

1. **Database Migration Errors**
   - Application logs error details
   - Container exits with non-zero status
   - Manual intervention required to fix migration
   - Rollback procedure documented

### Network Issues

1. **Database Connection Failures**
   - Application retries connection with exponential backoff
   - Health check fails, triggering container restart
   - Logs include connection error details

2. **External Network Issues**
   - Traefik handles connection timeouts
   - Circuit breaker pattern for backend failures
   - Graceful error pages for users

## Testing Strategy

### Pre-Deployment Testing

1. **Local Docker Build**
   - Build Docker image locally
   - Verify image size and layers
   - Test container startup

2. **Docker Compose Validation**
   - Validate compose file syntax
   - Test with docker-compose config
   - Verify environment variable substitution

3. **Integration Testing**
   - Start all services with docker-compose up
   - Verify application accessibility
   - Test database connectivity
   - Verify health checks

### Production Deployment Testing

1. **Smoke Tests**
   - Verify HTTPS access to graindesk.in
   - Check SSL certificate validity
   - Test application login flow
   - Verify database operations

2. **Health Check Validation**
   - Monitor /health endpoint
   - Verify container health status
   - Test automatic restart on failure

3. **SSL/TLS Testing**
   - Verify certificate chain
   - Test HTTP to HTTPS redirect
   - Validate TLS configuration (SSL Labs)

### Monitoring and Observability

1. **Container Monitoring**
   - Docker stats for resource usage
   - Container logs via docker logs
   - Health check status monitoring

2. **Application Monitoring**
   - Phoenix telemetry metrics
   - Request/response times
   - Error rates and patterns

3. **Traefik Monitoring**
   - Access logs for traffic patterns
   - SSL certificate expiration monitoring
   - Backend health status

## Security Considerations

### Container Security

1. **Non-Root User**
   - Application runs as `appuser` user
   - Minimal privileges inside container
   - Read-only filesystem where possible

2. **Image Security**
   - Ubuntu LTS base for stability and compatibility
   - Regular image updates
   - No unnecessary packages
   - Security patches via apt updates

### Network Security

1. **Network Isolation**
   - PostgreSQL not exposed to internet
   - Internal networks for service communication
   - Traefik as single entry point

2. **SSL/TLS Configuration**
   - TLS 1.2+ only
   - Strong cipher suites
   - HSTS headers

### Secrets Management

1. **Environment Variables**
   - Secrets stored in .env file
   - .env file excluded from version control
   - File permissions restricted (600)

2. **Database Credentials**
   - Strong passwords required
   - Credentials not hardcoded
   - Regular password rotation recommended

## Deployment Process

### Initial Deployment

1. **Prerequisites**
   - Docker and Docker Compose installed
   - Domain DNS pointing to server IP
   - Ports 80 and 443 open in firewall

2. **Setup Steps**
   - Clone repository
   - Create .env.production file
   - Generate SECRET_KEY_BASE
   - Build Docker image
   - Start services with docker-compose
   - Verify deployment

### Updates and Rollbacks

1. **Application Updates**
   - Build new Docker image
   - Tag with version number
   - Update docker-compose.yml
   - Perform rolling update
   - Verify health checks

2. **Rollback Procedure**
   - Stop current containers
   - Revert to previous image tag
   - Rollback database migrations if needed
   - Restart services
   - Verify functionality

### Backup and Restore

1. **Database Backups**
   - Automated daily backups using pg_dump
   - Backup retention policy (30 days)
   - Off-site backup storage
   - Regular restore testing

2. **Certificate Backups**
   - Backup traefik-certificates volume
   - Store securely off-server
   - Include in disaster recovery plan

## Performance Considerations

1. **Resource Allocation**
   - Application: 1-2 CPU cores, 1-2GB RAM
   - PostgreSQL: 1-2 CPU cores, 2-4GB RAM
   - Traefik: 0.5 CPU cores, 512MB RAM

2. **Connection Pooling**
   - Database pool size: 10-20 connections
   - Adjust based on load

3. **Caching**
   - Traefik caches SSL sessions
   - Application uses Cachex for data caching
   - Static assets served with cache headers

## Maintenance

1. **Regular Tasks**
   - Monitor disk space usage
   - Review logs for errors
   - Check certificate expiration
   - Update Docker images
   - Backup verification

2. **Scaling Considerations**
   - Horizontal scaling: Add application replicas
   - Load balancing: Traefik handles automatically
   - Database scaling: Consider read replicas
   - Resource monitoring: Set up alerts
