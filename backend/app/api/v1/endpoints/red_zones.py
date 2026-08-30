"""Dynamic red-zone endpoints backed by the live GIS snapshot engine."""

from __future__ import annotations

from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from shapely.wkt import loads as wkt_loads

from app.core.security import get_current_user_optional
from app.services.live_gis import INDIA_BBOX, build_snapshot

router = APIRouter()


class RedZoneCreateRequest(BaseModel):
    zone_id: str
    hazard_type: str
    severity_level: str
    geometry: str
    confidence_score: Optional[float] = 75.0
    detection_method: str = "AI_PREDICTION"


class RedZoneUpdateRequest(BaseModel):
    severity_level: Optional[str] = None
    validation_status: Optional[str] = None
    status: Optional[str] = None


def _zones_geojson(zones: list[Dict[str, Any]]) -> Dict[str, Any]:
    features = []
    for zone in zones:
        try:
            geom = wkt_loads(zone.get("geometry_wkt") or "")
            features.append(
                {
                    "type": "Feature",
                    "geometry": geom.__geo_interface__,
                    "properties": {
                        k: v for k, v in zone.items() if k != "geometry_wkt"
                    },
                }
            )
        except Exception:
            continue
    return {"type": "FeatureCollection", "features": features}


@router.get("/")
async def get_red_zones(
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    hazard_type: Optional[str] = None,
    zone_status: str = "ACTIVE",
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        snapshot = build_snapshot(south=south, west=west, north=north, east=east)
        zones = list(snapshot.get("red_zones", []))
        if hazard_type:
            zones = [
                z
                for z in zones
                if str(z.get("hazard_type", "")).upper() == hazard_type.upper()
            ]
        if zone_status:
            zones = [z for z in zones if zone_status.upper() == "ACTIVE"]

        return {
            "count": len(zones),
            "bbox": snapshot.get("bbox"),
            "generated_at": snapshot.get("generated_at"),
            "cache_hit": snapshot.get("cache_hit", False),
            "data_sources": snapshot.get("data_sources", {}),
            "red_zones": zones,
            "geojson": _zones_geojson(zones),
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to build live red zones: {exc}",
        ) from exc


@router.get("/{zone_id}")
async def get_red_zone(
    zone_id: str,
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    snapshot = build_snapshot(south=south, west=west, north=north, east=east)
    for zone in snapshot.get("red_zones", []):
        if zone.get("zone_id") == zone_id:
            return zone
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND, detail=f"Red zone not found: {zone_id}"
    )


@router.post("/", status_code=status.HTTP_501_NOT_IMPLEMENTED)
async def create_red_zone(
    request: RedZoneCreateRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Manual red-zone creation is disabled until the persistence layer is wired to live GIS outputs.",
    )


@router.put("/{zone_id}", status_code=status.HTTP_501_NOT_IMPLEMENTED)
async def update_red_zone(
    zone_id: str,
    request: RedZoneUpdateRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Manual red-zone edits are unavailable in the current live-compute mode.",
    )


@router.delete("/{zone_id}", status_code=status.HTTP_501_NOT_IMPLEMENTED)
async def delete_red_zone(
    zone_id: str,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Red-zone deletion is unavailable in the current live-compute mode.",
    )
