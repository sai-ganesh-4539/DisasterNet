"""Dynamic relocation prioritization endpoints."""

from __future__ import annotations

from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from app.core.security import get_current_user_optional
from app.services.live_gis import INDIA_BBOX, build_snapshot

router = APIRouter()


class PriorityFilterRequest(BaseModel):
    state_code: Optional[str] = None
    district_code: Optional[str] = None
    priority_category: Optional[str] = None
    min_priority_score: Optional[float] = None
    limit: int = 50
    offset: int = 0


def _with_priority_reason(row: Dict[str, Any]) -> Dict[str, Any]:
    breakdown = row.get("calculation_breakdown") or {}
    components = breakdown.get("component_scores") or {}
    reason_parts = []
    if components:
        ordered = sorted(components.items(), key=lambda kv: float(kv[1]), reverse=True)[
            :2
        ]
        for key, value in ordered:
            reason_parts.append(f"{key.replace('_', ' ')} {float(value):.0f}")
    if not reason_parts:
        reason_parts.append(
            f"hazard proximity {float(row.get('proximity_to_hazard_km') or 0.0):.1f} km"
        )
    category = str(row.get("priority_category") or "MEDIUM_TERM").upper()
    horizon = {
        "IMMEDIATE": {
            "name": "Immediate",
            "max_hours": 24,
            "description": "Evacuation / relocation action in 0-24h",
        },
        "SHORT_TERM": {
            "name": "Short-Term",
            "min_weeks": 1,
            "max_weeks": 4,
            "description": "Pre-stage assets and plan relocation",
        },
        "MEDIUM_TERM": {
            "name": "Medium-Term",
            "min_months": 1,
            "max_months": 6,
            "description": "Managed relocation planning",
        },
    }[category]
    return {
        **row,
        "time_horizon": horizon,
        "reason": "; ".join(reason_parts),
    }


async def _priority_payload(
    *,
    south: float,
    west: float,
    north: float,
    east: float,
    state_code: Optional[str],
    district_code: Optional[str],
    priority_category: Optional[str],
    limit: int,
    offset: int,
) -> Dict[str, Any]:
    snapshot = build_snapshot(south=south, west=west, north=north, east=east)
    rows = list(snapshot.get("habitations", []))
    if state_code:
        rows = [
            r
            for r in rows
            if str(r.get("state_code", "")).upper() == state_code.upper()
        ]
    if district_code:
        district_upper = district_code.upper()
        rows = [
            r for r in rows if district_upper in str(r.get("district_name", "")).upper()
        ]
    if priority_category:
        rows = [
            r
            for r in rows
            if str(r.get("priority_category", "")).upper() == priority_category.upper()
        ]
    rows.sort(key=lambda x: float(x.get("priority_score") or 0.0), reverse=True)
    enriched = [_with_priority_reason(r) for r in rows]
    return {
        "count": len(enriched),
        "limit": limit,
        "offset": offset,
        "generated_at": snapshot.get("generated_at"),
        "cache_hit": snapshot.get("cache_hit", False),
        "priorities": enriched[offset : offset + limit],
        "summary": {
            "immediate_count": len(
                [p for p in enriched if p.get("priority_category") == "IMMEDIATE"]
            ),
            "short_term_count": len(
                [p for p in enriched if p.get("priority_category") == "SHORT_TERM"]
            ),
            "medium_term_count": len(
                [p for p in enriched if p.get("priority_category") == "MEDIUM_TERM"]
            ),
        },
    }


@router.get("/")
async def get_priorities(
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    priority_category: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        return await _priority_payload(
            south=south,
            west=west,
            north=north,
            east=east,
            state_code=state_code,
            district_code=district_code,
            priority_category=priority_category,
            limit=limit,
            offset=offset,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to build priorities: {exc}",
        ) from exc


@router.get("/immediate")
async def get_immediate_priorities(
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    limit: int = 20,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    return await _priority_payload(
        south=south,
        west=west,
        north=north,
        east=east,
        state_code=state_code,
        district_code=district_code,
        priority_category="IMMEDIATE",
        limit=limit,
        offset=0,
    )


@router.get("/short-term")
async def get_short_term_priorities(
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    limit: int = 20,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    return await _priority_payload(
        south=south,
        west=west,
        north=north,
        east=east,
        state_code=state_code,
        district_code=district_code,
        priority_category="SHORT_TERM",
        limit=limit,
        offset=0,
    )


@router.get("/medium-term")
async def get_medium_term_priorities(
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    limit: int = 20,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    return await _priority_payload(
        south=south,
        west=west,
        north=north,
        east=east,
        state_code=state_code,
        district_code=district_code,
        priority_category="MEDIUM_TERM",
        limit=limit,
        offset=0,
    )


@router.get("/summary")
async def get_priority_summary(
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    snapshot = build_snapshot(south=south, west=west, north=north, east=east)
    rows = list(snapshot.get("habitations", []))
    if state_code:
        rows = [
            r
            for r in rows
            if str(r.get("state_code", "")).upper() == state_code.upper()
        ]
    if district_code:
        district_upper = district_code.upper()
        rows = [
            r for r in rows if district_upper in str(r.get("district_name", "")).upper()
        ]
    immediate = [r for r in rows if r.get("priority_category") == "IMMEDIATE"]
    short_term = [r for r in rows if r.get("priority_category") == "SHORT_TERM"]
    medium_term = [r for r in rows if r.get("priority_category") == "MEDIUM_TERM"]
    return {
        "total_habitations": len(rows),
        "prioritized_habitations": len(rows),
        "priority_distribution": {
            "immediate": len(immediate),
            "short_term": len(short_term),
            "medium_term": len(medium_term),
        },
        "population_at_risk": {
            "immediate": sum(int(r.get("total_population") or 0) for r in immediate),
            "short_term": sum(int(r.get("total_population") or 0) for r in short_term),
            "medium_term": sum(
                int(r.get("total_population") or 0) for r in medium_term
            ),
        },
        "geographic_distribution": {
            "states": len({r.get("state_code") for r in rows if r.get("state_code")}),
            "districts": len(
                {r.get("district_name") for r in rows if r.get("district_name")}
            ),
        },
        "resource_requirements": {
            "total_shelter_capacity_needed": sum(
                int(r.get("total_population") or 0) for r in rows
            ),
            "immediate_capacity_needed": sum(
                int(r.get("total_population") or 0) for r in immediate
            ),
            "short_term_capacity_needed": sum(
                int(r.get("total_population") or 0) for r in short_term
            ),
            "medium_term_capacity_needed": sum(
                int(r.get("total_population") or 0) for r in medium_term
            ),
        },
        "generated_at": snapshot.get("generated_at"),
        "cache_hit": snapshot.get("cache_hit", False),
    }
