#!/bin/bash

# NebulaGraph Cluster Health Check Script
# This script checks the health of all NebulaGraph services

set -e

echo "=== NebulaGraph Cluster Health Check ==="

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Function to check service health
check_service_health() {
    local service_name=$1
    local container_name=$2
    local port=$3
    
    echo "Checking $service_name..."
    
    # Check if container is running
    if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container_name"; then
        echo "❌ $service_name container is not running"
        return 1
    fi
    
    # Check if container is healthy
    local health_status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container_name" | awk '{print $2}')
    if [[ $health_status != *"healthy"* ]]; then
        echo "⚠️  $service_name container is running but not healthy yet"
        return 1
    fi
    
    # Try to connect to the service
    if [ -n "$port" ]; then
        if ! docker exec "$container_name" nebula-console --addr="$container_name" --port="$port" -u root -p nebula -e "SHOW HOSTS;" > /dev/null 2>&1; then
            echo "❌ $service_name is not responding to queries"
            return 1
        fi
    fi
    
    echo "✅ $service_name is healthy"
    return 0
}

# Function to check cluster status
check_cluster_status() {
    echo "Checking cluster status..."
    
    # Try to connect to GraphD and check cluster status
    if docker exec nebula-graphd-1 nebula-console --addr=graphd --port=9669 -u root -p nebula -e "SHOW HOSTS;" > /tmp/nebula_cluster_status.txt 2>&1; then
        echo "✅ Cluster status check passed"
        echo "Cluster information:"
        cat /tmp/nebula_cluster_status.txt
        rm -f /tmp/nebula_cluster_status.txt
        return 0
    else
        echo "❌ Cluster status check failed"
        if [ -f /tmp/nebula_cluster_status.txt ]; then
            echo "Error details:"
            cat /tmp/nebula_cluster_status.txt
            rm -f /tmp/nebula_cluster_status.txt
        fi
        return 1
    fi
}

# Function to check metrics exporter
check_metrics_exporter() {
    echo "Checking metrics exporter..."
    
    # Check if exporter container is running
    if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "nebula-stats-exporter"; then
        echo "❌ Metrics exporter container is not running"
        return 1
    fi
    
    # Check if metrics endpoint is accessible
    if curl -s http://localhost:9100/metrics > /dev/null 2>&1; then
        echo "✅ Metrics exporter is accessible"
        return 0
    else
        echo "❌ Metrics exporter is not accessible"
        return 1
    fi
}

# Main health check
overall_health=0

# Check MetaD services
echo ""
echo "=== MetaD Services ==="
for i in {0..2}; do
    if ! check_service_health "MetaD$i" "nebula-metad${i}-1" "9559"; then
        overall_health=1
    fi
done

# Check StorageD services
echo ""
echo "=== StorageD Services ==="
for i in {0..2}; do
    if ! check_service_health "StorageD$i" "nebula-storaged${i}-1" "9779"; then
        overall_health=1
    fi
done

# Check GraphD service
echo ""
echo "=== GraphD Service ==="
if ! check_service_health "GraphD" "nebula-graphd-1" "9669"; then
    overall_health=1
fi

# Check cluster status
echo ""
if ! check_cluster_status; then
    overall_health=1
fi

# Check metrics exporter
echo ""
if ! check_metrics_exporter; then
    overall_health=1
fi

# Overall status
echo ""
echo "=== Overall Status ==="
if [ $overall_health -eq 0 ]; then
    echo "🎉 All NebulaGraph services are healthy!"
    echo ""
    echo "You can now connect to NebulaGraph using:"
    echo "  - GraphD: localhost:9669"
    echo "  - Metrics: http://localhost:9100/metrics"
    echo ""
    echo "To test the connection, run:"
    echo "  docker exec nebula-graphd-1 nebula-console --addr=graphd --port=9669 -u root -p nebula"
else
    echo "❌ Some services are not healthy. Please check the logs:"
    echo "  docker-compose -f docker-compose.nebula.yml logs -f"
    echo ""
    echo "If services are still starting up, wait a few minutes and run this script again."
    exit 1
fi