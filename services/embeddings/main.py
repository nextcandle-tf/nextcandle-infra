"""
FastAPI Embeddings Server
sentence-transformers/paraphrase-multilingual-mpnet-base-v2 모델 서빙
OpenAI API 호환 엔드포인트 제공
"""

import os
import time
from typing import Union
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import json
import base64
import struct

# 환경 변수
MODEL_NAME = os.getenv("MODEL_NAME", "sentence-transformers/paraphrase-multilingual-mpnet-base-v2")
CACHE_DIR = os.getenv("CACHE_DIR", "/app/.cache")

# 전역 모델 변수
model: SentenceTransformer = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """앱 시작 시 모델 로드"""
    global model
    print(f"Loading model: {MODEL_NAME}")
    start = time.time()
    model = SentenceTransformer(MODEL_NAME, cache_folder=CACHE_DIR)
    print(f"Model loaded in {time.time() - start:.2f}s")
    yield
    print("Shutting down...")


app = FastAPI(
    title="Embeddings API",
    description="OpenAI 호환 임베딩 API (sentence-transformers)",
    version="1.0.0",
    lifespan=lifespan
)


# --- Request/Response Models ---

class EmbeddingRequest(BaseModel):
    """OpenAI 호환 임베딩 요청 (n8n 호환)"""
    input: Union[str, list[str], None] = None  # OpenAI 표준
    documents: Union[list[str], None] = None   # n8n에서 보낼 수 있는 형식
    model: str = MODEL_NAME
    dimensions: Union[int, None] = None  # n8n이 보낼 수 있는 파라미터
    encoding_format: Union[str, None] = None  # OpenAI 호환


class EmbeddingData(BaseModel):
    """임베딩 데이터"""
    object: str = "embedding"
    embedding: Union[list[float], str]  # float 배열 또는 base64 문자열
    index: int


class EmbeddingResponse(BaseModel):
    """OpenAI 호환 임베딩 응답"""
    object: str = "list"
    data: list[EmbeddingData]
    model: str
    usage: dict


# --- Endpoints ---

@app.post("/v1/embeddings", response_model=EmbeddingResponse)
async def create_embeddings(request: EmbeddingRequest):
    """
    OpenAI 호환 임베딩 생성 API

    n8n에서 사용 시:
    - Embeddings OpenAI 노드 사용
    - Base URL: http://embeddings:8080/v1
    - API Key: 아무 값 (검증 안 함)
    """
    # 디버그 로깅 - 전체 요청 파라미터
    print(f"[DEBUG] === REQUEST ===")
    print(f"[DEBUG] model={request.model}")
    print(f"[DEBUG] dimensions={request.dimensions}")
    print(f"[DEBUG] encoding_format={request.encoding_format}")
    print(f"[DEBUG] input type={type(request.input)}, documents type={type(request.documents)}")

    # dimensions 경고
    if request.dimensions:
        print(f"[WARN] dimensions={request.dimensions} 요청됨, 하지만 이 서버는 항상 768차원을 반환합니다!")

    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    # 입력 정규화 (input 또는 documents 사용)
    raw_input = request.input or request.documents
    if raw_input is None:
        raise HTTPException(status_code=400, detail="Either 'input' or 'documents' is required")

    texts = [raw_input] if isinstance(raw_input, str) else raw_input
    print(f"[DEBUG] Processing {len(texts)} texts, first: {texts[0][:80] if texts else 'empty'}...")

    if not texts:
        raise HTTPException(status_code=400, detail="Input cannot be empty")

    # 임베딩 생성
    start = time.time()
    embeddings = model.encode(texts, normalize_embeddings=True)
    elapsed = time.time() - start

    # 응답 생성 (encoding_format에 따라 분기)
    use_base64 = request.encoding_format == "base64"

    def encode_embedding(emb):
        """임베딩을 float 배열 또는 base64로 인코딩"""
        float_list = emb.tolist()
        if use_base64:
            # OpenAI 호환 base64: little-endian float32
            binary = struct.pack(f'<{len(float_list)}f', *float_list)
            return base64.b64encode(binary).decode('ascii')
        return float_list

    data = [
        EmbeddingData(embedding=encode_embedding(emb), index=i)
        for i, emb in enumerate(embeddings)
    ]

    # 응답 로깅
    dim = len(embeddings[0]) if len(embeddings) > 0 else 0
    print(f"[DEBUG] Response: {len(data)} embeddings, dim={dim}, encoding={request.encoding_format or 'float'}")

    return EmbeddingResponse(
        data=data,
        model=MODEL_NAME,
        usage={
            "prompt_tokens": sum(len(t.split()) for t in texts),
            "total_tokens": sum(len(t.split()) for t in texts),
            "elapsed_ms": int(elapsed * 1000)
        }
    )


@app.post("/embed")
async def embed_simple(request: EmbeddingRequest):
    """간단한 임베딩 API (n8n HTTP Request용)"""
    texts = [request.input] if isinstance(request.input, str) else request.input
    embeddings = model.encode(texts, normalize_embeddings=True)
    return {"embeddings": embeddings.tolist()}


@app.get("/health")
async def health():
    """헬스 체크"""
    return {
        "status": "ok",
        "model": MODEL_NAME,
        "model_loaded": model is not None
    }


@app.get("/")
async def root():
    """API 정보"""
    return {
        "name": "Embeddings API",
        "model": MODEL_NAME,
        "endpoints": {
            "embeddings": "POST /v1/embeddings (OpenAI 호환)",
            "simple": "POST /embed (간단한 API)",
            "health": "GET /health"
        }
    }


@app.get("/v1/models")
async def list_models():
    """OpenAI 호환 모델 목록 (Credentials 연결 테스트용)"""
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_NAME,
                "object": "model",
                "created": 1700000000,
                "owned_by": "sentence-transformers"
            }
        ]
    }


@app.get("/v1/models/{model_id}")
async def get_model(model_id: str):
    """OpenAI 호환 모델 정보"""
    return {
        "id": MODEL_NAME,
        "object": "model",
        "created": 1700000000,
        "owned_by": "sentence-transformers"
    }
