#!/bin/bash

# NebulaGraph Cluster Initialization Script
# This script prepares the environment for NebulaGraph cluster deployment

set -e

echo "=== NebulaGraph Cluster Initialization ==="

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Working directory: $SCRIPT_DIR"

# Create necessary directories
echo "Creating data and log directories..."
# Note: Directories are already created, just ensuring they exist
mkdir -p ./data/meta0 ./data/meta1 ./data/meta2
mkdir -p ./data/storage0 ./data/storage1 ./data/storage2
mkdir -p ./logs/meta0 ./logs/meta1 ./logs/meta2
mkdir -p ./logs/storaged0 ./logs/storaged1 ./logs/storaged2
mkdir -p ./logs/graphd

# Set proper permissions
echo "Setting directory permissions..."
chmod 755 ./data/*
chmod 755 ./logs/*

# Check if Docker is running
echo "Checking Docker status..."
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if docker-compose is available
echo "Checking docker-compose availability..."
if ! command -v docker-compose > /dev/null 2>&1; then
    echo "Error: docker-compose is not installed or not in PATH."
    exit 1
fi

# Clean up any existing containers and volumes
echo "Cleaning up existing containers and volumes..."
docker-compose -f docker-compose.nebula.yml down -v 2>/dev/null || true

# Remove any orphaned containers
echo "Removing orphaned containers..."
docker ps -a --filter "name=nebula" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true

# Pull the latest images
echo "Pulling NebulaGraph Docker images..."
docker-compose -f docker-compose.nebula.yml pull

echo "=== Initialization Complete ==="
echo ""
echo "Next steps:"
echo "1. Start the cluster: docker-compose -f docker-compose.nebula.yml up -d"
echo "2. Check cluster status: docker-compose -f docker-compose.nebula.yml ps"
echo "3. View logs: docker-compose -f docker-compose.nebula.yml logs -f"
echo ""
echo "Note: It may take 2-3 minutes for all services to become healthy."