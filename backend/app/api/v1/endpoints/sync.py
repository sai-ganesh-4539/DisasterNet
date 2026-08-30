"""Offline-first sync endpoints backed by the live GIS snapshot engine."""

from __future__ import annotations

import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from app.core.security import get_current_user_optional
from app.services.field_updates import field_update_store
from app.services.live_gis import INDIA_BBOX, build_snapshot

router = APIRouter()
logger = logging.getLogger(__name__)


class SyncDataRequest(BaseModel):
    device_id: str
    data_type: str
    payload: Dict[str, Any]
    timestamp: str
    signature: str


class SyncDataResponse(BaseModel):
    success: bool
    sync_id: str
    records_processed: int
    message: str
    server_timestamp: str


def _canonical_json(payload: Dict[str, Any]) -> str:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str)


@router.post("/upload")
async def upload_sync_data(
    request: SyncDataRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        if not _validate_signature(
            request.device_id, request.payload, request.signature
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid signature"
            )

        sync_id = f"SYNC_{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}_{request.device_id}"
        processed_count = _process_payload(request.data_type, request.payload)
        return SyncDataResponse(
            success=True,
            sync_id=sync_id,
            records_processed=processed_count,
            message="Data synced successfully",
            server_timestamp=datetime.now(timezone.utc).isoformat(),
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Sync upload failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync upload failed: {exc}",
        ) from exc


@router.get("/download")
async def download_sync_data(
    device_id: str,
    last_sync_timestamp: Optional[str] = None,
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        snapshot = build_snapshot(south=south, west=west, north=north, east=east)
        return {
            "device_id": device_id,
            "server_timestamp": datetime.now(timezone.utc).isoformat(),
            "generated_at": snapshot.get("generated_at"),
            "bbox": snapshot.get("bbox"),
            "hazard_zones": snapshot.get("red_zones", []),
            "habitations": snapshot.get("habitations", []),
            "shelters": snapshot.get("shelters", []),
            "summary": snapshot.get("summary", {}),
            "data_sources": snapshot.get("data_sources", {}),
            "cache_hit": snapshot.get("cache_hit", False),
            "last_sync_timestamp": last_sync_timestamp,
        }
    except Exception as exc:
        logger.error("Sync download failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync download failed: {exc}",
        ) from exc


@router.get("/status")
async def get_sync_status(
    device_id: Optional[str] = None,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    counts = field_update_store.counts()
    return {
        "device_id": device_id,
        "system_status": "OPERATIONAL",
        "overlay_counts": counts,
        "recent_events": field_update_store.recent_events(limit=10),
        "server_timestamp": datetime.now(timezone.utc).isoformat(),
    }


def _validate_signature(
    device_id: str, payload: Dict[str, Any], signature: str
) -> bool:
    try:
        expected = hashlib.sha256(
            f"{device_id}{_canonical_json(payload)}".encode()
        ).hexdigest()
        return signature == expected
    except Exception as exc:
        logger.error("Signature validation failed: %s", exc)
        return False


def _process_payload(data_type: str, payload: Dict[str, Any]) -> int:
    data_type_upper = data_type.upper()
    if data_type_upper in {"FIELD_SURVEY", "UPDATE_HABITATION", "HABITATION"}:
        field_update_store.upsert_habitation(payload)
        return 1
    if data_type_upper in {"SHELTER_UPDATE", "UPDATE_SHELTER", "SHELTER"}:
        field_update_store.upsert_shelter(payload)
        return 1
    if data_type_upper in {"CANDIDATE_SITE", "REGISTER_CANDIDATE"}:
        field_update_store.register_candidate_site(payload)
        return 1
    if data_type_upper == "BULK":
        processed = 0
        for row in payload.get("records", []):
            if not isinstance(row, dict):
                continue
            processed += _process_payload(
                str(row.get("data_type") or ""), row.get("payload") or row
            )
        return processed
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail=f"Unknown data type: {data_type}",
    )
