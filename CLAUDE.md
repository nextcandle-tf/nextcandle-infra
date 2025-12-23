# CLAUDE.md - NextCandle Infrastructure

이 문서는 Claude Code가 이 프로젝트를 이해하고 효과적으로 작업하기 위한 컨텍스트를 제공합니다.

## 프로젝트 개요

Docker Swarm 기반 멀티 환경 인프라 구성 저장소입니다. Cloudflare Tunnel을 통한 Zero Trust 네트워킹으로 외부에 포트를 노출하지 않습니다.

### 핵심 특징

- **멀티 환경**: dev, stg, prod 환경 분리
- **Zero Trust**: Cloudflare Tunnel로 외부 접근
- **자동화**: 비밀번호 자동 생성, Docker Secret 관리
- **모니터링**: Prometheus + Grafana + Loki 스택

## 디렉토리 구조

```
nextcandle-infra/
├── docker-compose.yml          # Core 스택 (Traefik, cloudflared)
├── stacks/
│   ├── dev.yml                 # 개발 환경 (PostgreSQL, Redis)
│   ├── stg.yml                 # 스테이징 환경
│   ├── prod.yml                # 프로덕션 환경
│   ├── shared.yml              # 공유 서비스 (MinIO, 모니터링, n8n)
│   └── runner.yml              # GitHub Runner (별도 라이프사이클)
├── configs/
│   ├── traefik/dynamic.yml     # Traefik 라우팅 설정
│   ├── postgres/               # PostgreSQL 설정 (dev용, prod용)
│   ├── prometheus/             # Prometheus scrape 설정
│   ├── loki/                   # Loki 로그 저장 설정
│   ├── promtail/               # Promtail 로그 수집 설정
│   └── grafana/provisioning/   # Grafana 데이터소스/대시보드
├── scripts/
│   ├── start.sh                # 인프라 시작 (의존성 확인, Secret 생성, 스택 배포)
│   ├── stop.sh                 # 인프라 중지
│   └── status.sh               # 상태 확인
├── secrets/
│   ├── secrets.yml.example     # Secret 템플릿
│   └── secrets.yml             # 실제 Secret (git 제외, 자동 생성)
├── services/
│   └── runner/entrypoint.sh    # GitHub Runner 엔트리포인트
├── .data/                      # 데이터 저장소 (git 제외)
├── .env.example                # 환경변수 템플릿
└── .env                        # 환경변수 (git 제외)
```

## 주요 파일 설명

### 스택 파일

| 파일 | 역할 | 서비스 |
|------|------|--------|
| `docker-compose.yml` | Core 스택 | Traefik v3.6, cloudflared |
| `stacks/dev.yml` | 개발 DB | PostgreSQL 17 + pgvector, Redis 7.4 |
| `stacks/stg.yml` | 스테이징 DB | PostgreSQL 17 + pgvector, Redis 7.4 |
| `stacks/prod.yml` | 프로덕션 DB | PostgreSQL 17 + pgvector (2배 리소스), Redis 7.4 |
| `stacks/shared.yml` | 공유 서비스 | MinIO, Prometheus, Grafana, n8n, Loki, Promtail, redis-exporter, cAdvisor, node-exporter |
| `stacks/runner.yml` | CI/CD | GitHub Runner (1시간 토큰 만료로 분리) |

### 스크립트

| 파일 | 역할 | 주요 함수 |
|------|------|----------|
| `scripts/start.sh` | 전체 배포 | `check_dependencies`, `init_swarm`, `create_secrets`, `deploy_stacks` |
| `scripts/stop.sh` | 스택 중지 | 선택적 중지, `--cleanup` 옵션 |
| `scripts/status.sh` | 상태 확인 | 헬스체크, `-v` 상세 모드 |

### 설정 파일

| 파일 | 역할 |
|------|------|
| `configs/traefik/dynamic.yml` | 보안 헤더, Rate Limit, Dashboard 인증 |
| `configs/postgres/postgresql.conf` | dev/stg PostgreSQL 설정 |
| `configs/postgres/postgresql-prod.conf` | prod PostgreSQL 설정 (병렬 쿼리, 더 큰 버퍼) |
| `configs/prometheus/prometheus.yml` | Scrape 대상 정의 (Traefik, MinIO, exporters, 애플리케이션 서비스) |
| `configs/loki/loki-config.yml` | 로그 저장 (7일 보관, TSDB) |
| `configs/promtail/promtail-config.yml` | Docker 로그 수집, Swarm 라벨 추출 |

## 코딩 규칙 및 컨벤션

### Docker Compose 작성

