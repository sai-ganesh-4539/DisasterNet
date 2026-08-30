"""Dynamic shelter capacity and site suitability endpoints."""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel

from app.core.security import get_current_user_optional
from app.ml.model_registry import get_model
from app.services.field_updates import field_update_store
from app.services.live_gis import INDIA_BBOX, build_snapshot, evaluate_candidate_site

router = APIRouter()


class ShelterCapacityRequest(BaseModel):
    shelter_id: str
    shelter_name: str
    total_capacity: int
    current_occupancy: int
    physical_beds: int
    water_sufficiency_days: float
    food_ration_storage_days: float
    medical_facility_depth: str
    geometry: str
    road_accessibility: str
    nearest_red_zone_distance_km: float
    electricity: bool
    water_supply: bool
    sanitation_facilities: bool


class ShelterSafetyRequest(BaseModel):
    shelter_geometry: str
    red_zone_geometries: List[str]


class CandidateSiteRequest(BaseModel):
    site_name: str
    district_name: str = ""
    state_code: str = "IN"
    latitude: float
    longitude: float
    hectares: float = 2.0
    road_distance_km: float = 1.0
    water_supply: bool = True
    sanitation_facilities: bool = True
    electricity: bool = True
    medical_facility_depth: str = "BASIC"


@router.get("/")
async def get_shelters(
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    shelter_type: Optional[str] = None,
    status_filter: str = "OPERATIONAL",
    limit: int = 50,
    offset: int = 0,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        snapshot = build_snapshot(south=south, west=west, north=north, east=east)
        shelters = list(snapshot.get("shelters", []))
        if state_code:
            shelters = [
                s
                for s in shelters
                if str(s.get("state_code", "")).upper() == state_code.upper()
            ]
        if district_code:
            district_upper = district_code.upper()
            shelters = [
                s
                for s in shelters
                if district_upper in str(s.get("district_name", "")).upper()
            ]
        if shelter_type:
            shelters = [
                s
                for s in shelters
                if str(s.get("shelter_type", "")).upper() == shelter_type.upper()
            ]
        if status_filter.upper() == "SAFE":
            shelters = [s for s in shelters if s.get("is_in_safe_zone")]
        total = len(shelters)
        return {
            "count": total,
            "limit": limit,
            "offset": offset,
            "generated_at": snapshot.get("generated_at"),
            "cache_hit": snapshot.get("cache_hit", False),
            "shelters": shelters[offset : offset + limit],
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to build live shelter list: {exc}",
        ) from exc


@router.get("/capacity")
async def get_shelter_capacity(
    shelter_id: Optional[str] = None,
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    snapshot = build_snapshot(south=south, west=west, north=north, east=east)
    shelters = list(snapshot.get("shelters", []))
    if shelter_id:
        shelter = next((s for s in shelters if s.get("shelter_id") == shelter_id), None)
        if shelter is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Shelter not found: {shelter_id}",
            )
        return shelter
    if state_code:
        shelters = [
            s
            for s in shelters
            if str(s.get("state_code", "")).upper() == state_code.upper()
        ]
    if district_code:
        district_upper = district_code.upper()
        shelters = [
            s
            for s in shelters
            if district_upper in str(s.get("district_name", "")).upper()
        ]
    return {
        "generated_at": snapshot.get("generated_at"),
        "shelter_count": len(shelters),
        "total_capacity": sum(int(s.get("total_capacity") or 0) for s in shelters),
        "effective_capacity": sum(
            int(s.get("effective_capacity") or 0) for s in shelters
        ),
        "available_capacity": sum(
            int(s.get("available_capacity") or 0) for s in shelters
        ),
        "safe_shelter_count": len([s for s in shelters if s.get("is_in_safe_zone")]),
        "primary_constraints": {
            key: len([s for s in shelters if s.get("capacity_constraint") == key])
            for key in ["NONE", "BEDS", "WATER", "FOOD", "MEDICAL"]
        },
    }


@router.post("/evaluate")
async def evaluate_shelter(
    request: ShelterCapacityRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        model = get_model("capacity_evaluator")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Capacity evaluator model not available",
            )
        return model.predict(request.dict())
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Shelter evaluation failed: {exc}",
        ) from exc


