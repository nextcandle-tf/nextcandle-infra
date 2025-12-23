#!/bin/bash
# =============================================================================
# GitHub Actions Self-hosted Runner Entrypoint
# =============================================================================
# Runner 등록, 실행, 정리를 담당
#
# 지원 모드:
#   - Organization-level: GITHUB_REPO 미설정 시 (모든 repo에서 사용 가능)
#   - Repository-level: GITHUB_REPO 설정 시 (특정 repo에서만 사용)
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# 환경 변수 검증
# ---------------------------------------------------------------------------
: "${GITHUB_OWNER:?GITHUB_OWNER is required}"
: "${RUNNER_TOKEN:?RUNNER_TOKEN is required}"

RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,Linux,X64,docker-swarm,pnpm}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-_work}"

# ---------------------------------------------------------------------------
# Runner URL 결정 (Organization vs Repository)
# ---------------------------------------------------------------------------
if [ -z "${GITHUB_REPO}" ]; then
    # Organization-level runner
    RUNNER_URL="https://github.com/${GITHUB_OWNER}"
    RUNNER_SCOPE="Organization"
else
    # Repository-level runner
    RUNNER_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}"
    RUNNER_SCOPE="Repository (${GITHUB_REPO})"
fi

# ---------------------------------------------------------------------------
# 정리 함수 (graceful shutdown)
# ---------------------------------------------------------------------------
cleanup() {
    echo "Graceful shutdown initiated..."

    if [ -f ".runner" ]; then
        echo "Removing runner registration..."
        ./config.sh remove --token "${RUNNER_TOKEN}" || true
    fi

    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

# ---------------------------------------------------------------------------
# Runner 설정
# ---------------------------------------------------------------------------
# .runner 디렉토리 권한 수정 (볼륨 마운트 시 필요)
if [ -d ".runner" ]; then
    chmod 700 .runner
    chown -R $(whoami):$(whoami) .runner 2>/dev/null || true
fi

echo "Configuring GitHub Actions Runner..."
echo "  Scope: ${RUNNER_SCOPE}"
echo "  URL: ${RUNNER_URL}"
echo "  Name: ${RUNNER_NAME}"
echo "  Labels: ${RUNNER_LABELS}"

./config.sh \
    --url "${RUNNER_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --work "${RUNNER_WORKDIR}" \
    --replace \
    --unattended \
    --disableupdate

# ---------------------------------------------------------------------------
# Runner 실행
# ---------------------------------------------------------------------------
echo "Starting GitHub Actions Runner..."
./run.sh &

# 백그라운드 프로세스 대기
wait $!
