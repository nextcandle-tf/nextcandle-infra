# =============================================================================
# FastAPI Embeddings Server
# sentence-transformers/paraphrase-multilingual-mpnet-base-v2
# ARM64 (Apple Silicon) + AMD64 호환
# =============================================================================

FROM python:3.11-slim

WORKDIR /app

# 시스템 의존성 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Python 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 앱 코드 복사
COPY main.py .

# 캐시 디렉토리 생성
RUN mkdir -p /app/.cache

# 환경 변수
ENV MODEL_NAME=sentence-transformers/paraphrase-multilingual-mpnet-base-v2
ENV CACHE_DIR=/app/.cache
ENV PYTHONUNBUFFERED=1

# 포트 노출
EXPOSE 8080

# 헬스체크
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# 실행
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
