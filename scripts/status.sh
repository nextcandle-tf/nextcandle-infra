#!/bin/bash
# =============================================================================
# Docker Swarm 인프라 상태 확인 스크립트
# =============================================================================

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Swarm 상태 확인
# ---------------------------------------------------------------------------
check_swarm() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} Docker Swarm 상태${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q 'active'; then
        echo -e "${GREEN}✓ Swarm 활성화됨${NC}"
        docker node ls
    else
        echo -e "${RED}✗ Swarm 비활성화${NC}"
    fi
}

# ---------------------------------------------------------------------------
# 스택 상태
# ---------------------------------------------------------------------------
check_stacks() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 스택 목록${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    docker stack ls
}

# ---------------------------------------------------------------------------
# 서비스 상태
# ---------------------------------------------------------------------------
check_services() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 서비스 상태${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    docker service ls --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}"
}

# ---------------------------------------------------------------------------
# 컨테이너 상태
# ---------------------------------------------------------------------------
check_containers() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 실행 중인 컨테이너${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# ---------------------------------------------------------------------------
# 네트워크 상태
# ---------------------------------------------------------------------------
check_networks() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} Overlay 네트워크${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    docker network ls --filter driver=overlay --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
}

# ---------------------------------------------------------------------------
# 데이터 디렉토리 상태
# ---------------------------------------------------------------------------
check_data_dirs() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 데이터 디렉토리${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local data_dir="$(dirname "$script_dir")/.data"

    if [ -d "$data_dir" ]; then
        du -sh "$data_dir"/* 2>/dev/null | sort -hr
    else
        echo -e "${YELLOW}데이터 디렉토리가 없습니다: $data_dir${NC}"
    fi
}

# ---------------------------------------------------------------------------
# 헬스 체크 (Docker exec로 내부 상태 확인)
# ---------------------------------------------------------------------------
health_check() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 헬스 체크${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Traefik (포트 노출됨)
    if curl -s http://localhost:8080/ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Traefik${NC} - 정상"
    else
        echo -e "${YELLOW}○ Traefik${NC} - 응답 없음"
    fi

    # Cloudflared (서비스 상태로 확인)
    local cf_container=$(docker ps -q -f name=core_cloudflared 2>/dev/null)
    if [ -n "$cf_container" ]; then
        echo -e "${GREEN}✓ Cloudflared${NC} - 실행 중"
    else
        echo -e "${YELLOW}○ Cloudflared${NC} - 실행 안됨"
    fi

    # PostgreSQL Dev (포트 노출됨)
    local pg_dev=$(docker ps -q -f name=dev_postgres 2>/dev/null)
    if [ -n "$pg_dev" ] && docker exec $pg_dev pg_isready > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL (dev)${NC} - 정상"
    else
        echo -e "${YELLOW}○ PostgreSQL (dev)${NC} - 응답 없음"
    fi

    # PostgreSQL Stg
    local pg_stg=$(docker ps -q -f name=stg_postgres 2>/dev/null)
    if [ -n "$pg_stg" ] && docker exec $pg_stg pg_isready > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL (stg)${NC} - 정상"
    else
        echo -e "${YELLOW}○ PostgreSQL (stg)${NC} - 응답 없음"
    fi

    # PostgreSQL Prod
    local pg_prod=$(docker ps -q -f name=prod_postgres 2>/dev/null)
    if [ -n "$pg_prod" ] && docker exec $pg_prod pg_isready > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL (prod)${NC} - 정상"
    else
        echo -e "${YELLOW}○ PostgreSQL (prod)${NC} - 응답 없음"
    fi

    # Redis Dev (포트 노출됨)
    local redis_dev=$(docker ps -q -f name=dev_redis 2>/dev/null)
    if [ -n "$redis_dev" ] && docker exec $redis_dev redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Redis (dev)${NC} - 정상"
    else
        echo -e "${YELLOW}○ Redis (dev)${NC} - 응답 없음"
    fi

    # MinIO (docker exec로 확인)
    local minio=$(docker ps -q -f name=shared_minio 2>/dev/null)
    if [ -n "$minio" ] && docker exec $minio mc ready local > /dev/null 2>&1; then
        echo -e "${GREEN}✓ MinIO${NC} - 정상"
    else
        echo -e "${YELLOW}○ MinIO${NC} - 응답 없음"
    fi

    # Prometheus (Traefik 경유)
    if curl -s http://prometheus.localhost/-/healthy > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Prometheus${NC} - 정상"
    else
        echo -e "${YELLOW}○ Prometheus${NC} - 응답 없음"
    fi

    # Grafana (컨테이너 상태로 확인)
    local grafana=$(docker ps -q -f name=shared_grafana 2>/dev/null)
    if [ -n "$grafana" ]; then
        echo -e "${GREEN}✓ Grafana${NC} - 실행 중"
    else
        echo -e "${YELLOW}○ Grafana${NC} - 실행 안됨"
    fi

    # n8n (컨테이너 상태로 확인)
    local n8n=$(docker ps -q -f name=shared_n8n 2>/dev/null)
    if [ -n "$n8n" ]; then
        echo -e "${GREEN}✓ n8n${NC} - 실행 중"
    else
        echo -e "${YELLOW}○ n8n${NC} - 실행 안됨"
    fi

    # Loki (컨테이너 상태로 확인)
    local loki=$(docker ps -q -f name=shared_loki 2>/dev/null)
    if [ -n "$loki" ]; then
        echo -e "${GREEN}✓ Loki${NC} - 실행 중"
    else
        echo -e "${YELLOW}○ Loki${NC} - 실행 안됨"
    fi
}

# ---------------------------------------------------------------------------
# 메인
# ---------------------------------------------------------------------------
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║           Docker Swarm Infrastructure - Status                     ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"

    check_swarm
    check_stacks
    check_services

    if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
        check_containers
        check_networks
        check_data_dirs
    fi

    health_check
    echo ""
}

main "$@"
