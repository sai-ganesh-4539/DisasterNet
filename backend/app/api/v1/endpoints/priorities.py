"""
Relocation prioritization endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from app.ml.priority_classifier import priority_classifier
from app.ml.model_registry import get_model
from app.core.security import get_current_user

router = APIRouter()


class PriorityFilterRequest(BaseModel):
    """Request model for filtering by priority"""
    state_code: Optional[str] = None
    district_code: Optional[str] = None
    priority_category: Optional[str] = None
    min_priority_score: Optional[float] = None
    limit: int = 50
    offset: int = 0


@router.get("/")
async def get_priorities(
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    priority_category: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get prioritized habitations for relocation
    
    - **state_code**: Filter by state code
    - **district_code**: Filter by district code
    - **priority_category**: Filter by priority category (IMMEDIATE, SHORT_TERM, MEDIUM_TERM)
    - **limit**: Maximum number of results
    - **offset**: Offset for pagination
    """
    try:
        # This would query the database in production
        # For now, return sample data
        
        sample_priorities = [
            {
                'habitation_id': 'HAB_001',
                'village_name': 'Village 1',
                'state_code': 'MH',
                'district_name': 'PUNE',
                'total_population': 500,
                'priority_score': 85.5,
                'priority_category': 'IMMEDIATE',
                'time_horizon': {
                    'name': 'Immediate',
                    'max_hours': 24,
                    'description': 'Critical priority - evacuation required'
                },
                'reason': 'Located within 0.5km of active red zone'
            },
            {
                'habitation_id': 'HAB_002',
                'village_name': 'Village 2',
                'state_code': 'MH',
                'district_name': 'NASHIK',
                'total_population': 750,
                'priority_score': 65.0,
                'priority_category': 'SHORT_TERM',
                'time_horizon': {
                    'name': 'Short-Term',
                    'min_weeks': 1,
                    'max_weeks': 4,
                    'description': 'High priority - pre-stage assets'
                },
                'reason': 'High vulnerability with limited road access'
            },
            {
                'habitation_id': 'HAB_003',
                'village_name': 'Village 3',
                'state_code': 'KA',
                'district_name': 'BENGALURU',
                'total_population': 300,
                'priority_score': 45.0,
                'priority_category': 'MEDIUM_TERM',
                'time_horizon': {
                    'name': 'Medium-Term',
                    'min_months': 1,
                    'max_months': 6,
                    'description': 'Moderate priority - planned relocation'
                },
                'reason': 'Long-term erosion trends'
            }
        ]
        
        # Apply filters
        filtered_priorities = sample_priorities
        if state_code:
            filtered_priorities = [p for p in filtered_priorities if p.get('state_code') == state_code]
        if district_code:
            filtered_priorities = [p for p in filtered_priorities if p.get('district_name') == district_code]
        if priority_category:
            filtered_priorities = [p for p in filtered_priorities if p.get('priority_category') == priority_category.upper()]
        
        # Sort by priority score
        filtered_priorities.sort(key=lambda x: x.get('priority_score', 0), reverse=True)
        
        # Apply pagination
        paginated_priorities = filtered_priorities[offset:offset + limit]
        
        return {
            'count': len(filtered_priorities),
            'limit': limit,
            'offset': offset,
            'priorities': paginated_priorities,
            'summary': {
                'immediate_count': len([p for p in filtered_priorities if p.get('priority_category') == 'IMMEDIATE']),
                'short_term_count': len([p for p in filtered_priorities if p.get('priority_category') == 'SHORT_TERM']),
                'medium_term_count': len([p for p in filtered_priorities if p.get('priority_category') == 'MEDIUM_TERM'])
            }
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get priorities: {str(e)}"
        )


@router.get("/immediate")
async def get_immediate_priorities(
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    limit: int = 20,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get immediate priority habitations (0-24 hours)
    
    - **state_code**: Filter by state code
    - **district_code**: Filter by district code
    - **limit**: Maximum number of results
    """
    try:
        # Get all priorities with IMMEDIATE filter
        result = await get_priorities(
            state_code=state_code,
            district_code=district_code,
            priority_category='IMMEDIATE',
            limit=limit,
            offset=0,
            current_user=current_user
        )
        
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get immediate priorities: {str(e)}"
        )


@router.get("/short-term")
async def get_short_term_priorities(
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    limit: int = 20,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get short-term priority habitations (1-4 weeks)
    
    - **state_code**: Filter by state code
    - **district_code**: Filter by district code
    - **limit**: Maximum number of results
    """
    try:
        # Get all priorities with SHORT_TERM filter
        result = await get_priorities(
            state_code=state_code,
            district_code=district_code,
            priority_category='SHORT_TERM',
            limit=limit,
            offset=0,
            current_user=current_user
        )
        
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get short-term priorities: {str(e)}"
        )


@router.get("/medium-term")
async def get_medium_term_priorities(
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    limit: int = 20,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get medium-term priority habitations (1-6 months)
    
    - **state_code**: Filter by state code
    - **district_code**: Filter by district code
    - **limit**: Maximum number of results
    """
    try:
        # Get all priorities with MEDIUM_TERM filter
        result = await get_priorities(
            state_code=state_code,
            district_code=district_code,
            priority_category='MEDIUM_TERM',
            limit=limit,
            offset=0,
            current_user=current_user
        )
        
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get medium-term priorities: {str(e)}"
        )


@router.get("/summary")
async def get_priority_summary(
    state_code: Optional[str] = None,
    district_code: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get summary statistics for relocation priorities
    
    - **state_code**: Filter by state code
    - **district_code**: Filter by district code
    """
    try:
        # This would calculate statistics from the database in production
        # For now, return sample data
        
        sample_summary = {
            'total_habitations': 150,
            'prioritized_habitations': 85,
            'priority_distribution': {
                'immediate': 15,
                'short_term': 35,
                'medium_term': 35
            },
            'population_at_risk': {
                'immediate': 7500,
                'short_term': 17500,
                'medium_term': 12500
            },
            'geographic_distribution': {
                'states': 5,
                'districts': 12
            },
            'resource_requirements': {
                'total_shelter_capacity_needed': 37500,
                'immediate_capacity_needed': 7500,
                'short_term_capacity_needed': 17500,
                'medium_term_capacity_needed': 12500
            }
        }
        
        return sample_summary
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get priority summary: {str(e)}"
        )