"""Dynamic habitation analysis endpoints."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from app.core.security import get_current_user_optional
from app.ml.model_registry import get_model
from app.services.live_gis import INDIA_BBOX, build_snapshot

router = APIRouter()


class HabitationRiskRequest(BaseModel):
    habitation_id: str
    latitude: float
    longitude: float
    total_population: int
    elderly_percentage: float
    child_percentage: float
    disability_percentage: float
    population_density_per_sqkm: float
    economic_status: str
    road_connectivity: str
    road_distance_km: float
    nearest_emergency_km: float
    communication_availability: str
    evacuation_route_status: str
    evacuation_time_hours: float
    red_zone_proximity_km: float
    current_risk_score: Optional[float] = 0.0
    hazard_history: Optional[List[Dict[str, Any]]] = []
    disaster_frequency_score: Optional[float] = 0.0


@router.get("/")
async def get_habitations(
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
        snapshot = build_snapshot(south=south, west=west, north=north, east=east)
        habitations = list(snapshot.get("habitations", []))
        if state_code:
            habitations = [
                h
                for h in habitations
                if str(h.get("state_code", "")).upper() == state_code.upper()
            ]
        if district_code:
            district_upper = district_code.upper()
            habitations = [
                h
                for h in habitations
                if district_upper in str(h.get("district_name", "")).upper()
            ]
        if priority_category:
            habitations = [
                h
                for h in habitations
                if str(h.get("priority_category", "")).upper()
                == priority_category.upper()
            ]
        total = len(habitations)
        habitations = habitations[offset : offset + limit]
        return {
            "count": total,
            "limit": limit,
            "offset": offset,
            "generated_at": snapshot.get("generated_at"),
            "cache_hit": snapshot.get("cache_hit", False),
            "habitations": habitations,
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to build live habitation list: {exc}",
        ) from exc


@router.get("/{habitation_id}/risk")
async def get_habitation_risk(
    habitation_id: str,
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    snapshot = build_snapshot(south=south, west=west, north=north, east=east)
    habitation = next(
        (
            h
            for h in snapshot.get("habitations", [])
            if h.get("habitation_id") == habitation_id
        ),
        None,
    )
    if habitation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Habitation not found: {habitation_id}",
        )

    score = float(habitation.get("priority_score") or 0.0)
    vulnerability_score = min(
        100.0,
        (
            float(habitation.get("population_60_plus") or 0)
            + float(habitation.get("population_0_6") or 0)
        )
        / max(1.0, float(habitation.get("total_population") or 1))
        * 100.0
        * 2.2,
    )
    access_limitations = (
        90.0
        if habitation.get("path_status") == "BLOCKED"
        else 65.0
        if habitation.get("path_status") == "DAMAGED"
        else 25.0
    )
    return {
        "habitation_id": habitation.get("habitation_id"),
        "village_name": habitation.get("village_name"),
        "total_population": habitation.get("total_population"),
        "vulnerability_score": round(vulnerability_score, 2),
        "hazard_exposure_score": round(min(100.0, score + 8.0), 2),
        "access_limitations_score": round(access_limitations, 2),
        "overall_risk_score": round(score, 2),
        "risk_level": "CRITICAL"
        if score >= 85
        else "HIGH"
        if score >= 70
        else "MEDIUM"
        if score >= 50
        else "LOW",
        "red_zone_proximity_km": habitation.get("proximity_to_hazard_km"),
        "current_red_zone_id": habitation.get("current_red_zone_id"),
        "evacuation_time_hours": habitation.get("calculation_breakdown", {}).get(
            "evacuation_time_hours"
        ),
        "assessment_timestamp": habitation.get("assessment_timestamp"),
    }


@router.post("/assess")
async def assess_habitation_priority(
    request: HabitationRiskRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        model = get_model("priority_classifier")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Priority classifier model not available",
            )
        return model.predict(request.dict())
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Priority assessment failed: {exc}",
        ) from exc


@router.post("/assess-batch")
async def assess_habitations_batch(
    habitations: List[HabitationRiskRequest],
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        model = get_model("priority_classifier")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Priority classifier model not available",
            )
        features_list = [habitation.dict() for habitation in habitations]
        priority_assessments = model.predict_batch(features_list)
        return {
            "total_habitations": len(habitations),
            "assessments": priority_assessments,
            "summary": {
                "immediate_count": len(
                    [
                        p
                        for p in priority_assessments
                        if p.get("priority_category") == "IMMEDIATE"
                    ]
                ),
                "short_term_count": len(
                    [
                        p
                        for p in priority_assessments
                        if p.get("priority_category") == "SHORT_TERM"
                    ]
                ),
                "medium_term_count": len(
                    [
                        p
                        for p in priority_assessments
                        if p.get("priority_category") == "MEDIUM_TERM"
                    ]
                ),
            },
            "prioritized_list": sorted(
                priority_assessments,
                key=lambda x: x.get("priority_score") or 0,
                reverse=True,
            ),
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Batch priority assessment failed: {exc}",
        ) from exc
