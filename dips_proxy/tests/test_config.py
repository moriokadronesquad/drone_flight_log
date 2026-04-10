"""config.py のテスト"""

from app.config import DipsEnv, Settings


def test_staging_endpoints() -> None:
    """ステージング環境のURL生成"""
    s = Settings(dips_env=DipsEnv.STAGING, dips_client_id="test", dips_client_secret="secret")
    assert "stg" in s.auth_base_url
    assert "stg" in s.api_base_url
    assert s.token_url.endswith("/token")
    assert s.authorize_url.endswith("/auth")


def test_production_endpoints() -> None:
    """本番環境のURL生成"""
    s = Settings(dips_env=DipsEnv.PRODUCTION, dips_client_id="test", dips_client_secret="secret")
    assert "stg" not in s.auth_base_url
    assert "dips-reg.mlit.go.jp" in s.authorize_url


def test_cors_origin_list() -> None:
    """CORS オリジンのパース"""
    s = Settings(cors_origins="https://example.com, http://localhost:8080 ")
    assert s.cors_origin_list == ["https://example.com", "http://localhost:8080"]
