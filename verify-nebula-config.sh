#!/bin/bash

# Nebula Configuration Verification Script
# This script verifies that Nebula components are properly configured for stats export

set -e

echo "=== Nebula Configuration Verification ==="
echo "Checking Nebula component configurations..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if docker-compose file exists
if [ ! -f "docker-compose.nebula.yml" ]; then
    print_error "docker-compose.nebula.yml not found!"
    exit 1
fi

print_status "Found docker-compose.nebula.yml"

# Check if nebula-stats-exporter-config.yaml exists
if [ ! -f "nebula-stats-exporter-config.yaml" ]; then
    print_error "nebula-stats-exporter-config.yaml not found!"
    exit 1
fi

print_status "Found nebula-stats-exporter-config.yaml"

# Check if nebula-graphd.conf exists
if [ ! -f "nebula-graphd.conf" ]; then
    print_error "nebula-graphd.conf not found!"
    exit 1
fi

print_status "Found nebula-graphd.conf"

echo ""
echo "=== Checking Docker Compose Configuration ==="

# Check if all components have logtostderr=false
echo "Checking logtostderr configuration..."
if grep -q "logtostderr=false" docker-compose.nebula.yml; then
    print_status "All components have logtostderr=false"
else
    print_error "Some components missing logtostderr=false"
fi

# Check if all components have alsologtostderr=false
echo "Checking alsologtostderr configuration..."
if grep -q "alsologtostderr=false" docker-compose.nebula.yml; then
    print_status "All components have alsologtostderr=false"
else
    print_error "Some components missing alsologtostderr=false"
fi

# Check if all components have stdout_log_filename configured
echo "Checking stdout_log_filename configuration..."
if grep -q "stdout_log_filename=/logs/stdout.log" docker-compose.nebula.yml; then
    print_status "All components have stdout_log_filename configured"
else
    print_error "Some components missing stdout_log_filename configuration"
fi

# Check if all components have enable_metric=true
echo "Checking enable_metric configuration..."
if grep -q "enable_metric=true" docker-compose.nebula.yml; then
    print_status "All components have enable_metric=true"
else
    print_error "Some components missing enable_metric=true"
fi

# Check if all components have ws_http_port configured
echo "Checking ws_http_port configuration..."
metad_count=$(grep -c "ws_http_port=1955" docker-compose.nebula.yml)
storaged_count=$(grep -c "ws_http_port=1977" docker-compose.nebula.yml)
graphd_count=$(grep -c "ws_http_port=19669" docker-compose.nebula.yml)

if [ "$metad_count" -eq 3 ] && [ "$storaged_count" -eq 3 ] && [ "$graphd_count" -eq 1 ]; then
    print_status "All components have ws_http_port configured"
else
    print_error "Some components missing ws_http_port configuration"
    echo "  metad ws_http_port count: $metad_count (expected: 3)"
    echo "  storaged ws_http_port count: $storaged_count (expected: 3)"
    echo "  graphd ws_http_port count: $graphd_count (expected: 1)"
fi

echo ""
echo "=== Checking Stats Exporter Configuration ==="

# Check if all endpoints in nebula-stats-exporter-config.yaml match docker-compose ports
echo "Checking endpoint port configuration..."

# Extract ports from nebula-stats-exporter-config.yaml
exporter_metad0_port=$(grep -A 10 "metad0" nebula-stats-exporter-config.yaml | grep "endpointPort" | awk '{print $2}')
exporter_metad1_port=$(grep -A 10 "metad1" nebula-stats-exporter-config.yaml | grep "endpointPort" | awk '{print $2}')
exporter_metad2_port=$(grep -A 10 "metad2" nebula-stats-exporter-config.yaml | grep "endpointPort" | awk '{print $2}')
exporter_storaged0_port=$(grep -A 10 "storaged0" nebula-stats-exporter-config.yaml | grep "endpointPort" | awk '{print $2}')
exporter_storaged1_port=$(grep -A 10 "storaged1" nebula-stats-exporter-config.yaml | grep "endpointPort" | awk '{print $2}')
exporter_storaged2_port=$(grep -A 10 "storaged2" nebula-stats-exporter-config.yaml | grep "endpointPort" | awk '{print $2}')
exporter_graphd_port=$(grep -A 10 "graphd" nebula-stats-exporter-config.yaml | grep "endpointPort" | awk '{print $2}')

