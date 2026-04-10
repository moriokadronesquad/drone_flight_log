"""DIPS 2.0 API 中継エンドポイント — 6つのAPIを Flutter Web に公開する"""

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.dips_client import DipsApiError, DipsClient

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/dips", tags=["dips"])


def get_dips_client() -> DipsClient:
    """DI用 — main.py の lifespan で差し替える"""
    raise NotImplementedError("dips_client not initialized")


# ──────────────────────────────────
# 1. 機体情報一覧取得
# ──────────────────────────────────


@router.get("/aircraft/list")
async def get_aircraft_list(
    client: DipsClient = Depends(get_dips_client),
) -> dict[str, Any]:
    """DIPS 登録済み機体一覧を取得"""
    try:
        return await client.request("GET", "/aircraft/list")
    except DipsApiError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e


# ──────────────────────────────────
# 2. 許可・承認情報取得
# ──────────────────────────────────


class PermitSearchRequest(BaseModel):
    """許可・承認検索の条件（API設定通知書で確定後に更新）"""

    application_number: str | None = None
    status: str | None = None


@router.post("/permit-application/search")
async def search_permit_applications(
    body: PermitSearchRequest,
    client: DipsClient = Depends(get_dips_client),
) -> dict[str, Any]:
    """飛行許可・承認情報を検索"""
    try:
        return await client.request(
            "POST",
            "/permit-application/search",
            json_body=body.model_dump(exclude_none=True),
        )
    except DipsApiError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e


# ──────────────────────────────────
# 3. 許可・承認申請受付
# ──────────────────────────────────


@router.post("/permit-application/register")
async def register_permit_application(
    body: dict[str, Any],
    client: DipsClient = Depends(get_dips_client),
) -> dict[str, Any]:
    """飛行許可・承認を申請（パラメータはAPI設定通知書で確定後に型定義）"""
    try:
        return await client.request(
            "POST", "/permit-application/register", json_body=body
        )
    except DipsApiError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e


# ──────────────────────────────────
# 4. 飛行計画情報取得（検索）
# ──────────────────────────────────


class FlightPlanSearchRequest(BaseModel):
    """飛行計画検索条件"""

    start_date: str | None = None
    end_date: str | None = None
    area_lat: float | None = None
    area_lon: float | None = None
    area_radius: float | None = None


@router.post("/flight-plan/search")
async def search_flight_plans(
    body: FlightPlanSearchRequest,
    client: DipsClient = Depends(get_dips_client),
) -> dict[str, Any]:
    """飛行計画を検索"""
    try:
        return await client.request(
            "POST",
            "/flight-plan/search",
            json_body=body.model_dump(exclude_none=True),
        )
    except DipsApiError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e


# ──────────────────────────────────
# 5. 飛行禁止エリア情報取得
# ──────────────────────────────────


class ProhibitedAreaSearchRequest(BaseModel):
    """飛行禁止エリア検索条件"""

    lat: float
    lon: float
    radius: float = 5000.0  # メートル


@router.post("/flight-prohibited-area/search")
async def search_prohibited_areas(
    body: ProhibitedAreaSearchRequest,
    client: DipsClient = Depends(get_dips_client),
) -> dict[str, Any]:
    """飛行禁止エリアを検索"""
    try:
        return await client.request(
            "POST",
            "/flight-prohibited-area/search",
            json_body=body.model_dump(),
        )
    except DipsApiError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e


# ──────────────────────────────────
# 6. 飛行計画通報（登録・更新）
# ──────────────────────────────────


@router.post("/flight-plan/register")
async def register_flight_plan(
    body: dict[str, Any],
    client: DipsClient = Depends(get_dips_client),
) -> dict[str, Any]:
    """飛行計画を通報（登録/更新）（パラメータはAPI設定通知書で確定後に型定義）"""
    try:
        return await client.request(
            "POST", "/flight-plan/register", json_body=body
        )
    except DipsApiError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail) from e
