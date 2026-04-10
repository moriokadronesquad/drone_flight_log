"""認証関連エンドポイント — Flutter Web から呼び出される"""

import logging
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import RedirectResponse
from pydantic import BaseModel

from app.auth import oidc
from app.auth.token_store import TokenStore
from app.config import Settings, get_settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["auth"])

# セッション中の認証パラメータ保持（単一ユーザー想定）
_pending_auth: dict[str, str] = {}


def get_token_store() -> TokenStore:
    """DI用 — main.py の lifespan で差し替える"""
    raise NotImplementedError("token_store not initialized")


# --- レスポンスモデル ---


class AuthUrlResponse(BaseModel):
    authorize_url: str
    state: str


class AuthStatusResponse(BaseModel):
    authenticated: bool
    access_token_valid: bool
    refresh_token_valid: bool


class CallbackRequest(BaseModel):
    code: str
    state: str
    redirect_uri: str


# --- エンドポイント ---


@router.get("/authorize", response_model=AuthUrlResponse)
async def get_authorize_url(
    redirect_uri: str = Query(..., description="Flutter側のコールバックURL"),
    settings: Settings = Depends(get_settings),
) -> AuthUrlResponse:
    """① 認可URLを生成して返す（Flutter が DIPS ログイン画面にリダイレクトする用）"""
    auth_params = oidc.generate_auth_params()
    _pending_auth.update(auth_params)
    _pending_auth["redirect_uri"] = redirect_uri

    url = oidc.build_authorize_url(settings, redirect_uri, auth_params)
    logger.info("認可URL生成: state=%s...", auth_params["state"][:8])
    return AuthUrlResponse(authorize_url=url, state=auth_params["state"])


@router.get("/callback")
async def handle_callback_get(
    settings: Settings = Depends(get_settings),
    store: TokenStore = Depends(get_token_store),
    code: str = Query(default=""),
    state: str = Query(default=""),
    error: str = Query(default=""),
    error_description: str = Query(default=""),
) -> RedirectResponse:
    """②-B DIPS認証サーバーからのGETリダイレクトを受け取りトークン交換する（B案: サーバーサイド完結型）

    成功時: Flutter Web にリダイレクト（?auth=success）
    エラー時: Flutter Web にエラーパラメータ付きリダイレクト
    """
    frontend_url = settings.frontend_url.rstrip("/")

    # DIPS側がエラーを返した場合（ユーザーが認証を拒否した等）
    if error:
        logger.warning("DIPS認証エラー: error=%s, description=%s", error, error_description)
        params = urlencode({"auth": "error", "error": error, "error_description": error_description})
        return RedirectResponse(url=f"{frontend_url}?{params}", status_code=302)

    # code / state が欠落
    if not code or not state:
        logger.warning("callbackにcode/stateが不足: code=%s, state=%s", bool(code), bool(state))
        params = urlencode({"auth": "error", "error": "missing_params", "error_description": "code or state missing"})
        return RedirectResponse(url=f"{frontend_url}?{params}", status_code=302)

    # state 検証
    if state != _pending_auth.get("state"):
        logger.warning("state不一致: expected=%s..., got=%s...",
                       _pending_auth.get("state", "none")[:8], state[:8])
        params = urlencode({"auth": "error", "error": "state_mismatch", "error_description": "state does not match"})
        return RedirectResponse(url=f"{frontend_url}?{params}", status_code=302)

    code_verifier = _pending_auth.get("code_verifier", "")
    if not code_verifier:
        logger.error("code_verifierが見つからない — 認証セッションが存在しない")
        params = urlencode({"auth": "error", "error": "no_session", "error_description": "no pending auth session"})
        return RedirectResponse(url=f"{frontend_url}?{params}", status_code=302)

    # redirect_uriは認可リクエスト時に保存したものを使う（トークン交換時に一致が必要）
    redirect_uri = _pending_auth.get("redirect_uri", "")

    try:
        token_resp = await oidc.exchange_code_for_tokens(
            settings, code, redirect_uri, code_verifier
        )
        store.save_token_response(token_resp)
        _pending_auth.clear()
        logger.info("GET /auth/callback: トークン交換成功")
        return RedirectResponse(url=f"{frontend_url}?auth=success", status_code=302)
    except Exception as exc:
        logger.error("トークン交換失敗: %s", exc)
        _pending_auth.clear()
        params = urlencode({"auth": "error", "error": "token_exchange_failed", "error_description": str(exc)})
        return RedirectResponse(url=f"{frontend_url}?{params}", status_code=302)


@router.post("/callback")
async def handle_callback(
    body: CallbackRequest,
    settings: Settings = Depends(get_settings),
    store: TokenStore = Depends(get_token_store),
) -> dict[str, str]:
    """② 認可コードを受け取りトークンに交換する"""
    if body.state != _pending_auth.get("state"):
        raise HTTPException(status_code=400, detail="state mismatch")

    code_verifier = _pending_auth.get("code_verifier", "")
    if not code_verifier:
        raise HTTPException(status_code=400, detail="No pending auth session")

    token_resp = await oidc.exchange_code_for_tokens(
        settings, body.code, body.redirect_uri, code_verifier
    )
    store.save_token_response(token_resp)
    _pending_auth.clear()

    return {"status": "authenticated"}


@router.get("/status", response_model=AuthStatusResponse)
async def get_auth_status(
    store: TokenStore = Depends(get_token_store),
) -> AuthStatusResponse:
    """認証状態を確認する"""
    tokens = store.get()
    return AuthStatusResponse(
        authenticated=tokens.is_authenticated,
        access_token_valid=tokens.access_token_valid,
        refresh_token_valid=tokens.refresh_token_valid,
    )


@router.post("/refresh")
async def refresh_token(
    settings: Settings = Depends(get_settings),
    store: TokenStore = Depends(get_token_store),
) -> dict[str, str]:
    """手動でトークンを更新する"""
    tokens = store.get()
    if not tokens.refresh_token_valid:
        raise HTTPException(status_code=401, detail="refresh_token expired — re-auth required")

    token_resp = await oidc.refresh_access_token(settings, tokens.refresh_token)
    store.save_token_response(token_resp)
    return {"status": "refreshed"}


@router.post("/logout")
async def logout(
    store: TokenStore = Depends(get_token_store),
) -> dict[str, str]:
    """トークンを破棄する"""
    store.clear()
    return {"status": "logged_out"}
