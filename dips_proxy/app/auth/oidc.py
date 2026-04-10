"""OpenID Connect Authorization Code Flow — DIPS 2.0 API 向け"""

import base64
import hashlib
import logging
import secrets

import httpx

from app.config import Settings

logger = logging.getLogger(__name__)


def generate_auth_params() -> dict[str, str]:
    """認可リクエストに必要な state / nonce / code_verifier (PKCE) を生成"""
    state = secrets.token_urlsafe(32)
    nonce = secrets.token_urlsafe(32)
    code_verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(code_verifier.encode("ascii")).digest()
    code_challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")

    return {
        "state": state,
        "nonce": nonce,
        "code_verifier": code_verifier,
        "code_challenge": code_challenge,
    }


def build_authorize_url(settings: Settings, redirect_uri: str, auth_params: dict[str, str]) -> str:
    """DIPS 認可エンドポイントの URL を構築する"""
    params = {
        "response_type": "code",
        "client_id": settings.dips_client_id,
        "redirect_uri": redirect_uri,
        "scope": "openid",
        "state": auth_params["state"],
        "nonce": auth_params["nonce"],
        "code_challenge": auth_params["code_challenge"],
        "code_challenge_method": "S256",
    }
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    return f"{settings.authorize_url}?{qs}"


async def exchange_code_for_tokens(
    settings: Settings,
    code: str,
    redirect_uri: str,
    code_verifier: str,
) -> dict[str, str]:
    """認可コードをトークンに交換する"""
    payload = {
        "grant_type": "authorization_code",
        "client_id": settings.dips_client_id,
        "client_secret": settings.dips_client_secret,
        "code": code,
        "redirect_uri": redirect_uri,
        "code_verifier": code_verifier,
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(settings.token_url, data=payload)
        if resp.status_code != 200:
            logger.error("トークン取得失敗: %s %s", resp.status_code, resp.text)
            resp.raise_for_status()
        return resp.json()


async def refresh_access_token(
    settings: Settings,
    refresh_token: str,
) -> dict[str, str]:
    """refresh_token で access_token を更新する"""
    payload = {
        "grant_type": "refresh_token",
        "client_id": settings.dips_client_id,
        "client_secret": settings.dips_client_secret,
        "refresh_token": refresh_token,
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(settings.token_url, data=payload)
        if resp.status_code != 200:
            logger.error("トークン更新失敗: %s %s", resp.status_code, resp.text)
            resp.raise_for_status()
        return resp.json()
