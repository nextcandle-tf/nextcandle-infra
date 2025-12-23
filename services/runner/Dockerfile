# =============================================================================
# GitHub Actions Self-hosted Runner
# =============================================================================
# Ubuntu 24.04 기반 Self-hosted Runner
# Docker CLI, Node.js 24, pnpm 포함
#
# 빌드:
#   docker build -t ghcr.io/m16khb/github-runner:latest .
# =============================================================================

FROM ubuntu:24.04

ARG RUNNER_VERSION=2.330.0
ARG TARGETARCH

LABEL maintainer="m16khb"
LABEL description="GitHub Actions Self-hosted Runner for Docker Swarm"

# 환경 변수
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_ALLOW_RUNASROOT=1

# 기본 패키지 + libicu (dotnet 의존성) 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    jq \
    unzip \
    zip \
    gnupg \
    lsb-release \
    sudo \
    libicu74 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI 설치
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Node.js 24 설치
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# pnpm 설치
RUN corepack enable && corepack prepare pnpm@latest --activate

# GitHub Actions Runner 설치
WORKDIR /home/runner

RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "x64") \
    && curl -fsSL -o actions-runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz" \
    && tar xzf actions-runner.tar.gz \
    && rm actions-runner.tar.gz \
    && ./bin/installdependencies.sh

# 엔트리포인트 스크립트
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
