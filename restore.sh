#!/bin/bash

# Database Restore Script
# This script restores a PostgreSQL database from backup

set -e

if [ $# -eq 0 ]; then
    echo "❌ Usage: $0 <backup_file>"
    echo "📋 Available backups:"
    ls -lh ./backups/rice_mill_backup_*.gz 2>/dev/null || echo "   No backups found"
    exit 1
fi

BACKUP_FILE=$1

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Load environment variables
source .env

echo "🔄 Restoring database from: $BACKUP_FILE"

# Confirm restore
read -p "⚠️  This will replace the current database. Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "❌ Restore cancelled"
    exit 1
fi

# Stop the application to prevent conflicts
echo "🛑 Stopping application..."
docker-compose -f docker-compose.prod.yml stop app

# Drop and recreate the database
echo "🗄️ Recreating database..."
docker-compose -f docker-compose.prod.yml exec -T db psql -U $DB_USER -c "DROP DATABASE IF EXISTS rice_mill_inventory_prod;"
docker-compose -f docker-compose.prod.yml exec -T db psql -U $DB_USER -c "CREATE DATABASE rice_mill_inventory_prod;"

# Restore the backup
echo "📥 Restoring backup..."
if [[ $BACKUP_FILE == *.gz ]]; then
    gunzip -c $BACKUP_FILE | docker-compose -f docker-compose.prod.yml exec -T db psql -U $DB_USER -d rice_mill_inventory_prod
else
    docker-compose -f docker-compose.prod.yml exec -T db psql -U $DB_USER -d rice_mill_inventory_prod < $BACKUP_FILE
fi

# Start the application
echo "🚀 Starting application..."
docker-compose -f docker-compose.prod.yml start app

# Wait for application to be healthy
echo "🏥 Waiting for application to be healthy..."
sleep 10
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

echo "✅ Database restore completed successfully!"