```yaml
# 서비스 정의 순서
services:
  service-name:
    image: <image>:<version>       # 명시적 버전 태그
    environment:                   # Secret은 _FILE 접미사
      POSTGRES_PASSWORD_FILE: /run/secrets/password
    volumes:
      - ../.data/<path>:/data      # 상대 경로 (.data 하위)
    networks:
      - internal                   # 내부 통신용
      - traefik-public             # 외부 노출 필요 시
    secrets:
      - secret_name
    deploy:
      mode: replicated             # 또는 global (exporters)
      replicas: 1
      labels:                      # Traefik 라우팅
        - traefik.enable=true
        - traefik.http.routers.<name>.rule=Host(`<domain>`)
      resources:
        limits:
          cpus: '0.50'
          memory: 256M
        reservations:
          cpus: '0.10'
          memory: 64M
      restart_policy:
        condition: on-failure
        delay: 5s
    healthcheck:                   # 헬스체크 필수
      test: ["CMD", "..."]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Secret 관리

1. **자동 생성 Secret** (`secrets.yml`):
   - `openssl rand -base64 16`으로 랜덤 생성
   - `scripts/start.sh`에서 Docker Secret 등록

2. **외부 토큰** (`.env`):
   - Cloudflare Tunnel, GitHub Runner 등
   - 수동 입력 필요

3. **컨테이너 접근**:
   ```yaml
   # 환경변수로 파일 경로 지정
   environment:
     POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password

   # 또는 쉘에서 읽기
   command:
     - |
       export PASSWORD=$$(cat /run/secrets/password)
       exec myapp
   ```

### 네트워크

- `traefik-public`: 외부 트래픽 라우팅 (전체 스택 공유)
- `internal`: 스택 내부 통신 (스택별 격리)

### 리소스 할당 패턴

| 서비스 유형 | CPU | Memory |
|------------|-----|--------|
| 리버스 프록시 | 0.10-0.50 | 64M-256M |
| 데이터베이스 (dev/stg) | 0.10-0.50 | 256M-512M |
| 데이터베이스 (prod) | 0.20-1.00 | 512M-1G |
| 모니터링 | 0.05-0.30 | 64M-256M |
| Global exporters | 0.05-0.20 | 32M-128M |

## 자주 사용하는 명령어

### 인프라 관리

```bash
# 시작
./scripts/start.sh all          # 전체 (runner 제외)
./scripts/start.sh dev          # Core + dev만
./scripts/start.sh runner       # runner만 (별도)

# 중지
./scripts/stop.sh all
./scripts/stop.sh --cleanup     # 미사용 리소스 정리

# 상태
./scripts/status.sh
./scripts/status.sh -v          # 상세
```

### Docker Swarm

```bash
# 스택
docker stack ls
docker stack services <stack>
docker stack rm <stack>

# 서비스
docker service ls
docker service logs <service>
docker service logs -f <service>  # 실시간
docker service ps <service>       # 태스크 상태
docker service scale <service>=N

# Secret
docker secret ls
docker secret rm <name>
```

### 디버깅

```bash
# 서비스가 시작 안 될 때
docker service ps <service> --no-trunc
docker service logs <service> --tail 100

# 네트워크 문제
docker network inspect traefik-public

# Secret 문제
docker secret ls
# Secret 값 확인은 불가 (보안)
```

## 작업 시 주의사항

### 볼륨 경로

- 상대 경로 사용: `../.data/<path>`
- **프로젝트 루트에서 실행 필수**
- `scripts/` 디렉토리에서 실행하면 경로 깨짐

### Secret 변경

```bash
# Secret은 불변이므로 삭제 후 재생성
docker secret rm <secret_name>
./scripts/start.sh
```

### runner 스택

- `RUNNER_TOKEN`은 1시간 만료
- shared 스택과 분리된 이유
- 토큰 갱신 시 runner 스택만 재배포

### 환경별 차이

| 항목 | dev/stg | prod |
|------|---------|------|
| PostgreSQL 설정 | `postgresql.conf` | `postgresql-prod.conf` |
| 리소스 | 기본 | 2배 |
| restart max_attempts | 3 | 5 |
| Redis appendfsync | 기본 | everysec |

## 새 서비스 추가 시

1. **스택 파일 수정** (`stacks/<env>.yml`)
2. **Secret 추가** (`secrets.yml` 및 `start.sh`의 `create_secrets`)
3. **Prometheus 추가** (메트릭 필요 시 `prometheus.yml`)
4. **Traefik 라벨** (외부 노출 필요 시)

### 예시: 새 서비스 추가

```yaml
# stacks/shared.yml
services:
  new-service:
    image: myimage:v1.0
    environment:
      SECRET_FILE: /run/secrets/new_service_secret
    networks:
      - internal
      - traefik-public
    secrets:
      - new_service_secret
    deploy:
      mode: replicated
      replicas: 1
      labels:
        - traefik.enable=true
        - traefik.http.routers.new-service.rule=Host(`new-service.nextcandle.io`)
        - traefik.http.services.new-service.loadbalancer.server.port=8080
      resources:
        limits:
          cpus: '0.50'
          memory: 256M
        reservations:
          cpus: '0.10'
          memory: 64M
      restart_policy:
        condition: on-failure
        delay: 5s
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

secrets:
  new_service_secret:
    external: true
```

## 트러블슈팅 가이드

### 서비스 시작 실패

```bash
# 1. 태스크 상태 확인
docker service ps <service> --no-trunc

# 2. 로그 확인
docker service logs <service>

# 3. 일반적인 원인
# - Secret 누락: docker secret ls
# - 네트워크 누락: docker network ls
# - 이미지 pull 실패: docker pull <image>
# - 리소스 부족: docker node ls
```

### Secret 관련

```bash
# Secret 목록 확인
docker secret ls

# Secret 재생성
docker stack rm <stack>
docker secret rm <secret_name>
./scripts/start.sh
```

### 네트워크 관련

```bash
# traefik-public 확인
docker network inspect traefik-public

# 없으면 생성
docker network create --driver overlay --attachable traefik-public
```

## 연관 프로젝트

이 인프라는 NextCandle 프로젝트의 다음 서비스를 지원합니다:

- **PostgreSQL**: 애플리케이션 데이터베이스 (pgvector로 벡터 검색)
- **Redis**: 세션/캐시 저장소
- **MinIO**: 파일 업로드 (S3 호환)
- **n8n**: 워크플로우 자동화
- **Grafana**: 모니터링 대시보드

### 애플리케이션 서비스 통합

Prometheus는 이 인프라에 포함되지 않은 애플리케이션 서비스도 스크랩하도록 사전 구성되어 있습니다:
- `dev_auth`: 인증 서비스 (별도 배포)

애플리케이션 서비스는 이 인프라의 `traefik-public` 네트워크에 연결하여 통합됩니다.
