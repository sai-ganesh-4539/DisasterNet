"""
Habitation analysis endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from app.ml.priority_classifier import priority_classifier
from app.ml.model_registry import get_model
from app.core.security import get_current_user

router = APIRouter()


class HabitationRiskRequest(BaseModel):
    """Request model for habitation risk assessment"""
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
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    priority_category: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get habitations with optional filters
    
    - **state_code**: Filter by state code
    - **district_code**: Filter by district code
    - **priority_category**: Filter by priority category
    - **limit**: Maximum number of results
    - **offset**: Offset for pagination
    """
    try:
        # This would query the database in production
        # For now, return sample data
        
        sample_habitations = [
            {
                'habitation_id': 'HAB_001',
                'village_name': 'Village 1',
                'state_code': 'MH',
                'district_name': 'PUNE',
                'total_population': 500,
                'latitude': 18.5,
                'longitude': 73.9,
                'priority_score': 85.5,
                'priority_category': 'IMMEDIATE',
                'red_zone_proximity_km': 0.5
            },
            {
                'habitation_id': 'HAB_002',
                'village_name': 'Village 2',
                'state_code': 'MH',
                'district_name': 'NASHIK',
                'total_population': 750,
                'latitude': 19.9,
                'longitude': 73.8,
                'priority_score': 65.0,
                'priority_category': 'SHORT_TERM',
                'red_zone_proximity_km': 3.5
            }
        ]
        
        # Apply filters
        filtered_habitations = sample_habitations
        if state_code:
            filtered_habitations = [h for h in filtered_habitations if h.get('state_code') == state_code]
        if district_code:
            filtered_habitations = [h for h in filtered_habitations if h.get('district_name') == district_code]
        if priority_category:
            filtered_habitations = [h for h in filtered_habitations if h.get('priority_category') == priority_category.upper()]
        
        # Apply pagination
        paginated_habitations = filtered_habitations[offset:offset + limit]
        
        return {
            'count': len(filtered_habitations),
            'limit': limit,
            'offset': offset,
            'habitations': paginated_habitations
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get habitations: {str(e)}"
        )


@router.get("/{habitation_id}/risk")
async def get_habitation_risk(
    habitation_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get risk assessment for a specific habitation"""
    try:
        # This would query the database and calculate risk in production
        # For now, return sample data
        
        sample_risk_assessment = {
            'habitation_id': habitation_id,
            'village_name': 'Village 1',
            'total_population': 500,
            'vulnerability_score': 72.5,
            'hazard_exposure_score': 85.0,
            'access_limitations_score': 68.0,
            'overall_risk_score': 75.0,
            'risk_level': 'HIGH',
            'red_zone_proximity_km': 0.5,
            'current_red_zone_id': 'RZ_001',
            'evacuation_time_hours': 4.5,
            'assessment_timestamp': '2024-01-15T14:00:00Z'
        }
        
        return sample_risk_assessment
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get habitation risk: {str(e)}"
        )


@router.post("/assess")
async def assess_habitation_priority(
    request: HabitationRiskRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Assess relocation priority for a habitation
    
    - **habitation_id**: Unique identifier for the habitation
    - **latitude**: Location latitude
    - **longitude**: Location longitude
    - **total_population**: Total population
    - **elderly_percentage**: Percentage of elderly population
    - **child_percentage**: Percentage of children
    - **disability_percentage**: Percentage of disabled population
    - **population_density_per_sqkm**: Population density
    - **economic_status**: Economic status (BPL, APL, MIXED)
    - **road_connectivity**: Road connectivity type
    - **road_distance_km**: Distance to main road in km
    - **nearest_emergency_km**: Distance to emergency services in km
    - **communication_availability**: Communication availability
    - **evacuation_route_status**: Evacuation route status
    - **evacuation_time_hours**: Estimated evacuation time in hours
    - **red_zone_proximity_km**: Distance to nearest red zone in km
    - **current_risk_score**: Current risk score (optional)
    - **hazard_history**: List of past hazard events
    - **disaster_frequency_score**: Score based on disaster history
    """
    try:
        # Get priority classifier model
        model = get_model("priority_classifier")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Priority classifier model not available"
            )
        
        # Prepare features
        features = request.dict()
        
        # Make prediction
        priority_assessment = model.predict(features)
        
        return priority_assessment
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Priority assessment failed: {str(e)}"
        )


@router.post("/assess-batch")
async def assess_habitations_batch(
    habitations: List[HabitationRiskRequest],
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Assess relocation priorities for multiple habitations
    
    - **habitations**: List of habitation features
    """
    try:
        # Get priority classifier model
        model = get_model("priority_classifier")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Priority classifier model not available"
            )
        
        # Prepare features
        features_list = [habitation.dict() for habitation in habitations]
        
        # Make batch predictions
        priority_assessments = model.predict_batch(features_list)
        
        # Categorize by priority
        immediate = [p for p in priority_assessments if p.get('priority_category') == 'IMMEDIATE']
        short_term = [p for p in priority_assessments if p.get('priority_category') == 'SHORT_TERM']
        medium_term = [p for p in priority_assessments if p.get('priority_category') == 'MEDIUM_TERM']
        
        return {
            'total_habitations': len(habitations),
            'assessments': priority_assessments,
            'summary': {
                'immediate_count': len(immediate),
                'short_term_count': len(short_term),
                'medium_term_count': len(medium_term)
            },
            'prioritized_list': sorted(priority_assessments, key=lambda x: x.get('priority_score', 0), reverse=True)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Batch priority assessment failed: {str(e)}"
        )