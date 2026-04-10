"""token_store.py のテスト"""

import time

from cryptography.fernet import Fernet

from app.auth.token_store import TokenData, TokenStore


def test_token_data_validity() -> None:
    """トークンの有効期限判定"""
    now = time.time()

    # 有効なトークン
    valid = TokenData(
        access_token="at",
        refresh_token="rt",
        access_token_expires_at=now + 300,
        refresh_token_expires_at=now + 3600,
    )
    assert valid.access_token_valid
    assert valid.refresh_token_valid
    assert valid.is_authenticated

    # access_token 期限切れ, refresh_token 有効
    partial = TokenData(
        access_token="at",
        refresh_token="rt",
        access_token_expires_at=now - 10,
        refresh_token_expires_at=now + 3600,
    )
    assert not partial.access_token_valid
    assert partial.refresh_token_valid
    assert partial.is_authenticated

    # 両方期限切れ
    expired = TokenData(
        access_token="at",
        refresh_token="rt",
        access_token_expires_at=now - 10,
        refresh_token_expires_at=now - 10,
    )
    assert not expired.is_authenticated


def test_save_and_restore(tmp_path: object) -> None:
    """トークンの保存と復元"""
    import pathlib

    assert isinstance(tmp_path, pathlib.Path)
    key = Fernet.generate_key().decode()
    path = str(tmp_path / "tokens.enc")

    store = TokenStore(encryption_key=key, storage_path=path)
    store.save_token_response({
        "access_token": "test_at",
        "refresh_token": "test_rt",
        "id_token": "test_id",
        "expires_in": "300",
        "refresh_expires_in": "3600",
    })

    # 新しいインスタンスで復元
    store2 = TokenStore(encryption_key=key, storage_path=path)
    tokens = store2.get()
    assert tokens.access_token == "test_at"
    assert tokens.refresh_token == "test_rt"
    assert tokens.is_authenticated


def test_clear(tmp_path: object) -> None:
    """トークンのクリア"""
    import pathlib

    assert isinstance(tmp_path, pathlib.Path)
    key = Fernet.generate_key().decode()
    path = str(tmp_path / "tokens.enc")

    store = TokenStore(encryption_key=key, storage_path=path)
    store.save_token_response({
        "access_token": "at",
        "refresh_token": "rt",
        "expires_in": "300",
        "refresh_expires_in": "3600",
    })
    store.clear()

    tokens = store.get()
    assert not tokens.is_authenticated
