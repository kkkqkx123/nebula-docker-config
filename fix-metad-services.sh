#!/bin/bash

# NebulaGraph MetaD Services Fix Script
# This script diagnoses and fixes MetaD service issues

set -e

echo "=== NebulaGraph MetaD Services Fix ==="

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Function to check if a container exists and is running
check_container() {
    local container_name=$1
    if docker ps --format "table {{.Names}}" | grep -q "$container_name"; then
        return 0
    else
        return 1
    fi
}

# Function to check container logs for errors
check_container_logs() {
    local container_name=$1
    local log_file=$2
    
    echo "Checking logs for $container_name..."
    
    if check_container "$container_name"; then
        echo "=== Container logs for $container_name ==="
        docker logs "$container_name" --tail 20
        echo ""
        
        # Check for specific error patterns
        if docker logs "$container_name" 2>&1 | grep -i "error\|exception\|failed" > /tmp/${container_name}_errors.txt; then
            echo "❌ Found errors in $container_name logs:"
            cat /tmp/${container_name}_errors.txt
            rm -f /tmp/${container_name}_errors.txt
            return 1
        else
            echo "✅ No errors found in $container_name logs"
            return 0
        fi
    else
        echo "❌ Container $container_name is not running"
        return 1
    fi
}

# Function to clean up cluster ID files (fixes wrong cluster ID issues)
cleanup_cluster_ids() {
    echo "Cleaning up cluster ID files..."
    
    # Stop all services
    echo "Stopping all NebulaGraph services..."
    docker-compose -f docker-compose.nebula.yml down
    
    # Remove cluster.id files from data directories
    echo "Removing cluster.id files..."
    for i in {0..2}; do
        if [ -f "./data/meta$i/cluster.id" ]; then
            echo "Removing ./data/meta$i/cluster.id"
            rm -f ./data/meta$i/cluster.id
        fi
        
        if [ -f "./data/storage$i/cluster.id" ]; then
            echo "Removing ./data/storage$i/cluster.id"
            rm -f ./data/storage$i/cluster.id"
        fi
    done
    
    echo "✅ Cluster ID files cleaned up"
}

# Function to fix data directory permissions
fix_permissions() {
    echo "Fixing data directory permissions..."
    
    # Ensure all data directories exist and have correct permissions
    mkdir -p ./data/meta0 ./data/meta1 ./data/meta2
    mkdir -p ./data/storage0 ./data/storage1 ./data/storage2
    mkdir -p ./logs/meta0 ./logs/meta1 ./logs/meta2
    mkdir -p ./logs/storage0 ./logs/storage1 ./logs/storage2
    mkdir -p ./logs/graphd
    
    # Set correct permissions
    chmod 755 ./data/*
    chmod 755 ./logs/*
    
    echo "✅ Directory permissions fixed"
}

# Function to restart MetaD services in correct order
restart_metad_services() {
    echo "Restarting MetaD services in correct order..."
    
    # Start with metad0 (first node)
    echo "Starting metad0..."
    docker-compose -f docker-compose.nebula.yml up -d metad0
    
    # Wait for metad0 to be ready
    echo "Waiting for metad0 to be ready..."
    for i in {1..30}; do
        if docker exec nebula-metad0-1 nebula-console --addr=metad0 --port=9559 -u root -p nebula -e "SHOW HOSTS;" > /dev/null 2>&1; then
            echo "✅ metad0 is ready"
            break
        fi
        echo "Waiting for metad0... ($i/30)"
        sleep 5
    done
    
    # Start metad1
    echo "Starting metad1..."
    docker-compose -f docker-compose.nebula.yml up -d metad1
    
    # Wait for metad1 to be ready
    echo "Waiting for metad1 to be ready..."
    for i in {1..30}; do
        if docker exec nebula-metad1-1 nebula-console --addr=metad1 --port=9559 -u root -p nebula -e "SHOW HOSTS;" > /dev/null 2>&1; then
            echo "✅ metad1 is ready"
            break
        fi
        echo "Waiting for metad1... ($i/30)"
        sleep 5
    done
    
    # Start metad2
    echo "Starting metad2..."
    docker-compose -f docker-compose.nebula.yml up -d metad2
    
    # Wait for metad2 to be ready
    echo "Waiting for metad2 to be ready..."
    for i in {1..30}; do
        if docker exec nebula-metad2-1 nebula-console --addr=metad2 --port=9559 -u root -p nebula -e "SHOW HOSTS;" > /dev/null 2>&1; then
            echo "✅ metad2 is ready"
            break
        fi
        echo "Waiting for metad2... ($i/30)"
        sleep 5
    done
    
    echo "✅ All MetaD services restarted"
}

# Function to verify MetaD cluster status
verify_metad_cluster() {
    echo "Verifying MetaD cluster status..."
    
    # Check cluster status from metad0
    if docker exec nebula-metad0-1 nebula-console --addr=metad0 --port=9559 -u root -p nebula -e "SHOW HOSTS META;" > /tmp/metad_cluster_status.txt 2>&1; then
        echo "✅ MetaD cluster status:"
        cat /tmp/metad_cluster_status.txt
        rm -f /tmp/metad_cluster_status.txt
        return 0
    else
        echo "❌ Failed to get MetaD cluster status"
        if [ -f /tmp/metad_cluster_status.txt ]; then
            echo "Error details:"
            cat /tmp/metad_cluster_status.txt
            rm -f /tmp/metad_cluster_status.txt
        fi
        return 1
    fi
}

# Main fix process
echo "Starting MetaD services fix process..."

# Step 1: Check current status
echo ""
echo "=== Step 1: Checking current MetaD service status ==="
metad_healthy=true
for i in {0..2}; do
    if ! check_container_logs "nebula-metad${i}-1"; then
        metad_healthy=false
    fi
done

# Step 2: Fix issues
echo ""
echo "=== Step 2: Fixing MetaD service issues ==="

if [ "$metad_healthy" = false ]; then
    echo "MetaD services have issues, applying fixes..."
    
    # Fix permissions
    fix_permissions
    
    # Clean up cluster IDs
    cleanup_cluster_ids
    
    # Restart MetaD services
    restart_metad_services
    
    # Verify cluster status
    if verify_metad_cluster; then
        echo "✅ MetaD cluster is healthy"
    else
        echo "❌ MetaD cluster still has issues"
        exit 1
    fi
else
    echo "✅ MetaD services appear to be healthy"
fi

# Step 3: Start remaining services
echo ""
echo "=== Step 3: Starting remaining services ==="
echo "Starting StorageD and GraphD services..."
docker-compose -f docker-compose.nebula.yml up -d

# Step 4: Final verification
echo ""
echo "=== Step 4: Final verification ==="
echo "Waiting for all services to be ready..."
sleep 30

# Run health check
if [ -f "./check-nebula-health.sh" ]; then
    chmod +x ./check-nebula-health.sh
    ./check-nebula-health.sh
else
    echo "Health check script not found, manual verification required"
fi

echo ""
echo "=== MetaD Services Fix Complete ==="
echo ""
echo "If services are still not healthy, please check:"
echo "1. Docker logs: docker-compose -f docker-compose.nebula.yml logs -f"
echo "2. System resources: docker stats"
echo "3. Network connectivity: docker network ls"