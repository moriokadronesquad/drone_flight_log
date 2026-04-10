"""oidc.py のテスト"""

import base64
import hashlib

from app.auth.oidc import build_authorize_url, generate_auth_params
from app.config import DipsEnv, Settings


def test_generate_auth_params() -> None:
    """PKCE パラメータが正しく生成される"""
    params = generate_auth_params()
    assert "state" in params
    assert "nonce" in params
    assert "code_verifier" in params
    assert "code_challenge" in params

    # S256 検証
    digest = hashlib.sha256(params["code_verifier"].encode("ascii")).digest()
    expected = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
    assert params["code_challenge"] == expected


def test_build_authorize_url() -> None:
    """認可URLが正しく構築される"""
    settings = Settings(
        dips_env=DipsEnv.STAGING,
        dips_client_id="my_client_id",
        dips_client_secret="secret",
    )
    params = generate_auth_params()
    url = build_authorize_url(settings, "https://example.com/callback", params)

    assert "stg.uafp.dips.mlit.go.jp" in url
    assert "client_id=my_client_id" in url
    assert "response_type=code" in url
    assert "code_challenge=" in url
    assert "code_challenge_method=S256" in url
    assert f"state={params['state']}" in url
