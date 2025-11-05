#!/bin/bash

# Production Deployment Script
# This script deploys the Rice Mill Inventory System to production

set -e

echo "🚀 Starting production deployment..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Load environment variables
source .env

# Validate required environment variables
required_vars=("DB_PASSWORD" "SECRET_KEY_BASE" "SUPER_ADMIN_EMAIL" "SUPER_ADMIN_PASSWORD")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ] || [[ "${!var}" == *"here"* ]]; then
        echo "❌ Required environment variable $var is not set or still has placeholder value"
        exit 1
    fi
done

echo "✅ Environment variables validated"

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.prod.yml down || true

# Pull latest changes
echo "📥 Pulling latest changes..."
git pull origin master

# Build and start containers
echo "🔨 Building and starting containers..."
docker-compose -f docker-compose.prod.yml up -d --build

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
sleep 10

# Run database migrations
echo "🗄️ Running database migrations..."
docker-compose -f docker-compose.prod.yml exec app bin/rice_mill eval "RiceMill.Release.migrate"

# Run database seeds (creates super admin)
echo "🌱 Running database seeds..."
docker-compose -f docker-compose.prod.yml exec app bin/rice_mill eval "RiceMill.Release.seed"

# Wait for application to be healthy
echo "🏥 Waiting for application to be healthy..."
for i in {1..30}; do
    if curl -f http://localhost:4000/health > /dev/null 2>&1; then
        echo "✅ Application is healthy!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Application failed to become healthy"
        docker-compose -f docker-compose.prod.yml logs app
        exit 1
    fi
    echo "   Attempt $i/30..."
    sleep 2
done

# Show status
echo "📊 Deployment status:"
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "🌐 Your application is available at: https://snvs.dpdns.org"
echo "👤 Admin login: $SUPER_ADMIN_EMAIL"
echo ""
echo "🔧 Useful commands:"
echo "   - View logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "   - Access app shell: docker-compose -f docker-compose.prod.yml exec app bash"
echo "   - Access database: docker-compose -f docker-compose.prod.yml exec db psql -U $DB_USER -d rice_mill_inventory_prod"
echo "   - Backup database: ./backup.sh"