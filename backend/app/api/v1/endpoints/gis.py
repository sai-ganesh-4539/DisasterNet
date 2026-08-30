"""Live GIS snapshot endpoints — no static sample rows."""
from typing import Any, Dict, Optional

from fastapi import APIRouter, HTTPException, Query

from app.services.live_gis import INDIA_BBOX, build_snapshot

router = APIRouter()


@router.get("/snapshot")
async def gis_snapshot(
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
):
    try:
        return build_snapshot(south=south, west=west, north=north, east=east)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Live GIS build failed: {exc}") from exc


@router.get("/national")
async def gis_national():
    try:
        return build_snapshot()
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Live GIS build failed: {exc}") from exc


@router.get("/inspect")
async def gis_inspect(
    latitude: float = Query(..., ge=6.0, le=37.5),
    longitude: float = Query(..., ge=68.0, le=97.5),
):
    try:
        from app.services.live_gis import inspect_point

        return inspect_point(latitude, longitude)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Inspect failed: {exc}") from exc
