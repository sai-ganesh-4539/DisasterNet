"""Data-source status endpoints for demo/live GIS modes."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.config import yaml_config
from app.core.security import check_permission, get_current_user_optional
from app.ingestion.scheduler import DataIngestionScheduler
from app.services.field_updates import field_update_store
from app.services.live_gis import build_snapshot

router = APIRouter()
data_scheduler = DataIngestionScheduler()


class DataIngestionTriggerRequest(BaseModel):
    source: str


@router.get("/status")
async def get_data_status(
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        snapshot = build_snapshot()
        generated_at = datetime.fromisoformat(
            snapshot["generated_at"].replace("Z", "+00:00")
        )
        mode = snapshot.get("mode") or "LIVE"
        next_refresh = (
            None
            if mode == "DEMO_SCENARIO"
            else (generated_at + timedelta(minutes=3)).isoformat()
        )
        return {
            "mode": mode,
            "scenario": snapshot.get("scenario"),
            "last_generation": snapshot.get("generated_at"),
            "next_refresh_due": next_refresh,
            "data_sources": snapshot.get("data_sources", {}),
            "record_counts": {
                "grid_cells": len(snapshot.get("grid_cells", [])),
                "red_zones": len(snapshot.get("red_zones", [])),
                "habitations": len(snapshot.get("habitations", [])),
                "shelters": len(snapshot.get("shelters", [])),
            },
            "field_update_overlay": field_update_store.counts(),
            "system_status": "OPERATIONAL",
            "cache_hit": snapshot.get("cache_hit", False),
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get data status: {exc}",
        ) from exc


@router.post("/trigger")
async def trigger_data_ingestion(
    request: DataIngestionTriggerRequest,
    background_tasks: BackgroundTasks,
    current_user: Dict[str, Any] = Depends(check_permission("WRITE_FIELD_DATA")),
):
    try:
        valid_sources = ["isro_bhuvan", "imd_rainfall", "census"]
        if request.source not in valid_sources:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid source. Must be one of: {valid_sources}",
            )

        def run_ingestion():
            return data_scheduler.run_manual_ingestion(request.source)

        background_tasks.add_task(run_ingestion)
        return {
            "success": True,
            "message": f"Data ingestion triggered for {request.source}",
            "triggered_by": current_user.get("username"),
            "source": request.source,
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to trigger data ingestion: {exc}",
        ) from exc


@router.get("/sources")
async def get_data_sources(
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    ingestion_config = yaml_config.get("data_ingestion", {})
    snapshot = build_snapshot()
    mode = snapshot.get("mode") or "LIVE"
    if mode == "DEMO_SCENARIO":
        return {
            "mode": mode,
            "scenario": snapshot.get("scenario"),
            "sources": {
                "scenario_dataset": {
                    "provider": "Curated SIH prototype dataset",
                    "update_frequency": "manual scenario switch",
                    "description": "Static multi-hazard scenario package used for deterministic demo outputs",
                },
                "field_overlays": {
                    "provider": "On-device / backend field updates",
                    "update_frequency": "on sync upload",
                    "description": "Survey corrections applied over the active scenario snapshot",
                },
                "configured_ingestors": ingestion_config,
            },
            "scheduler_status": "INACTIVE_IN_DEMO_MODE",
        }
    return {
        "mode": mode,
        "sources": {
            "meteorology": {
                "provider": "Open-Meteo",
                "update_frequency": "on demand with 3-minute cache",
                "description": "Live precipitation, humidity, wind, temperature and soil moisture",
            },
            "flood": {
                "provider": "Open-Meteo GloFAS",
                "update_frequency": "on demand with 3-minute cache",
                "description": "River discharge signal used for flood amplification",
            },
            "terrain": {
                "provider": "Open-Meteo DEM",
                "update_frequency": "on demand with 3-minute cache",
                "description": "Elevation samples with neighbor-derived slope",
            },
            "settlements_and_sites": {
                "provider": "OpenStreetMap Overpass",
                "update_frequency": "on demand with 3-minute cache",
                "description": "Live habitations and relocation-site candidates",
            },
            "configured_ingestors": ingestion_config,
        },
        "scheduler_status": "ACTIVE" if data_scheduler.is_running else "INACTIVE",
    }


@router.get("/quality")
async def get_data_quality(
    source: Optional[str] = None,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    snapshot = build_snapshot()
    cache_hit = snapshot.get("cache_hit", False)
    mode = snapshot.get("mode") or "LIVE"
    if mode == "DEMO_SCENARIO":
        source_quality = {
            "scenario_dataset": {
                "provider": "Curated SIH prototype dataset",
                "snapshot_state": "STATIC_SCENARIO",
                "assessment": "Decision layers come from a fixed scenario package for deterministic demonstration outputs.",
            },
            "field_overlays": {
                "provider": "Survey sync overlays",
                "snapshot_state": "LIVE_OVERLAY"
                if field_update_store.counts()
                else "IDLE",
                "assessment": "Field submissions can still modify the active scenario snapshot.",
            },
        }
    else:
        source_quality = {
            "meteorology": {
                "provider": "Open-Meteo",
                "snapshot_state": "CACHED" if cache_hit else "LIVE_FETCH",
                "assessment": "Live meteorology is fetched on demand and cached for 3 minutes.",
            },
            "terrain": {
                "provider": "Open-Meteo DEM + neighbor-derived slope",
                "snapshot_state": "CACHED" if cache_hit else "LIVE_FETCH",
                "assessment": "Terrain elevation is fetched live; slope is derived from local neighborhood samples.",
            },
            "settlements_and_sites": {
                "provider": "OpenStreetMap Overpass",
                "snapshot_state": "CACHED" if cache_hit else "LIVE_FETCH",
                "assessment": "Settlement and facility features are fetched live from Overpass and merged with field overlays.",
            },
        }
    quality_issues = []
    if mode != "DEMO_SCENARIO" and cache_hit:
        quality_issues.append(
            {
                "source": "snapshot_cache",
                "issue_type": "CACHED_RESPONSE",
                "severity": "LOW",
                "description": "Returned data came from the 3-minute live snapshot cache.",
            }
        )
    quality = {
        "mode": mode,
        "scenario": snapshot.get("scenario"),
        "snapshot_state": "STATIC_SCENARIO"
        if mode == "DEMO_SCENARIO"
        else ("CACHED" if cache_hit else "LIVE_FETCH"),
        "generated_at": snapshot.get("generated_at"),
        "source_quality": source_quality,
        "quality_issues": quality_issues,
        "record_counts": {
            "grid_cells": len(snapshot.get("grid_cells", [])),
            "red_zones": len(snapshot.get("red_zones", [])),
            "habitations": len(snapshot.get("habitations", [])),
            "shelters": len(snapshot.get("shelters", [])),
        },
    }
    if source:
        if source not in source_quality:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Source not found: {source}",
            )
        return {"source": source, **source_quality[source]}
    return quality