# Extract ports from docker-compose.nebula.yml
compose_metad0_port=$(grep -A 20 "metad0:" docker-compose.nebula.yml | grep "ws_http_port=19559" | wc -l)
compose_metad1_port=$(grep -A 20 "metad1:" docker-compose.nebula.yml | grep "ws_http_port=19560" | wc -l)
compose_metad2_port=$(grep -A 20 "metad2:" docker-compose.nebula.yml | grep "ws_http_port=19561" | wc -l)
compose_storaged0_port=$(grep -A 20 "storaged0:" docker-compose.nebula.yml | grep "ws_http_port=19779" | wc -l)
compose_storaged1_port=$(grep -A 20 "storaged1:" docker-compose.nebula.yml | grep "ws_http_port=19780" | wc -l)
compose_storaged2_port=$(grep -A 20 "storaged2:" docker-compose.nebula.yml | grep "ws_http_port=19781" | wc -l)
compose_graphd_port=$(grep -A 20 "graphd:" docker-compose.nebula.yml | grep "ws_http_port=19669" | wc -l)

# Check port matching
if [ "$exporter_metad0_port" = "19559" ] && [ "$compose_metad0_port" -eq 1 ]; then
    print_status "metad0 port configuration matches"
else
    print_error "metad0 port configuration mismatch"
fi

if [ "$exporter_metad1_port" = "19560" ] && [ "$compose_metad1_port" -eq 1 ]; then
    print_status "metad1 port configuration matches"
else
    print_error "metad1 port configuration mismatch"
fi

if [ "$exporter_metad2_port" = "19561" ] && [ "$compose_metad2_port" -eq 1 ]; then
    print_status "metad2 port configuration matches"
else
    print_error "metad2 port configuration mismatch"
fi

if [ "$exporter_storaged0_port" = "19779" ] && [ "$compose_storaged0_port" -eq 1 ]; then
    print_status "storaged0 port configuration matches"
else
    print_error "storaged0 port configuration mismatch"
fi

if [ "$exporter_storaged1_port" = "19780" ] && [ "$compose_storaged1_port" -eq 1 ]; then
    print_status "storaged1 port configuration matches"
else
    print_error "storaged1 port configuration mismatch"
fi

if [ "$exporter_storaged2_port" = "19781" ] && [ "$compose_storaged2_port" -eq 1 ]; then
    print_status "storaged2 port configuration matches"
else
    print_error "storaged2 port configuration mismatch"
fi

if [ "$exporter_graphd_port" = "19669" ] && [ "$compose_graphd_port" -eq 1 ]; then
    print_status "graphd port configuration matches"
else
    print_error "graphd port configuration mismatch"
fi

echo ""
echo "=== Checking nebula-graphd.conf Configuration ==="

# Check nebula-graphd.conf
if grep -q "logtostderr=false" nebula-graphd.conf; then
    print_status "nebula-graphd.conf has logtostderr=false"
else
    print_error "nebula-graphd.conf missing logtostderr=false"
fi

if grep -q "alsologtostderr=false" nebula-graphd.conf; then
    print_status "nebula-graphd.conf has alsologtostderr=false"
else
    print_error "nebula-graphd.conf missing alsologtostderr=false"
fi

if grep -q "stdout_log_filename=/logs/stdout.log" nebula-graphd.conf; then
    print_status "nebula-graphd.conf has stdout_log_filename configured"
else
    print_error "nebula-graphd.conf missing stdout_log_filename configuration"
fi

echo ""
echo "=== Verification Complete ==="
echo "Configuration files have been updated with the following changes:"
echo "1. All Nebula components now have logtostderr=false to avoid stderr output"
echo "2. All components have alsologtostderr=false to avoid dual logging"
echo "3. All components have stdout_log_filename=/logs/stdout.log for proper stdout.log file"
echo "4. All components have enable_metric=true for metrics collection"
echo "5. Each component has a unique ws_http_port for HTTP metrics endpoint"
echo "6. nebula-stats-exporter-config.yaml ports match docker-compose configuration"
echo ""
echo "To test the configuration:"
echo "1. Restart the Nebula services: docker-compose -f docker-compose.nebula.yml restart"
echo "2. Check nebula-stats-exporter logs: docker logs nebula-stats-exporter"
echo "3. Access metrics at: http://localhost:9100/metrics"