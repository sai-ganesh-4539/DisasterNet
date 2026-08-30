"""
Red zone management endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from app.core.spatial import polygons_to_geojson
from app.core.security import get_current_user

router = APIRouter()


class RedZoneCreateRequest(BaseModel):
    """Request model for creating a red zone"""
    zone_id: str
    hazard_type: str
    severity_level: str
    geometry: str  # WKT format
    confidence_score: Optional[float] = 75.0
    detection_method: str = "AI_PREDICTION"


class RedZoneUpdateRequest(BaseModel):
    """Request model for updating a red zone"""
    severity_level: Optional[str] = None
    validation_status: Optional[str] = None
    status: Optional[str] = None


@router.get("/")
async def get_red_zones(
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    hazard_type: Optional[str] = None,
    status: str = "ACTIVE",
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get red zones with optional filters
    
    - **state_code**: Filter by state code
    - **district_code**: Filter by district code
    - **hazard_type**: Filter by hazard type
    - **status**: Filter by status (default: ACTIVE)
    """
    try:
        # This would query the database in production
        # For now, return sample data
        
        sample_red_zones = [
            {
                'zone_id': 'RZ_001',
                'hazard_type': 'LANDSLIDE',
                'severity_level': 'HIGH',
                'geometry': 'POLYGON((77.2 28.5, 77.3 28.5, 77.3 28.6, 77.2 28.6, 77.2 28.5))',
                'center_lat': 28.55,
                'center_lon': 77.25,
                'area_sq_km': 12.5,
                'status': 'ACTIVE',
                'detection_timestamp': '2024-01-15T10:30:00Z',
                'confidence_score': 85.0
            },
            {
                'zone_id': 'RZ_002',
                'hazard_type': 'FLOOD',
                'severity_level': 'CRITICAL',
                'geometry': 'POLYGON((75.8 19.0, 76.0 19.0, 76.0 19.2, 75.8 19.2, 75.8 19.0))',
                'center_lat': 19.1,
                'center_lon': 75.9,
                'area_sq_km': 25.0,
                'status': 'ACTIVE',
                'detection_timestamp': '2024-01-15T11:00:00Z',
                'confidence_score': 90.0
            }
        ]
        
        # Apply filters
        filtered_zones = sample_red_zones
        if state_code:
            filtered_zones = [z for z in filtered_zones if z.get('state_code') == state_code]
        if district_code:
            filtered_zones = [z for z in filtered_zones if z.get('district_code') == district_code]
        if hazard_type:
            filtered_zones = [z for z in filtered_zones if z.get('hazard_type') == hazard_type.upper()]
        if status:
            filtered_zones = [z for z in filtered_zones if z.get('status') == status.upper()]
        
        # Convert to GeoJSON
        geojson = polygons_to_geojson(filtered_zones)
        
        return {
            'count': len(filtered_zones),
            'red_zones': filtered_zones,
            'geojson': geojson
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get red zones: {str(e)}"
        )


@router.get("/{zone_id}")
async def get_red_zone(
    zone_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get a specific red zone by ID"""
    try:
        # This would query the database in production
        # For now, return sample data
        
        sample_zone = {
            'zone_id': zone_id,
            'hazard_type': 'LANDSLIDE',
            'severity_level': 'HIGH',
            'geometry': 'POLYGON((77.2 28.5, 77.3 28.5, 77.3 28.6, 77.2 28.6, 77.2 28.5))',
            'center_lat': 28.55,
            'center_lon': 77.25,
            'area_sq_km': 12.5,
            'grid_cells_count': 45,
            'average_risk_score': 82.5,
            'max_risk_score': 95.0,
            'state_code': 'MH',
            'district_code': 'PUNE',
            'estimated_population': 1250,
            'household_count': 250,
            'status': 'ACTIVE',
            'validation_status': 'VALIDATED',
            'detection_timestamp': '2024-01-15T10:30:00Z',
            'confidence_score': 85.0,
            'detection_method': 'AI_PREDICTION'
        }
        
        return sample_zone
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get red zone: {str(e)}"
        )


@router.post("/")
async def create_red_zone(
    request: RedZoneCreateRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Create a new red zone
    
    - **zone_id**: Unique identifier for the red zone
    - **hazard_type**: Type of hazard (LANDSLIDE, FLOOD, COASTAL_EROSION, CLOUDBURST)
    - **severity_level**: Severity level (LOW, MEDIUM, HIGH, CRITICAL)
    - **geometry**: Red zone boundary in WKT format
    - **confidence_score**: Confidence in detection (0-100)
    - **detection_method**: Method of detection (AI_PREDICTION, MANUAL, SATELLITE)
    """
    try:
        # This would insert into the database in production
        # For now, just return success
        
        return {
            'success': True,
            'zone_id': request.zone_id,
            'message': 'Red zone created successfully',
            'created_by': current_user.get('username'),
            'created_at': '2024-01-15T12:00:00Z'
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create red zone: {str(e)}"
        )


@router.put("/{zone_id}")
async def update_red_zone(
    zone_id: str,
    request: RedZoneUpdateRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Update an existing red zone
    
    - **severity_level**: New severity level
    - **validation_status**: New validation status
    - **status**: New status
    """
    try:
        # This would update the database in production
        # For now, just return success
        
        return {
            'success': True,
            'zone_id': zone_id,
            'message': 'Red zone updated successfully',
            'updated_by': current_user.get('username'),
            'updated_at': '2024-01-15T12:30:00Z'
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update red zone: {str(e)}"
        )


@router.delete("/{zone_id}")
async def delete_red_zone(
    zone_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Delete a red zone"""
    try:
        # This would delete from the database in production
        # For now, just return success
        
        return {
            'success': True,
            'zone_id': zone_id,
            'message': 'Red zone deleted successfully',
            'deleted_by': current_user.get('username'),
            'deleted_at': '2024-01-15T13:00:00Z'
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete red zone: {str(e)}"
        )