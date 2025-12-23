#!/bin/bash
# =============================================================================
# Docker Swarm 인프라 시작 스크립트
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_DIR="$(dirname "$SCRIPT_DIR")"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---------------------------------------------------------------------------
# 의존성 확인
# ---------------------------------------------------------------------------
check_dependencies() {
    if ! command -v yq &> /dev/null; then
        log_error "yq가 설치되어 있지 않습니다."
        log_info "설치 방법: brew install yq (macOS) 또는 https://github.com/mikefarah/yq"
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        log_error "docker가 설치되어 있지 않습니다."
        exit 1
    fi

    # Docker 소켓 접근 권한 확인
    if ! docker info &> /dev/null; then
        log_error "Docker에 접근할 수 없습니다."
        log_info "해결 방법: sudo usermod -aG docker \$USER && newgrp docker"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# YAML에서 값 추출 (yq 사용)
# ---------------------------------------------------------------------------
get_yaml_value() {
    local yaml_file=$1
    local path=$2  # 예: postgres.dev.password
    yq ".${path}" "$yaml_file" 2>/dev/null | grep -v '^null$'
}

# ---------------------------------------------------------------------------
# 랜덤 비밀번호 생성
# ---------------------------------------------------------------------------
generate_password() {
    openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16
}

# ---------------------------------------------------------------------------
# htpasswd 형식 생성 (Apache MD5)
# ---------------------------------------------------------------------------
generate_htpasswd() {
    local user=$1
    local pass=$2
    # OpenSSL로 Apache MD5 해시 생성
    local salt=$(openssl rand -base64 8 | tr -dc 'a-zA-Z0-9' | head -c 8)
    local hash=$(openssl passwd -apr1 -salt "$salt" "$pass")
    echo "${user}:${hash}"
}

# ---------------------------------------------------------------------------
# Docker Swarm 초기화 확인
# ---------------------------------------------------------------------------
init_swarm() {
    local swarm_state=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
    local is_manager=$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)

    if [ "$swarm_state" = "active" ] && [ "$is_manager" = "true" ]; then
        log_info "Docker Swarm이 이미 활성화되어 있습니다 (Manager)"
    else
        if [ "$swarm_state" = "active" ]; then
            log_warn "Swarm worker 상태 감지. 재초기화 중..."
            docker swarm leave --force 2>/dev/null || true
        fi

        log_info "Docker Swarm 초기화 중..."
        docker swarm init --advertise-addr 127.0.0.1
        log_success "Docker Swarm 초기화 완료"
    fi
}

# ---------------------------------------------------------------------------
# 네트워크 생성
# ---------------------------------------------------------------------------
create_networks() {
    log_info "네트워크 생성 중..."

    if ! docker network ls | grep -q 'traefik-public'; then
        docker network create --driver overlay --attachable traefik-public
        log_success "traefik-public 네트워크 생성됨"
    fi
}

