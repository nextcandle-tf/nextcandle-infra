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
# 볼륨 상태
# ---------------------------------------------------------------------------
check_volumes() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 볼륨${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    docker volume ls --format "table {{.Name}}\t{{.Driver}}"
}

# ---------------------------------------------------------------------------
# 헬스 체크
# ---------------------------------------------------------------------------
health_check() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN} 헬스 체크${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Traefik
    if curl -s http://localhost:8080/ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Traefik${NC} - 정상"
    else
        echo -e "${YELLOW}○ Traefik${NC} - 응답 없음"
    fi

    # Auth Server
    if curl -s http://localhost:3000/api/v1/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Auth Server${NC} - 정상"
    else
        echo -e "${YELLOW}○ Auth Server${NC} - 응답 없음"
    fi

    # PostgreSQL Dev
    if docker exec $(docker ps -q -f name=dev_postgres) pg_isready > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL (dev)${NC} - 정상"
    else
        echo -e "${YELLOW}○ PostgreSQL (dev)${NC} - 응답 없음"
    fi

    # Redis Dev
    if docker exec $(docker ps -q -f name=dev_redis) redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Redis (dev)${NC} - 정상"
    else
        echo -e "${YELLOW}○ Redis (dev)${NC} - 응답 없음"
    fi

    # MinIO
    if curl -s http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        echo -e "${GREEN}✓ MinIO${NC} - 정상"
    else
        echo -e "${YELLOW}○ MinIO${NC} - 응답 없음"
    fi

    # Prometheus
    if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Prometheus${NC} - 정상"
    else
        echo -e "${YELLOW}○ Prometheus${NC} - 응답 없음"
    fi

    # Grafana
    if curl -s http://localhost:23000/api/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Grafana${NC} - 정상"
    else
        echo -e "${YELLOW}○ Grafana${NC} - 응답 없음"
    fi

    # cAdvisor
    if curl -s http://localhost:8081/healthz > /dev/null 2>&1; then
        echo -e "${GREEN}✓ cAdvisor${NC} - 정상"
    else
        echo -e "${YELLOW}○ cAdvisor${NC} - 응답 없음"
    fi

    # node-exporter
    if curl -s http://localhost:9100/metrics > /dev/null 2>&1; then
        echo -e "${GREEN}✓ node-exporter${NC} - 정상"
    else
        echo -e "${YELLOW}○ node-exporter${NC} - 응답 없음"
    fi

    # Redis exporter
    if curl -s http://localhost:9121/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Redis exporter${NC} - 정상"
    else
        echo -e "${YELLOW}○ Redis exporter${NC} - 응답 없음"
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
        check_volumes
    fi

    health_check
    echo ""
}

main "$@"
