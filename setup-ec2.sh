#!/bin/bash

# EC2 Deployment Script for Rice Mill Inventory System
# This script sets up the production environment on EC2

set -e

echo "🚀 Starting EC2 deployment for Rice Mill Inventory System..."

# Update system packages
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker and Docker Compose
echo "🐳 Installing Docker and Docker Compose..."
if ! command -v docker &> /dev/null; then
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
fi

if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Add user to docker group
sudo usermod -aG docker $USER

# Install other utilities
echo "🔧 Installing utilities..."
sudo apt install -y git curl htop nginx-cert-utils apache2-utils

# Create application directory
APP_DIR="/opt/rice-mill-inventory"
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Create necessary directories
mkdir -p $APP_DIR/{letsencrypt,backups,uploads,logs}

# Clone or update the repository
if [ -d "$APP_DIR/.git" ]; then
    echo "📥 Updating existing repository..."
    cd $APP_DIR
    git pull origin main
else
    echo "📥 Cloning repository..."
    git clone https://github.com/your-username/rice-mill-inventory.git $APP_DIR
    cd $APP_DIR
fi

# Setup environment file
if [ ! -f "$APP_DIR/.env" ]; then
    echo "⚙️ Setting up environment file..."
    cp .env.example .env
    echo "❗ Please edit $APP_DIR/.env with your production values"
    echo "   Required: DB_PASSWORD, SECRET_KEY_BASE, SUPER_ADMIN_PASSWORD"
fi

# Generate secret key base if not set
if ! grep -q "SECRET_KEY_BASE=your_64_character_secret" $APP_DIR/.env; then
    echo "🔑 Secret key base already set"
else
    SECRET_KEY=$(openssl rand -base64 64 | tr -d '\n')
    sed -i "s/your_64_character_secret_key_base_here/$SECRET_KEY/" $APP_DIR/.env
    echo "🔑 Generated new secret key base"
fi

# Set proper permissions
chmod 600 $APP_DIR/.env
chmod 755 $APP_DIR/deploy.sh

echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Edit $APP_DIR/.env with your production values"
echo "2. Run: cd $APP_DIR && ./deploy.sh"
echo ""
echo "🔧 After deployment, you can manage the application with:"
echo "   - Start: docker-compose -f docker-compose.prod.yml up -d"
echo "   - Stop: docker-compose -f docker-compose.prod.yml down"
echo "   - Logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "   - Update: git pull && docker-compose -f docker-compose.prod.yml up -d --build"