# ---------------------------------------------------------------------------
# 데이터 디렉토리 생성
# ---------------------------------------------------------------------------
create_data_directories() {
    log_info "데이터 디렉토리 확인 중..."

    local data_dir="$SWARM_DIR/.data"
    local dirs=(
        "dev/postgres"
        "dev/redis"
        "stg/postgres"
        "stg/redis"
        "prod/postgres"
        "prod/redis"
        "minio"
        "prometheus"
        "grafana"
        "n8n"
        "loki"
        "promtail"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$data_dir/$dir"
    done

    # .gitignore 생성
    if [ ! -f "$data_dir/.gitignore" ]; then
        cat > "$data_dir/.gitignore" << 'EOF'
# Ignore all data files
*
# But keep this .gitignore
!.gitignore
EOF
    fi

    log_success "데이터 디렉토리 준비 완료: $data_dir"
}

# ---------------------------------------------------------------------------
# Secret 생성 (secrets.yml 기반)
# ---------------------------------------------------------------------------
create_secrets() {
    log_info "Secret 확인 중..."

    local secrets_file="$SWARM_DIR/secrets/secrets.yml"
    local generated_new=false

    mkdir -p "$SWARM_DIR/secrets"

    # secrets.yml 파일이 없으면 자동 생성
    if [ ! -f "$secrets_file" ]; then
        log_warn "secrets.yml 파일이 없습니다. 자동 생성합니다..."

        cat > "$secrets_file" << EOF
# =============================================================================
# Docker Swarm Secrets Configuration
# =============================================================================
# 자동 생성: $(date '+%Y-%m-%d %H:%M:%S')
# Cloudflare Tunnel 토큰은 .env에서 관리합니다.
# =============================================================================

# ---------------------------------------------------------------------------
# PostgreSQL (환경별)
# ---------------------------------------------------------------------------
postgres:
  dev:
    db: nextcandle_dev
    user: dev_user
    password: "$(generate_password)"
  stg:
    db: nextcandle_stg
    user: stg_user
    password: "$(generate_password)"
  prod:
    db: nextcandle_prod
    user: prod_user
    password: "$(generate_password)"

# ---------------------------------------------------------------------------
# Redis (환경별)
# ---------------------------------------------------------------------------
redis:
  dev:
    user: redis_dev_user
    password: "$(generate_password)"
  stg:
    user: redis_stg_user
    password: "$(generate_password)"
  prod:
    user: redis_prod_user
    password: "$(generate_password)"

# ---------------------------------------------------------------------------
# MinIO
# ---------------------------------------------------------------------------
minio:
  root_user: minioadmin
  root_password: "$(generate_password)"

# ---------------------------------------------------------------------------
# Grafana
# ---------------------------------------------------------------------------
grafana:
  admin_user: admin
  admin_password: "$(generate_password)"

# ---------------------------------------------------------------------------
# n8n (공유)
# ---------------------------------------------------------------------------
n8n:
  user: admin
  password: "$(generate_password)"

# ---------------------------------------------------------------------------
# Traefik Dashboard
# ---------------------------------------------------------------------------
traefik:
  dashboard_user: admin
  dashboard_password: "$(generate_password)"
EOF
        chmod 600 "$secrets_file"
        generated_new=true
        log_success "secrets.yml 자동 생성됨 (랜덤 비밀번호)"
    fi

    # secrets.yml에서 Docker Secret 생성
    log_info "Docker Secret 등록 중..."

    # PostgreSQL (환경별)
    for env in dev stg prod; do
        create_secret_from_yaml "${env}_postgres_db" "postgres.${env}.db"
        create_secret_from_yaml "${env}_postgres_user" "postgres.${env}.user"
        create_secret_from_yaml "${env}_postgres_password" "postgres.${env}.password"
    done

    # Redis (환경별)
    for env in dev stg prod; do
        create_secret_from_yaml "${env}_redis_user" "redis.${env}.user"
        create_secret_from_yaml "${env}_redis_password" "redis.${env}.password"
    done

    # MinIO
    create_secret_from_yaml "minio_root_user" "minio.root_user"
    create_secret_from_yaml "minio_root_password" "minio.root_password"

    # Grafana
    create_secret_from_yaml "grafana_admin_user" "grafana.admin_user"
    create_secret_from_yaml "grafana_admin_password" "grafana.admin_password"

    # n8n (공유)
    create_secret_from_yaml "n8n_user" "n8n.user"
    create_secret_from_yaml "n8n_password" "n8n.password"

    # Traefik Dashboard (htpasswd 형식)
    create_traefik_auth_secret

    if [ "$generated_new" = true ]; then
        echo ""
        log_warn "secrets.yml이 자동 생성되었습니다."
        log_warn "Cloudflare Tunnel 토큰을 설정하세요:"
        log_warn "  vim $secrets_file"
    fi

    log_info "Secret 설정 완료"
}

# secrets.yml에서 값을 읽어 Docker Secret 생성
create_secret_from_yaml() {
    local secret_name=$1
    local yaml_path=$2
    local secrets_file="$SWARM_DIR/secrets/secrets.yml"

    # 이미 존재하면 스킵
    if docker secret ls --format '{{.Name}}' | grep -q "^${secret_name}$"; then
        return 0
    fi

    # YAML에서 값 추출
    local value
    value=$(get_yaml_value "$secrets_file" "$yaml_path")

    # 값이 비어있거나 기본값이면 스킵
    if [ -z "$value" ] || [ "$value" = "your-tunnel-token-here" ]; then
        if [[ "$secret_name" == *"tunnel"* ]]; then
            log_warn "$secret_name: 토큰 미설정 (secrets.yml 수정 필요)"
        fi
        return 0
    fi

    # Secret 생성
    echo "$value" | docker secret create "$secret_name" - > /dev/null 2>&1
    log_success "$secret_name Secret 생성됨"
}

# Traefik Dashboard Auth Secret 생성 (htpasswd 형식)
create_traefik_auth_secret() {
    local secret_name="traefik_dashboard_auth"
    local secrets_file="$SWARM_DIR/secrets/secrets.yml"

    # 이미 존재하면 스킵
    if docker secret ls --format '{{.Name}}' | grep -q "^${secret_name}$"; then
        return 0
    fi

    # YAML에서 사용자/비밀번호 추출
    local user=$(get_yaml_value "$secrets_file" "traefik.dashboard_user")
    local pass=$(get_yaml_value "$secrets_file" "traefik.dashboard_password")

    if [ -z "$user" ] || [ -z "$pass" ]; then
        log_warn "$secret_name: traefik 설정 누락 (secrets.yml 수정 필요)"
        return 0
    fi

    # htpasswd 형식으로 Secret 생성
    generate_htpasswd "$user" "$pass" | docker secret create "$secret_name" - > /dev/null 2>&1
    log_success "$secret_name Secret 생성됨 (htpasswd 형식)"
}

# ---------------------------------------------------------------------------
# 스택 배포
# ---------------------------------------------------------------------------
deploy_stacks() {
    log_info "스택 배포 중..."

    cd "$SWARM_DIR"

    # 환경 변수 로드 (.env)
    if [ -f .env ]; then
        set -a
        source .env
        set +a
    fi

    # Cloudflare Tunnel Token 확인
    if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ] && [ "$CLOUDFLARE_TUNNEL_TOKEN" != "your-tunnel-token-here" ]; then
        log_info "Cloudflare Tunnel Token 로드됨"
    else
        log_warn "Cloudflare Tunnel Token이 설정되지 않았습니다 (.env 수정 필요)"
    fi

    # 환경별 스택
    case "${1:-all}" in
        dev)
            log_info "Core 스택 배포 중..."
            docker stack deploy -c docker-compose.yml core
            docker stack deploy -c stacks/dev.yml dev
            ;;
        stg)
            log_info "Core 스택 배포 중..."
            docker stack deploy -c docker-compose.yml core
            docker stack deploy -c stacks/stg.yml stg
            ;;
        prod)
            log_info "Core 스택 배포 중..."
            docker stack deploy -c docker-compose.yml core
            docker stack deploy -c stacks/prod.yml prod
            ;;
        shared)
            log_info "Core 스택 배포 중..."
            docker stack deploy -c docker-compose.yml core
            docker stack deploy -c stacks/shared.yml shared
            ;;
        runner)
            # Runner는 별도 관리 (토큰 1시간 유효, Core 불필요)
            docker stack deploy -c stacks/runner.yml runner
            ;;
        all)
            log_info "Core 스택 배포 중..."
            docker stack deploy -c docker-compose.yml core
            docker stack deploy -c stacks/dev.yml dev
            docker stack deploy -c stacks/stg.yml stg
            docker stack deploy -c stacks/prod.yml prod
            docker stack deploy -c stacks/shared.yml shared
            # runner는 all에서 제외 (토큰 만료 문제)
            log_warn "runner 스택은 별도로 배포하세요: $0 runner"
            ;;
        *)
            log_error "알 수 없는 환경: $1"
            echo "사용법: $0 [dev|stg|prod|shared|runner|all]"
            exit 1
            ;;
    esac

    log_success "스택 배포 완료"
}

