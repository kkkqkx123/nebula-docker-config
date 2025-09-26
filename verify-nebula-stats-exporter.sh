#!/bin/bash

# NebulaStats Exporter 验证脚本
# 用于验证 nebula-stats-exporter 是否正常工作

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 是否运行
check_docker() {
    log_info "检查 Docker 运行状态..."
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 未运行，请启动 Docker"
        exit 1
    fi
    log_info "Docker 运行正常"
}

# 检查 Docker Compose 文件
check_compose_file() {
    log_info "检查 Docker Compose 文件..."
    if [ ! -f "docker-compose.nebula.yml" ]; then
        log_error "docker-compose.nebula.yml 文件不存在"
        exit 1
    fi
    log_info "Docker Compose 文件存在"
}

# 检查配置文件
check_config_file() {
    log_info "检查 nebula-stats-exporter 配置文件..."
    if [ ! -f "nebula-stats-exporter-config.yaml" ]; then
        log_error "nebula-stats-exporter-config.yaml 文件不存在"
        exit 1
    fi
    
    # 验证 YAML 格式
    if command -v python3 >/dev/null 2>&1; then
        if ! python3 -c "import yaml; yaml.safe_load(open('nebula-stats-exporter-config.yaml'))" 2>/dev/null; then
            log_error "nebula-stats-exporter-config.yaml YAML 格式错误"
            exit 1
        fi
        log_info "配置文件 YAML 格式正确"
    else
        log_warn "Python3 未安装，跳过 YAML 格式验证"
    fi
}

# 检查网络
check_network() {
    log_info "检查 Docker 网络..."
    if ! docker network ls | grep -q "monitoring"; then
        log_warn "monitoring 网络不存在，创建网络..."
        docker network create monitoring
    fi
    log_info "Docker 网络检查完成"
}

# 启动服务
start_services() {
    log_info "启动 NebulaGraph 服务..."
    docker-compose -f docker-compose.nebula.yml up -d
    
    log_info "等待服务启动..."
    sleep 30
    
    log_info "检查服务状态..."
    docker-compose -f docker-compose.nebula.yml ps
}

# 检查服务健康状态
check_service_health() {
    log_info "检查服务健康状态..."
    
    # 等待所有服务变为 healthy
    local timeout=300
    local start_time=$(date +%s)
    
    while true; do
        local all_healthy=true
        
        # 检查每个服务的健康状态
        for service in graphd metad0 metad1 metad2 storaged0 storaged1 storaged2 nebula-stats-exporter; do
            local status=$(docker-compose -f docker-compose.nebula.yml ps -q $service | xargs docker inspect --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
            
            if [ "$status" != "healthy" ]; then
                log_warn "$service 健康状态: $status"
                all_healthy=false
            else
                log_info "$service 健康状态: $status"
            fi
        done
        
        if [ "$all_healthy" = true ]; then
            log_info "所有服务都已健康"
            break
        fi
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            log_error "等待服务健康超时"
            return 1
        fi
        
        log_info "等待服务健康... (已等待 ${elapsed}s)"
        sleep 10
    done
}

# 测试端口连接
test_port_connections() {
    log_info "测试端口连接..."
    
    # 定义要测试的端口
    declare -A ports=(
        ["graphd"]="19669"
        ["metad0"]="19559"
        ["metad1"]="19559"
        ["metad2"]="19559"
        ["storaged0"]="19779"
        ["storaged1"]="19779"
        ["storaged2"]="19779"
    )
    
    for service in "${!ports[@]}"; do
        local port=${ports[$service]}
        log_info "测试 $service:$port 连接..."
        
        # 在 exporter 容器内测试连接
        if docker exec nebula-stats-exporter curl -f -s "http://$service:$port/stats" >/dev/null 2>&1; then
            log_info "$service:$port 连接成功"
        else
            log_error "$service:$port 连接失败"
            return 1
        fi
    done
}

# 测试 exporter 指标
test_exporter_metrics() {
    log_info "测试 nebula-stats-exporter 指标..."
    
    # 测试本地指标
    if curl -f -s "http://localhost:9100/metrics" >/dev/null 2>&1; then
        log_info "nebula-stats-exporter 本地指标正常"
    else
        log_error "nebula-stats-exporter 本地指标异常"
        return 1
    fi
    
    # 测试容器内指标
    if docker exec nebula-stats-exporter curl -f -s "http://localhost:9100/metrics" >/dev/null 2>&1; then
        log_info "nebula-stats-exporter 容器内指标正常"
    else
        log_error "nebula-stats-exporter 容器内指标异常"
        return 1
    fi
}

# 检查日志
check_logs() {
    log_info "检查 nebula-stats-exporter 日志..."
    
    local logs=$(docker-compose -f docker-compose.nebula.yml logs nebula-stats-exporter)
    
    if echo "$logs" | grep -q "connection refused"; then
        log_error "发现 connection refused 错误"
        echo "$logs" | tail -20
        return 1
    fi
    
    if echo "$logs" | grep -q "Start collect"; then
        log_info "nebula-stats-exporter 正在收集指标"
    fi
    
    if echo "$logs" | grep -q "Collect.*Metrics"; then
        log_info "nebula-stats-exporter 正在收集服务指标"
    fi
}

# 显示状态
show_status() {
    log_info "显示当前状态..."
    echo "=========================================="
    docker-compose -f docker-compose.nebula.yml ps
    echo "=========================================="
    
    log_info "nebula-stats-exporter 最近日志："
    docker-compose -f docker-compose.nebula.yml logs --tail=10 nebula-stats-exporter
    echo "=========================================="
}

# 清理函数
cleanup() {
    log_info "清理临时资源..."
    # 可以在这里添加清理逻辑
}

# 主函数
main() {
    log_info "开始验证 nebula-stats-exporter..."
    
    # 设置错误处理
    trap cleanup EXIT
    
    # 执行检查步骤
    check_docker
    check_compose_file
    check_config_file
    check_network
    start_services
    check_service_health
    test_port_connections
    test_exporter_metrics
    check_logs
    show_status
    
    log_info "验证完成！nebula-stats-exporter 运行正常"
}

# 如果脚本被直接执行（而不是被 source）
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi