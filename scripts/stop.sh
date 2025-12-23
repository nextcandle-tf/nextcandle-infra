#!/bin/bash
# =============================================================================
# Docker Swarm 인프라 중지 스크립트
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# ---------------------------------------------------------------------------
# 스택 제거
# ---------------------------------------------------------------------------
remove_stacks() {
    log_info "스택 제거 중..."

    case "${1:-all}" in
        dev)
            docker stack rm dev 2>/dev/null || true
            ;;
        stg)
            docker stack rm stg 2>/dev/null || true
            ;;
        prod)
            docker stack rm prod 2>/dev/null || true
            ;;
        shared)
            docker stack rm shared 2>/dev/null || true
            ;;
        core)
            docker stack rm core 2>/dev/null || true
            ;;
        all)
            docker stack rm dev 2>/dev/null || true
            docker stack rm stg 2>/dev/null || true
            docker stack rm prod 2>/dev/null || true
            docker stack rm shared 2>/dev/null || true
            docker stack rm core 2>/dev/null || true
            ;;
        *)
            log_warn "알 수 없는 환경: $1"
            echo "사용법: $0 [dev|stg|prod|shared|core|all]"
            exit 1
            ;;
    esac

    log_success "스택 제거 완료"
}

# ---------------------------------------------------------------------------
# 정리 (선택)
# ---------------------------------------------------------------------------
cleanup() {
    if [ "$2" == "--cleanup" ]; then
        log_info "리소스 정리 중..."

        # 사용하지 않는 컨테이너/이미지 정리
        docker system prune -f

        log_success "정리 완료"
    fi
}

# ---------------------------------------------------------------------------
# 메인
# ---------------------------------------------------------------------------
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║           Docker Swarm Infrastructure - Stop                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""

    remove_stacks "${1:-all}"
    cleanup "$@"

    echo ""
    docker stack ls
    echo ""
    log_success "인프라 중지 완료"
}

main "$@"
