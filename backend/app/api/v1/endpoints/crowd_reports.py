"""Crowd-sourced damage / situation reports from citizens.

Citizens (and field officers) can submit lightweight reports —
damage, flooding, road blockage, casualty counts — without going
through the full field-survey form. These reports are queued and
merged into the GIS snapshot so they appear on the map for everyone
(operators and other citizens).
"""

from __future__ import annotations

import math
import secrets
import threading
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.core.security import get_current_user, get_current_user_optional

router = APIRouter()

_LOCK = threading.RLock()
_REPORTS: Dict[str, Dict[str, Any]] = {}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class CrowdReport(BaseModel):
    report_id: Optional[str] = None
    category: str = Field(..., description="FLOOD | LANDSLIDE | ROAD_BLOCKED | STRUCTURE_DAMAGE | FIRE | MEDICAL | STRANDED | WATERLOGGING | OTHER")
    severity: str = Field(default="MEDIUM", description="LOW | MEDIUM | HIGH | CRITICAL")
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    accuracy_m: Optional[float] = None
    description: str = Field(default="", max_length=2000)
    people_affected: Optional[int] = Field(default=None, ge=0, le=100000)
    casualties: Optional[int] = Field(default=None, ge=0, le=10000)
    photo_url: Optional[str] = None
    contact_phone: Optional[str] = None
    submitted_at: str = Field(default_factory=_now_iso)


class CrowdReportResponse(BaseModel):
    report_id: str
    accepted: bool
    duplicate: bool
    server_timestamp: str


class CrowdReportRecord(BaseModel):
    report_id: str
    category: str
    severity: str
    latitude: float
    longitude: float
    description: str
    people_affected: Optional[int]
    casualties: Optional[int]
    photo_url: Optional[str]
    contact_phone: Optional[str]
    submitted_at: str
    submitted_by: Optional[str]
    submitter_role: Optional[str]
    verified: bool
    status: str


class CrowdReportList(BaseModel):
    count: int
    items: List[CrowdReportRecord]
    server_time: str


@router.post("/submit", response_model=CrowdReportResponse)
async def submit_crowd_report(
    report: CrowdReport,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """Submit a citizen crowd-sourced damage report.

    Authenticated citizens get their user_id stamped; anonymous
    submissions are accepted (the prototype lets the public contribute
    without friction).
    """
    report_id = report.report_id or f"cr-{secrets.token_urlsafe(8)}"
    with _LOCK:
        if report.report_id and report.report_id in _REPORTS:
            return CrowdReportResponse(
                report_id=report.report_id,
                accepted=True,
                duplicate=True,
                server_timestamp=_now_iso(),
            )
        record: Dict[str, Any] = {
            **report.model_dump(),
            "report_id": report_id,
            "submitted_by": current_user.get("user_id") if current_user else None,
            "submitter_role": current_user.get("role") if current_user else "ANONYMOUS",
            "verified": False,
            "status": "SUBMITTED",
            "server_timestamp": _now_iso(),
        }
        _REPORTS[report_id] = record
    return CrowdReportResponse(
        report_id=report_id,
        accepted=True,
        duplicate=False,
        server_timestamp=_now_iso(),
    )


@router.get("/", response_model=CrowdReportList)
async def list_crowd_reports(
    latitude: Optional[float] = Query(default=None, ge=-90, le=90),
    longitude: Optional[float] = Query(default=None, ge=-180, le=180),
    radius_km: float = Query(default=25.0, ge=1, le=500),
    category: Optional[str] = Query(default=None),
    severity: Optional[str] = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """List crowd reports — optionally filtered by location radius."""
    items: List[CrowdReportRecord] = []

    def _haversine_km(lat1, lon1, lat2, lon2):
        r = 6371.0
        p1 = math.radians(lat1)
        p2 = math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlam = math.radians(lon2 - lon1)
        a = (
            math.sin(dphi / 2) ** 2
            + math.cos(p1) * math.cos(p2) * math.sin(dlam / 2) ** 2
        )
        return 2 * r * math.asin(math.sqrt(a))

    with _LOCK:
        for record in _REPORTS.values():
            if category and record["category"] != category:
                continue
            if severity and record["severity"] != severity:
                continue
            if latitude is not None and longitude is not None:
                d = _haversine_km(latitude, longitude, record["latitude"], record["longitude"])
                if d > radius_km:
                    continue
            items.append(_to_record(record))
    items.sort(key=lambda r: r.submitted_at, reverse=True)
    return CrowdReportList(count=len(items[:limit]), items=items[:limit], server_time=_now_iso())


@router.post("/{report_id}/verify", response_model=CrowdReportRecord)
async def verify_report(
    report_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Mark a crowd report as verified by an operator (field officer+)."""
    role = (current_user.get("role") or "").upper()
    if role in {"CITIZEN", "VIEWER"}:
        raise HTTPException(status_code=403, detail="Only operators can verify reports.")
    with _LOCK:
        record = _REPORTS.get(report_id)
        if record is None:
            raise HTTPException(status_code=404, detail="Report not found.")
        record["verified"] = True
        record["verified_by"] = current_user.get("user_id")
        record["status"] = "VERIFIED"
        return _to_record(record)


@router.get("/status/summary")
async def reports_summary(current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional)):
    """Aggregate stats for the crowd-report dashboard."""
    with _LOCK:
        by_category: Dict[str, int] = {}
        by_severity: Dict[str, int] = {}
        by_status: Dict[str, int] = {}
        verified = 0
        for r in _REPORTS.values():
            by_category[r["category"]] = by_category.get(r["category"], 0) + 1
            by_severity[r["severity"]] = by_severity.get(r["severity"], 0) + 1
            by_status[r["status"]] = by_status.get(r["status"], 0) + 1
            if r["verified"]:
                verified += 1
        return {
            "total": len(_REPORTS),
            "verified": verified,
            "by_category": by_category,
            "by_severity": by_severity,
            "by_status": by_status,
            "server_time": _now_iso(),
        }


def _to_record(record: Dict[str, Any]) -> CrowdReportRecord:
    return CrowdReportRecord(
        report_id=record["report_id"],
        category=record["category"],
        severity=record["severity"],
        latitude=record["latitude"],
        longitude=record["longitude"],
        description=record["description"],
        people_affected=record.get("people_affected"),
        casualties=record.get("casualties"),
        photo_url=record.get("photo_url"),
        contact_phone=record.get("contact_phone"),
        submitted_at=record["submitted_at"],
        submitted_by=record.get("submitted_by"),
        submitter_role=record.get("submitter_role"),
        verified=record.get("verified", False),
        status=record.get("status", "SUBMITTED"),
    )
