"""
Data ingestion status and management endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from typing import Dict, Any, Optional
from pydantic import BaseModel
from app.ingestion.scheduler import DataIngestionScheduler
from app.core.security import get_current_user, check_permission

router = APIRouter()

# Global scheduler instance
data_scheduler = DataIngestionScheduler()


class DataIngestionTriggerRequest(BaseModel):
    """Request model for triggering data ingestion"""
    source: str  # isro_bhuvan, imd_rainfall, census


@router.get("/status")
async def get_data_status(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get current data ingestion status"""
    try:
        # This would query the database for actual status in production
        # For now, return sample data
        
        sample_status = {
            'last_ingestion': {
                'isro_bhuvan': '2024-01-14T02:00:00Z',
                'imd_rainfall': '2024-01-15T01:00:00Z',
                'census': '2024-01-01T00:00:00Z'
            },
            'next_scheduled': {
                'isro_bhuvan': '2024-01-21T02:00:00Z',
                'imd_rainfall': '2024-01-15T02:00:00Z',
                'census': '2025-01-01T00:00:00Z'
            },
            'data_freshness': {
                'terrain_data': 'STALE',  # 1 day old
                'weather_data': 'FRESH',  # 1 hour old
                'census_data': 'CURRENT'  # 1 year old
            },
            'record_counts': {
                'hazard_grids': 50000,
                'environmental_data': 150000,
                'census_data': 45000,
                'habitations': 12000,
                'shelters': 3500
            },
            'system_status': 'OPERATIONAL'
        }
        
        return sample_status
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get data status: {str(e)}"
        )


@router.post("/trigger")
async def trigger_data_ingestion(
    request: DataIngestionTriggerRequest,
    background_tasks: BackgroundTasks,
    current_user: Dict[str, Any] = Depends(check_permission("WRITE_FIELD_DATA"))
):
    """
    Trigger manual data ingestion for a specific source
    
    - **source**: Data source to ingest (isro_bhuvan, imd_rainfall, census)
    """
    try:
        # Validate source
        valid_sources = ['isro_bhuvan', 'imd_rainfall', 'census']
        if request.source not in valid_sources:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid source. Must be one of: {valid_sources}"
            )
        
        # Trigger ingestion in background
        def run_ingestion():
            result = data_scheduler.run_manual_ingestion(request.source)
            return result
        
        background_tasks.add_task(run_ingestion)
        
        return {
            'success': True,
            'message': f'Data ingestion triggered for {request.source}',
            'triggered_by': current_user.get('username'),
            'source': request.source
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to trigger data ingestion: {str(e)}"
        )


@router.get("/sources")
async def get_data_sources(
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get available data sources and their configuration"""
    try:
        from app.core.config import yaml_config
        
        ingestion_config = yaml_config.get('data_ingestion', {})
        
        sources_info = {
            'isro_bhuvan': {
                'enabled': ingestion_config.get('isro_bhuvan', {}).get('enabled', True),
                'update_frequency': ingestion_config.get('isro_bhuvan', {}).get('update_frequency', 'weekly'),
                'data_types': ingestion_config.get('isro_bhuvan', {}).get('data_types', []),
                'description': 'ISRO Bhuvan terrain and environmental data'
            },
            'imd_rainfall': {
                'enabled': ingestion_config.get('imd_rainfall', {}).get('enabled', True),
                'update_frequency': ingestion_config.get('imd_rainfall', {}).get('update_frequency', 'hourly'),
                'api_type': ingestion_config.get('imd_rainfall', {}).get('api_type', 'live'),
                'description': 'IMD rainfall and weather data'
            },
            'census': {
                'enabled': ingestion_config.get('census', {}).get('enabled', True),
                'update_frequency': ingestion_config.get('census', {}).get('update_frequency', 'yearly'),
                'api_type': ingestion_config.get('census', {}).get('api_type', 'batch'),
                'description': 'Census demographic and socio-economic data'
            }
        }
        
        return {
            'sources': sources_info,
            'scheduler_status': 'ACTIVE' if data_scheduler.is_running else 'INACTIVE'
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get data sources: {str(e)}"
        )


@router.get("/quality")
async def get_data_quality(
    source: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get data quality metrics
    
    - **source**: Optional filter by data source
    """
    try:
        # This would calculate actual quality metrics from the database in production
        # For now, return sample data
        
        sample_quality = {
            'overall_quality_score': 87.5,
            'quality_level': 'GOOD',
            'source_quality': {
                'isro_bhuvan': {
                    'completeness': 92.0,
                    'consistency': 88.0,
                    'freshness': 85.0,
                    'overall_score': 88.3,
                    'quality_level': 'GOOD'
                },
                'imd_rainfall': {
                    'completeness': 95.0,
                    'consistency': 90.0,
                    'freshness': 95.0,
                    'overall_score': 93.3,
                    'quality_level': 'EXCELLENT'
                },
                'census': {
                    'completeness': 85.0,
                    'consistency': 82.0,
                    'freshness': 75.0,
                    'overall_score': 80.7,
                    'quality_level': 'GOOD'
                }
            },
            'quality_issues': [
                {
                    'source': 'census',
                    'issue_type': 'STALE_DATA',
                    'severity': 'MEDIUM',
                    'description': 'Census data is 1 year old'
                }
            ]
        }
        
        if source:
            if source in sample_quality['source_quality']:
                return {
                    'source': source,
                    **sample_quality['source_quality'][source]
                }
            else:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Source not found: {source}"
                )
        
        return sample_quality
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get data quality: {str(e)}"
        )