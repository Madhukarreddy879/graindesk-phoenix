#!/bin/bash

# Database Backup Script
# This script creates automated backups of the PostgreSQL database

set -e

# Load environment variables
source .env

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/rice_mill_backup_$TIMESTAMP.sql"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

echo "💾 Creating database backup..."

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Create the backup
docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U $DB_USER -d rice_mill_inventory_prod > $BACKUP_FILE

# Compress the backup
gzip $BACKUP_FILE
BACKUP_FILE="${BACKUP_FILE}.gz"

echo "✅ Backup created: $BACKUP_FILE"

# Clean up old backups
echo "🧹 Cleaning up old backups (older than $RETENTION_DAYS days)..."
find $BACKUP_DIR -name "rice_mill_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "✅ Backup cleanup completed"

# Show backup directory size
echo "📊 Backup directory size: $(du -sh $BACKUP_DIR | cut -f1)"

# List recent backups
echo "📋 Recent backups:"
ls -lh $BACKUP_DIR/rice_mill_backup_*.gz | tail -5