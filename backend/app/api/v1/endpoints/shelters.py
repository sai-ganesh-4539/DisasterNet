"""
Shelter capacity and suitability endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from app.ml.capacity_evaluator import capacity_evaluator
from app.ml.model_registry import get_model
from app.core.security import get_current_user

router = APIRouter()


class ShelterCapacityRequest(BaseModel):
    """Request model for shelter capacity evaluation"""
    shelter_id: str
    shelter_name: str
    total_capacity: int
    current_occupancy: int
    physical_beds: int
    water_sufficiency_days: float
    food_ration_storage_days: float
    medical_facility_depth: str
    geometry: str  # WKT format
    road_accessibility: str
    nearest_red_zone_distance_km: float
    electricity: bool
    water_supply: bool
    sanitation_facilities: bool


class ShelterSafetyRequest(BaseModel):
    """Request model for shelter safety evaluation"""
    shelter_geometry: str
    red_zone_geometries: List[str]


@router.get("/")
async def get_shelters(
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    shelter_type: Optional[str] = None,
    status: str = "OPERATIONAL",
    limit: int = 50,
    offset: int = 0,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get shelters with optional filters
    
    - **state_code**: Filter by state code
    - **district_code**: Filter by district code
    - **shelter_type**: Filter by shelter type
    - **status**: Filter by status (default: OPERATIONAL)
    - **limit**: Maximum number of results
    - **offset**: Offset for pagination
    """
    try:
        # This would query the database in production
        # For now, return sample data
        
        sample_shelters = [
            {
                'shelter_id': 'SHELTER_001',
                'shelter_name': 'Community Hall 1',
                'shelter_type': 'COMMUNITY',
                'state_code': 'MH',
                'district_name': 'PUNE',
                'total_capacity': 500,
                'current_occupancy': 150,
                'available_capacity': 350,
                'effective_capacity': 350,
                'latitude': 18.52,
                'longitude': 73.85,
                'operational_status': 'OPERATIONAL',
                'safety_check_passed': True
            },
            {
                'shelter_id': 'SHELTER_002',
                'shelter_name': 'School Building 1',
                'shelter_type': 'SCHOOL',
                'state_code': 'MH',
                'district_name': 'NASHIK',
                'total_capacity': 300,
                'current_occupancy': 50,
                'available_capacity': 250,
                'effective_capacity': 250,
                'latitude': 19.95,
                'longitude': 73.78,
                'operational_status': 'OPERATIONAL',
                'safety_check_passed': True
            }
        ]
        
        # Apply filters
        filtered_shelters = sample_shelters
        if state_code:
            filtered_shelters = [s for s in filtered_shelters if s.get('state_code') == state_code]
        if district_code:
            filtered_shelters = [s for s in filtered_shelters if s.get('district_name') == district_code]
        if shelter_type:
            filtered_shelters = [s for s in filtered_shelters if s.get('shelter_type') == shelter_type.upper()]
        if status:
            filtered_shelters = [s for s in filtered_shelters if s.get('operational_status') == status.upper()]
        
        # Apply pagination
        paginated_shelters = filtered_shelters[offset:offset + limit]
        
        return {
            'count': len(filtered_shelters),
            'limit': limit,
            'offset': offset,
            'shelters': paginated_shelters
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get shelters: {str(e)}"
        )


@router.get("/capacity")
async def get_shelter_capacity(
    shelter_id: Optional[str] = None,
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get shelter capacity information
    
    - **shelter_id**: Specific shelter ID
    - **state_code**: Filter by state code
    - **district_code**: Filter by district code
    """
    try:
        # This would query the database in production
        # For now, return sample data
        
        sample_capacity = {
            'shelter_id': shelter_id or 'SHELTER_001',
            'total_capacity': 500,
            'current_occupancy': 150,
            'available_capacity': 350,
            'effective_capacity': 350,
            'capacity_constraint': 'NONE',
            'utilization_percentage': 30.0,
            'capacity_status': 'LOW',
            'resource_breakdown': {
                'physical_beds': 500,
                'water_sufficiency_days': 14.0,
                'food_ration_storage_days': 21.0,
                'medical_facility_depth': 'FULL'
            }
        }
        
        return sample_capacity
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get shelter capacity: {str(e)}"
        )


@router.post("/evaluate")
async def evaluate_shelter(
    request: ShelterCapacityRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Evaluate shelter capacity and suitability
    
    - **shelter_id**: Unique identifier for the shelter
    - **shelter_name**: Name of the shelter
    - **total_capacity**: Total capacity
    - **current_occupancy**: Current occupancy
    - **physical_beds**: Number of physical beds
    - **water_sufficiency_days**: Days of water sufficiency
    - **food_ration_storage_days**: Days of food storage
    - **medical_facility_depth**: Medical facility depth
    - **geometry**: Shelter location in WKT format
    - **road_accessibility**: Road accessibility
    - **nearest_red_zone_distance_km**: Distance to nearest red zone
    - **electricity**: Electricity availability
    - **water_supply**: Water supply availability
    - **sanitation_facilities**: Sanitation facilities availability
    """
    try:
        # Get capacity evaluator model
        model = get_model("capacity_evaluator")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Capacity evaluator model not available"
            )
        
        # Prepare features
        features = request.dict()
        
        # Make capacity prediction
        capacity_result = model.predict(features)
        
        return capacity_result
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Shelter evaluation failed: {str(e)}"
        )


@router.post("/evaluate-safety")
async def evaluate_shelter_safety(
    request: ShelterSafetyRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Evaluate shelter safety against red zones
    
    - **shelter_geometry**: Shelter location in WKT format
    - **red_zone_geometries**: List of red zone geometries in WKT format
    """
    try:
        # Get capacity evaluator model
        model = get_model("capacity_evaluator")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Capacity evaluator model not available"
            )
        
        # Evaluate safety intersect
        safety_result = model.evaluate_safety_intersect(
            request.shelter_geometry,
            request.red_zone_geometries
        )
        
        return safety_result
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Safety evaluation failed: {str(e)}"
        )


@router.post("/evaluate-suitability")
async def evaluate_shelter_suitability(
    capacity_request: ShelterCapacityRequest,
    red_zone_geometries: List[str],
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Comprehensive shelter suitability evaluation
    
    - **capacity_request**: Shelter capacity and features
    - **red_zone_geometries**: List of red zone geometries in WKT format
    """
    try:
        # Get capacity evaluator model
        model = get_model("capacity_evaluator")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Capacity evaluator model not available"
            )
        
        # Prepare features
        features = capacity_request.dict()
        
        # Evaluate comprehensive suitability
        suitability_result = model.evaluate_shelter_suitability(features, red_zone_geometries)
        
        return suitability_result
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Suitability evaluation failed: {str(e)}"
        )