# NextCandle Infrastructure

Docker Swarm 기반 컨테이너 오케스트레이션 인프라입니다.

## 아키텍처

```
Cloudflare Edge → cloudflared → Traefik v3.6 → 서비스
                                    ↓
         ┌──────────────────────────┼──────────────────────────┐
         ↓                          ↓                          ↓
    dev Stack                  stg Stack                  prod Stack
  (PostgreSQL 17)           (PostgreSQL 17)           (PostgreSQL 17)
    (Redis 7.4)          (Redis 7.4, Nginx Web)   (Redis 7.4, Nginx Web)
                                    ↓
                              shared Stack
    (MinIO, Prometheus, Grafana, n8n, Loki, Promtail, cAdvisor, node-exporter)
```

## 전제 조건

- Docker 24.x+
- Docker Swarm 모드
- yq (YAML 프로세서)

```bash
# Docker Swarm 초기화
docker swarm init

# yq 설치 (macOS)
brew install yq

# yq 설치 (Linux)
# https://github.com/mikefarah/yq#install
```

## 빠른 시작

```bash
# 1. 설정 파일 복사
cp .env.example .env

# 2. Cloudflare Tunnel 토큰 설정
# .env 파일에서 CLOUDFLARE_TUNNEL_TOKEN 값 입력
# https://one.dash.cloudflare.com/ → Access → Tunnels

# 3. 시작
./scripts/start.sh dev
```

## 스택 구성

| 스택 | 파일 | 서비스 |
|------|------|--------|
| **core** | `docker-compose.yml` | Traefik v3.6, cloudflared |
| **dev** | `stacks/dev.yml` | PostgreSQL 17, Redis 7.4 |
| **stg** | `stacks/stg.yml` | PostgreSQL 17, Redis 7.4, Nginx |
| **prod** | `stacks/prod.yml` | PostgreSQL 17, Redis 7.4, Nginx |
| **shared** | `stacks/shared.yml` | MinIO, Grafana, Prometheus, n8n, Loki, ... |

## 명령어

```bash
# 시작
./scripts/start.sh       # 전체 시작
./scripts/start.sh dev   # dev 환경만
./scripts/start.sh stg   # stg 환경만
./scripts/start.sh prod  # prod 환경만
./scripts/start.sh shared   # 공유 서비스만

# 중지
./scripts/stop.sh

# 상태 확인
./scripts/status.sh

# Docker Swarm 직접 제어
docker stack ls                    # 스택 목록
docker stack services dev          # dev 스택 서비스
docker service logs dev_postgres   # 서비스 로그
```

## 서비스 접근

### 로컬 포트

| 서비스 | 포트 |
|--------|------|
| Traefik Dashboard | 8080 |
| PostgreSQL Dev/Stg/Prod | 5432/5433/5434 |
| Redis Dev/Stg/Prod | 6379/6380/6381 |
| MinIO API/Console | 9000/9001 |
| Grafana | 23000 |
| Prometheus | 9090 |

### 도메인

| 서비스 | URL |
|--------|-----|
| Stg Web | stg.nextcandle.io |
| Prod Web | www.nextcandle.io |
| n8n | n8n.nextcandle.io |
| Grafana | grafana.nextcandle.io |
| MinIO | s3.nextcandle.io / minio.nextcandle.io |

## 환경 변수

`.env` 파일에서 설정:

| 변수 | 설명 |
|------|------|
| `PROJECT_NAME` | 프로젝트 이름 |
| `DOMAIN_DEV` | dev 환경 도메인 |
| `DOMAIN_STG` | stg 환경 도메인 |
| `DOMAIN_PROD` | prod 환경 도메인 |
| `CLOUDFLARE_TUNNEL_TOKEN` | Cloudflare Tunnel 토큰 |

## Secret 관리

DB 비밀번호 등은 `secrets/secrets.yml`에서 관리되며, 첫 시작 시 자동 생성됩니다.

```bash
# Secret 재생성
docker stack rm dev core shared
docker secret rm $(docker secret ls -q)
rm secrets/secrets.yml
./scripts/start.sh dev
```

## 디렉토리 구조

```
.
├── docker-compose.yml        # Core 스택
├── stacks/                   # 환경별 스택
├── configs/                  # 서비스 설정
├── scripts/                  # 관리 스크립트
├── secrets/                  # 민감 정보 (git 미추적)
└── .env                      # 환경 변수 (git 미추적)
```

## 주의사항

### Docker Swarm 볼륨 마운트
상대 경로 볼륨 마운트가 작동하지 않습니다. 절대 경로를 사용하세요.

```yaml
# ❌ 상대 경로 - 작동 안 함
volumes:
  - ../html:/usr/share/nginx/html:ro

# ✅ 절대 경로
volumes:
  - /absolute/path/to/html:/usr/share/nginx/html:ro
```

## 라이선스

MIT