@router.post("/evaluate-safety")
async def evaluate_shelter_safety(
    request: ShelterSafetyRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        model = get_model("capacity_evaluator")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Capacity evaluator model not available",
            )
        return model.evaluate_safety_intersect(
            request.shelter_geometry, request.red_zone_geometries
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Safety evaluation failed: {exc}",
        ) from exc


@router.post("/evaluate-suitability")
async def evaluate_shelter_suitability(
    capacity_request: ShelterCapacityRequest,
    red_zone_geometries: List[str],
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        model = get_model("capacity_evaluator")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Capacity evaluator model not available",
            )
        return model.evaluate_shelter_suitability(
            capacity_request.dict(), red_zone_geometries
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Suitability evaluation failed: {exc}",
        ) from exc


@router.post("/evaluate-site")
async def evaluate_site(
    request: CandidateSiteRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        return evaluate_candidate_site(**request.dict())
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Candidate site evaluation failed: {exc}",
        ) from exc


@router.post("/register-candidate")
async def register_candidate_site(
    request: CandidateSiteRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    try:
        evaluation = evaluate_candidate_site(**request.dict())
        shelter_id = evaluation["candidate_site_id"]
        registered = {
            "shelter_id": shelter_id,
            "state_code": request.state_code,
            "district_name": request.district_name,
            "shelter_name": request.site_name,
            "shelter_type": "GREENFIELD_SITE",
            "latitude": request.latitude,
            "longitude": request.longitude,
            "total_capacity": evaluation["capacity"]["planned_population_capacity"],
            "effective_capacity": evaluation["capacity_evaluation"][
                "effective_capacity"
            ],
            "available_capacity": evaluation["capacity_evaluation"][
                "available_capacity"
            ],
            "utilization_percentage": evaluation["capacity_evaluation"][
                "utilization_percentage"
            ],
            "current_population": 0,
            "water_available_liters": evaluation["capacity"]["water_available_liters"],
            "food_available_kg": evaluation["capacity"]["food_available_kg"],
            "medical_kits_available": 24
            if request.medical_facility_depth == "FULL"
            else 8,
            "generator_fuel_liters": 120 if request.electricity else 0,
            "capacity_constraint": evaluation["capacity_evaluation"][
                "capacity_constraint"
            ],
            "capacity_status": evaluation["capacity_evaluation"]["capacity_status"],
            "is_in_safe_zone": evaluation["safety_evaluation"].get(
                "safety_check_passed", False
            ),
            "safety_buffer_km": evaluation["nearest_red_zone_distance_km"],
            "overall_suitability": evaluation["overall_suitability"],
            "safety_score": evaluation["safety_score"],
            "has_generator": request.electricity,
            "has_medical_facility": request.medical_facility_depth in {"FULL", "BASIC"},
            "has_kitchen": True,
            "has_toilets": request.sanitation_facilities,
            "access_road_status": "CLEAR"
            if request.road_distance_km <= 1.0
            else "LIMITED",
            "geometry_wkt": evaluation["geometry_wkt"],
            "evaluation_timestamp": evaluation["evaluated_at"],
            "model_version": "live-dss-3.1",
            "is_synced": True,
            "field_survey_notes": f"Registered from live site evaluation. Recommendation: {evaluation['recommendation']}",
            "last_field_visit": evaluation["evaluated_at"],
            "surveyor_id": (current_user or {}).get("username") or "device-field-node",
        }
        field_update_store.register_candidate_site(registered)
        return {
            "success": True,
            "message": "Candidate site registered in live operational dataset",
            "candidate_site": registered,
            "evaluation": evaluation,
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Candidate site registration failed: {exc}",
        ) from exc
