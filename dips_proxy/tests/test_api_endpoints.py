"""API エンドポイントのスモークテスト"""

import pytest
from cryptography.fernet import Fernet
from httpx import ASGITransport, AsyncClient

from app.api.dips_client import DipsClient
from app.api.router import get_dips_client
from app.auth.router import get_token_store
from app.auth.token_store import TokenStore
from app.config import Settings, get_settings
from app.main import app


@pytest.fixture
def settings() -> Settings:
    return Settings(
        dips_client_id="test_id",
        dips_client_secret="test_secret",
        cors_origins="http://localhost:8080",
        token_encryption_key=Fernet.generate_key().decode(),
    )


@pytest.fixture
def token_store(settings: Settings, tmp_path: object) -> TokenStore:
    import pathlib

    assert isinstance(tmp_path, pathlib.Path)
    return TokenStore(
        encryption_key=settings.token_encryption_key,
        storage_path=str(tmp_path / "tokens.enc"),
    )


@pytest.fixture
def dips_client(settings: Settings, token_store: TokenStore) -> DipsClient:
    return DipsClient(settings, token_store)


@pytest.fixture
async def client(
    settings: Settings,
    token_store: TokenStore,
    dips_client: DipsClient,
) -> AsyncClient:
    app.dependency_overrides[get_settings] = lambda: settings
    app.dependency_overrides[get_token_store] = lambda: token_store
    app.dependency_overrides[get_dips_client] = lambda: dips_client
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_health(client: AsyncClient) -> None:
    resp = await client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_auth_status_unauthenticated(client: AsyncClient) -> None:
    resp = await client.get("/auth/status")
    assert resp.status_code == 200
    data = resp.json()
    assert data["authenticated"] is False


@pytest.mark.asyncio
async def test_authorize_url(client: AsyncClient) -> None:
    resp = await client.get("/auth/authorize?redirect_uri=http://localhost:8080/callback")
    assert resp.status_code == 200
    data = resp.json()
    assert "authorize_url" in data
    assert "stg.uafp.dips.mlit.go.jp" in data["authorize_url"]
    assert "state" in data


@pytest.mark.asyncio
async def test_dips_api_requires_auth(client: AsyncClient) -> None:
    """未認証時に DIPS API を叩くと 401 になる"""
    resp = await client.get("/dips/aircraft/list")
    assert resp.status_code == 401
