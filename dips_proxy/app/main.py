"""ドローンログ DIPS 2.0 API Proxy — FastAPI アプリケーション"""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.dips_client import DipsClient
from app.api.router import get_dips_client
from app.api.router import router as dips_router
from app.auth.router import get_token_store
from app.auth.router import router as auth_router
from app.auth.token_store import TokenStore
from app.config import get_settings

# ログ設定
settings = get_settings()
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """起動時に TokenStore / DipsClient を初期化し、DI に注入する"""
    store = TokenStore(
        encryption_key=settings.token_encryption_key,
        storage_path="data/tokens.enc",
    )
    client = DipsClient(settings, store)

    # FastAPI の Depends で取得できるように差し替え
    auth_router.dependencies = []
    dips_router.dependencies = []

    _app.dependency_overrides[get_token_store] = lambda: store
    _app.dependency_overrides[get_dips_client] = lambda: client

    logger.info(
        "DIPS Proxy 起動 (env=%s, origins=%s)",
        settings.dips_env.value,
        settings.cors_origin_list,
    )
    yield
    logger.info("DIPS Proxy シャットダウン")


app = FastAPI(
    title="DIPS 2.0 API Proxy",
    description="ドローンログ用 DIPS 2.0 API 中継サーバー",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS 設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# ルーター登録
app.include_router(auth_router)
app.include_router(dips_router)


@app.get("/health")
async def health() -> dict[str, str]:
    """ヘルスチェック"""
    return {"status": "ok", "env": settings.dips_env.value}
