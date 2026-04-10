"""アプリケーション設定 — 環境変数から読み込む"""

from enum import Enum
from functools import lru_cache

from pydantic_settings import BaseSettings


class DipsEnv(str, Enum):
    """DIPS API 接続先環境"""

    STAGING = "staging"
    PRODUCTION = "production"


# DIPS 2.0 API エンドポイント定義
_ENDPOINTS = {
    DipsEnv.STAGING: {
        "auth_base": "https://www.stg.uafp.dips.mlit.go.jp/auth/realms/drs-fpl/protocol/openid-connect",
        "api_base": "https://www.stg.uafpi.dips.mlit.go.jp/api",
    },
    DipsEnv.PRODUCTION: {
        "auth_base": "https://www.dips-reg.mlit.go.jp/auth/realms/drs-fpl/protocol/openid-connect",
        "api_base": "https://www.uafpi.dips.mlit.go.jp/api",
    },
}


class Settings(BaseSettings):
    """環境変数ベースの設定"""

    # DIPS 認証
    dips_client_id: str = ""
    dips_client_secret: str = ""
    dips_env: DipsEnv = DipsEnv.STAGING

    # FastAPI
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    app_secret_key: str = "change-this-to-a-random-secret-key"

    # CORS
    cors_origins: str = "https://moriokadronesquad.github.io,http://localhost:8080"

    # フロントエンド（認証完了後のリダイレクト先）
    frontend_url: str = "https://moriokadronesquad.github.io/drone_flight_log/"

    # トークン暗号化
    token_encryption_key: str = ""

    # ログ
    log_level: str = "INFO"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}

    # --- 派生プロパティ ---

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def auth_base_url(self) -> str:
        return _ENDPOINTS[self.dips_env]["auth_base"]

    @property
    def api_base_url(self) -> str:
        return _ENDPOINTS[self.dips_env]["api_base"]

    @property
    def authorize_url(self) -> str:
        return f"{self.auth_base_url}/auth"

    @property
    def token_url(self) -> str:
        return f"{self.auth_base_url}/token"

    @property
    def userinfo_url(self) -> str:
        return f"{self.auth_base_url}/userinfo"


@lru_cache
def get_settings() -> Settings:
    """設定シングルトンを返す"""
    return Settings()