# ---------------------------------------------------------------------------
# 상태 확인
# ---------------------------------------------------------------------------
wait_for_services() {
    log_info "서비스 시작 대기 중..."
    sleep 10

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 서비스 상태"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    docker stack ls
    echo ""
    docker service ls
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo ""
    log_success "Docker Swarm 인프라가 시작되었습니다!"
    echo ""
    echo "접근 정보:"
    echo "  - Traefik Dashboard: http://traefik.localhost:8080"
    echo "  - Prometheus:        http://prometheus.localhost (로컬만)"
    echo ""
    echo "공유 서비스 (Cloudflare Tunnel 경유):"
    echo "  - n8n:               https://n8n.nextcandle.io"
    echo "  - MinIO Console:     https://minio.nextcandle.io"
    echo "  - MinIO API:         https://s3.nextcandle.io"
    echo "  - Grafana:           https://grafana.nextcandle.io"
    echo ""
    echo "데이터베이스 (내부 네트워크):"
    echo "  - PostgreSQL Dev:    dev_postgres:5432 (localhost:5432)"
    echo "  - PostgreSQL Stg:    stg_postgres:5432 (localhost:5433)"
    echo "  - PostgreSQL Prod:   prod_postgres:5432 (localhost:5434)"
    echo "  - Redis Dev:         dev_redis:6379 (localhost:6379)"
    echo ""
    echo "데이터 저장: .data/"
    echo "Secret 정보: secrets/secrets.yml"
}

# ---------------------------------------------------------------------------
# 메인
# ---------------------------------------------------------------------------
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║           Docker Swarm Infrastructure - Start                      ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""

    check_dependencies
    init_swarm
    create_networks
    create_data_directories
    create_secrets
    deploy_stacks "${1:-all}"
    wait_for_services
}

main "$@"
