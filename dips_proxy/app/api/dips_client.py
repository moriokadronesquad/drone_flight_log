"""DIPS 2.0 API への HTTP クライアント — トークン自動更新付き"""

import logging
from typing import Any

import httpx

from app.auth import oidc
from app.auth.token_store import TokenStore
from app.config import Settings

logger = logging.getLogger(__name__)


class DipsApiError(Exception):
    """DIPS API 呼び出し時のエラー"""

    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"DIPS API error {status_code}: {detail}")


class DipsClient:
    """DIPS 2.0 API と通信するクライアント

    - access_token 期限切れ時に自動で refresh する
    - refresh_token も切れている場合は再認証を要求する
    """

    def __init__(self, settings: Settings, token_store: TokenStore) -> None:
        self._settings = settings
        self._store = token_store

    async def _ensure_valid_token(self) -> str:
        """有効な access_token を返す。必要に応じて refresh する"""
        tokens = self._store.get()

        if tokens.access_token_valid:
            return tokens.access_token

        if tokens.refresh_token_valid:
            logger.info("access_token 期限切れ → refresh 実行")
            token_resp = await oidc.refresh_access_token(
                self._settings, tokens.refresh_token
            )
            updated = self._store.save_token_response(token_resp)
            return updated.access_token

        raise DipsApiError(401, "認証が必要です。DIPS に再ログインしてください。")

    async def request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """DIPS API にリクエストを送信する"""
        access_token = await self._ensure_valid_token()
        url = f"{self._settings.api_base_url}{path}"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.request(
                method, url, headers=headers, params=params, json=json_body
            )

        if resp.status_code == 401:
            raise DipsApiError(401, "DIPS API 認証エラー — 再ログインしてください")
        if resp.status_code >= 400:
            raise DipsApiError(resp.status_code, resp.text)

        return resp.json()
