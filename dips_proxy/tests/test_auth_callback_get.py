"""GET /auth/callback エンドポイントのテスト（B案: サーバーサイド完結型）"""

from unittest.mock import AsyncMock, patch

import pytest
from cryptography.fernet import Fernet
from httpx import ASGITransport, AsyncClient

from app.auth import router as auth_router_module
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
        frontend_url="https://example.com/app/",
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
async def client(
    settings: Settings,
    token_store: TokenStore,
) -> AsyncClient:
    app.dependency_overrides[get_settings] = lambda: settings
    app.dependency_overrides[get_token_store] = lambda: token_store
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=False) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture(autouse=True)
def _clear_pending_auth():
    """各テスト後に_pending_authをクリア"""
    yield
    auth_router_module._pending_auth.clear()


# --- テストケース ---


@pytest.mark.asyncio
async def test_callback_get_error_from_dips(client: AsyncClient) -> None:
    """DIPS側がerrorパラメータを返した場合、Flutterにエラーリダイレクトする"""
    resp = await client.get("/auth/callback", params={
        "error": "access_denied",
        "error_description": "User denied access",
    })
    assert resp.status_code == 302
    location = resp.headers["location"]
    assert "auth=error" in location
    assert "access_denied" in location


@pytest.mark.asyncio
async def test_callback_get_missing_code(client: AsyncClient) -> None:
    """code/stateが欠落している場合、エラーリダイレクトする"""
    resp = await client.get("/auth/callback", params={"state": "abc"})
    assert resp.status_code == 302
    assert "missing_params" in resp.headers["location"]


@pytest.mark.asyncio
async def test_callback_get_state_mismatch(client: AsyncClient) -> None:
    """stateが一致しない場合、エラーリダイレクトする"""
    auth_router_module._pending_auth.update({
        "state": "correct_state",
        "code_verifier": "test_verifier",
        "redirect_uri": "https://example.com/auth/callback",
    })
    resp = await client.get("/auth/callback", params={"code": "test_code", "state": "wrong_state"})
    assert resp.status_code == 302
    assert "state_mismatch" in resp.headers["location"]


@pytest.mark.asyncio
async def test_callback_get_no_session(client: AsyncClient) -> None:
    """pending authにcode_verifierが無い場合エラー"""
    auth_router_module._pending_auth.update({"state": "test_state"})
    resp = await client.get("/auth/callback", params={"code": "test_code", "state": "test_state"})
    assert resp.status_code == 302
    assert "no_session" in resp.headers["location"]


@pytest.mark.asyncio
async def test_callback_get_success(client: AsyncClient) -> None:
    """正常系: トークン交換が成功し、Flutter にauth=successでリダイレクトする"""
    auth_router_module._pending_auth.update({
        "state": "good_state",
        "code_verifier": "verifier123",
        "redirect_uri": "https://dronepeak-dips.minato-morioka.jp/auth/callback",
    })

    mock_token_resp = {
        "access_token": "at_xxx",
        "refresh_token": "rt_xxx",
        "id_token": "id_xxx",
        "expires_in": 300,
        "refresh_expires_in": 3600,
    }

    with patch("app.auth.oidc.exchange_code_for_tokens", new_callable=AsyncMock, return_value=mock_token_resp):
        resp = await client.get("/auth/callback", params={"code": "auth_code", "state": "good_state"})

    assert resp.status_code == 302
    location = resp.headers["location"]
    assert "https://example.com/app" in location
    assert "auth=success" in location
    assert len(auth_router_module._pending_auth) == 0


@pytest.mark.asyncio
async def test_callback_get_token_exchange_failure(client: AsyncClient) -> None:
    """トークン交換が失敗した場合、エラーリダイレクトする"""
    auth_router_module._pending_auth.update({
        "state": "fail_state",
        "code_verifier": "verifier456",
        "redirect_uri": "https://dronepeak-dips.minato-morioka.jp/auth/callback",
    })

    with patch("app.auth.oidc.exchange_code_for_tokens", new_callable=AsyncMock, side_effect=RuntimeError("connection error")):
        resp = await client.get("/auth/callback", params={"code": "bad_code", "state": "fail_state"})

    assert resp.status_code == 302
    assert "token_exchange_failed" in resp.headers["location"]


@pytest.mark.asyncio
async def test_callback_get_redirects_to_configured_frontend(client: AsyncClient) -> None:
    """frontend_url設定値がリダイレクト先に使われる"""
    resp = await client.get("/auth/callback", params={"error": "test"})
    assert resp.status_code == 302
    assert resp.headers["location"].startswith("https://example.com/app")
