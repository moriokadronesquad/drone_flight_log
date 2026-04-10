"""DIPS トークンの暗号化保管と自動更新"""

import json
import logging
import time
from dataclasses import dataclass, field
from pathlib import Path

from cryptography.fernet import Fernet, InvalidToken

logger = logging.getLogger(__name__)

# access_token: 300秒, refresh_token: 3600秒（DIPS仕様）
ACCESS_TOKEN_LIFETIME = 300
REFRESH_TOKEN_LIFETIME = 3600
# 有効期限の余裕（期限の30秒前に期限切れ扱い）
EXPIRY_MARGIN = 30


@dataclass
class TokenData:
    """保管するトークン情報"""

    access_token: str = ""
    refresh_token: str = ""
    id_token: str = ""
    access_token_expires_at: float = 0.0
    refresh_token_expires_at: float = 0.0
    extra: dict[str, str] = field(default_factory=dict)

    @property
    def access_token_valid(self) -> bool:
        return bool(self.access_token) and time.time() < (
            self.access_token_expires_at - EXPIRY_MARGIN
        )

    @property
    def refresh_token_valid(self) -> bool:
        return bool(self.refresh_token) and time.time() < (
            self.refresh_token_expires_at - EXPIRY_MARGIN
        )

    @property
    def is_authenticated(self) -> bool:
        """access_token または refresh_token のどちらかが有効"""
        return self.access_token_valid or self.refresh_token_valid


class TokenStore:
    """暗号化ファイルベースのトークンストア

    さくらVPS上のファイルに Fernet で暗号化して保存する。
    プロセス再起動時にも認証状態を維持できる。
    """

    def __init__(self, encryption_key: str, storage_path: str = "data/tokens.enc") -> None:
        if not encryption_key:
            logger.warning("TOKEN_ENCRYPTION_KEY が未設定。トークンはメモリのみで保持します")
            self._fernet = None
        else:
            self._fernet = Fernet(encryption_key.encode())

        self._storage_path = Path(storage_path)
        self._tokens = TokenData()
        self._load()

    # --- 公開メソッド ---

    def get(self) -> TokenData:
        """現在のトークンを取得"""
        return self._tokens

    def save_token_response(self, token_response: dict[str, str]) -> TokenData:
        """DIPS トークンエンドポイントのレスポンスを保存する"""
        now = time.time()
        expires_in = int(token_response.get("expires_in", ACCESS_TOKEN_LIFETIME))
        refresh_expires_in = int(
            token_response.get("refresh_expires_in", REFRESH_TOKEN_LIFETIME)
        )

        self._tokens = TokenData(
            access_token=token_response.get("access_token", ""),
            refresh_token=token_response.get("refresh_token", ""),
            id_token=token_response.get("id_token", ""),
            access_token_expires_at=now + expires_in,
            refresh_token_expires_at=now + refresh_expires_in,
        )
        self._persist()
        logger.info(
            "トークン保存完了 (access: %ds, refresh: %ds)", expires_in, refresh_expires_in
        )
        return self._tokens

    def clear(self) -> None:
        """トークンを破棄する（ログアウト時）"""
        self._tokens = TokenData()
        self._persist()
        logger.info("トークンをクリアしました")

    # --- 永続化 ---

    def _persist(self) -> None:
        """暗号化してファイルに書き込む"""
        if self._fernet is None:
            return
        data = json.dumps({
            "access_token": self._tokens.access_token,
            "refresh_token": self._tokens.refresh_token,
            "id_token": self._tokens.id_token,
            "access_token_expires_at": self._tokens.access_token_expires_at,
            "refresh_token_expires_at": self._tokens.refresh_token_expires_at,
        })
        self._storage_path.parent.mkdir(parents=True, exist_ok=True)
        self._storage_path.write_bytes(self._fernet.encrypt(data.encode()))

    def _load(self) -> None:
        """起動時にファイルから復元する"""
        if self._fernet is None or not self._storage_path.exists():
            return
        try:
            raw = self._fernet.decrypt(self._storage_path.read_bytes())
            obj = json.loads(raw.decode())
            self._tokens = TokenData(
                access_token=obj.get("access_token", ""),
                refresh_token=obj.get("refresh_token", ""),
                id_token=obj.get("id_token", ""),
                access_token_expires_at=obj.get("access_token_expires_at", 0.0),
                refresh_token_expires_at=obj.get("refresh_token_expires_at", 0.0),
            )
            if self._tokens.is_authenticated:
                logger.info("保存済みトークンを復元しました")
            else:
                logger.info("保存済みトークンは期限切れです")
        except (InvalidToken, json.JSONDecodeError, KeyError) as e:
            logger.warning("トークンファイルの復元に失敗: %s", e)
            self._tokens = TokenData()
