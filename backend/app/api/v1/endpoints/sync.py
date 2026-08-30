"""
Offline-first data sync endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from typing import Dict, Any, List, Optional
from pydantic import BaseModel
from datetime import datetime
import json
import gzip
import hashlib
import logging
from app.core.security import get_current_user, verify_api_key, hash_api_key

router = APIRouter()
logger = logging.getLogger(__name__)


class SyncDataRequest(BaseModel):
    """Request model for sync data upload"""
    device_id: str
    data_type: str  # field_survey, shelter_update, hazard_report
    payload: Dict[str, Any]
    timestamp: str
    signature: str  # Digital signature for validation


class SyncDataResponse(BaseModel):
    """Response model for sync operations"""
    success: bool
    sync_id: str
    records_processed: int
    message: str
    server_timestamp: str


@router.post("/upload")
async def upload_sync_data(
    request: SyncDataRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Upload field data for offline-first sync
    
    - **device_id**: Unique identifier for the device
    - **data_type**: Type of data being synced
    - **payload**: Data payload
    - **timestamp**: Client timestamp
    - **signature**: Digital signature for validation
    """
    try:
        # Validate signature
        if not _validate_signature(request.device_id, request.payload, request.signature):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid signature"
            )
        
        # Process sync data
        sync_id = f"SYNC_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}_{request.device_id}"
        
        # Process based on data type
        processed_count = 0
        if request.data_type == "field_survey":
            processed_count = _process_field_survey(request.payload)
        elif request.data_type == "shelter_update":
            processed_count = _process_shelter_update(request.payload)
        elif request.data_type == "hazard_report":
            processed_count = _process_hazard_report(request.payload)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unknown data type: {request.data_type}"
            )
        
        return SyncDataResponse(
            success=True,
            sync_id=sync_id,
            records_processed=processed_count,
            message="Data synced successfully",
            server_timestamp=datetime.utcnow().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Sync upload failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync upload failed: {str(e)}"
        )


@router.post("/upload-compressed")
async def upload_compressed_sync_data(
    device_id: str,
    data_type: str,
    timestamp: str,
    signature: str,
    file: UploadFile = File(...),
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Upload compressed field data for offline-first sync
    
    - **device_id**: Unique identifier for the device
    - **data_type**: Type of data being synced
    - **timestamp**: Client timestamp
    - **signature**: Digital signature for validation
    - **file**: Compressed data file
    """
    try:
        # Read and decompress file
        compressed_data = await file.read()
        
        try:
            decompressed_data = gzip.decompress(compressed_data)
            payload = json.loads(decompressed_data.decode('utf-8'))
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Failed to decompress data: {str(e)}"
            )
        
        # Validate signature
        if not _validate_signature(device_id, payload, signature):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid signature"
            )
        
        # Process sync data
        sync_id = f"SYNC_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}_{device_id}"
        
        # Process based on data type
        processed_count = 0
        if data_type == "field_survey":
            processed_count = _process_field_survey(payload)
        elif data_type == "shelter_update":
            processed_count = _process_shelter_update(payload)
        elif data_type == "hazard_report":
            processed_count = _process_hazard_report(payload)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unknown data type: {data_type}"
            )
        
        return SyncDataResponse(
            success=True,
            sync_id=sync_id,
            records_processed=processed_count,
            message="Compressed data synced successfully",
            server_timestamp=datetime.utcnow().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Compressed sync upload failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Compressed sync upload failed: {str(e)}"
        )


@router.get("/download")
async def download_sync_data(
    device_id: str,
    last_sync_timestamp: Optional[str] = None,
    data_types: Optional[str] = None,  # Comma-separated list
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Download data for offline-first sync
    
    - **device_id**: Unique identifier for the device
    - **last_sync_timestamp**: Last sync timestamp for incremental updates
    - **data_types**: Comma-separated list of data types to download
    """
    try:
        # Determine what data to send
        requested_types = data_types.split(',') if data_types else ['red_zones', 'shelters', 'habitations']
        
        # This would query the database for actual data in production
        # For now, return sample data
        
        sample_sync_data = {
            'device_id': device_id,
            'server_timestamp': datetime.utcnow().isoformat(),
            'data': {
                'red_zones': [
                    {
                        'zone_id': 'RZ_001',
                        'hazard_type': 'LANDSLIDE',
                        'severity_level': 'HIGH',
                        'geometry': 'POLYGON((77.2 28.5, 77.3 28.5, 77.3 28.6, 77.2 28.6, 77.2 28.5))',
                        'updated_at': '2024-01-15T10:30:00Z'
                    }
                ],
                'shelters': [
                    {
                        'shelter_id': 'SHELTER_001',
                        'shelter_name': 'Community Hall 1',
                        'total_capacity': 500,
                        'available_capacity': 350,
                        'latitude': 18.52,
                        'longitude': 73.85,
                        'updated_at': '2024-01-15T11:00:00Z'
                    }
                ],
                'habitations': [
                    {
                        'habitation_id': 'HAB_001',
                        'village_name': 'Village 1',
                        'priority_category': 'IMMEDIATE',
                        'latitude': 18.5,
                        'longitude': 73.9,
                        'updated_at': '2024-01-15T12:00:00Z'
                    }
                ]
            },
            'compression_enabled': True,
            'data_size_bytes': 2048
        }
        
        # Filter by requested types
        filtered_data = {k: v for k, v in sample_sync_data['data'].items() if k in requested_types}
        sample_sync_data['data'] = filtered_data
        
        return sample_sync_data
        
    except Exception as e:
        logger.error(f"Sync download failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync download failed: {str(e)}"
        )


@router.get("/status")
async def get_sync_status(
    device_id: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Get sync status for devices
    
    - **device_id**: Optional filter by specific device
    """
    try:
        # This would query the database for actual sync status in production
        # For now, return sample data
        
        sample_sync_status = {
            'total_sync_operations': 1250,
            'successful_syncs': 1180,
            'failed_syncs': 70,
            'success_rate': 94.4,
            'recent_syncs': [
                {
                    'device_id': 'DEVICE_001',
                    'sync_timestamp': '2024-01-15T14:30:00Z',
                    'records_processed': 15,
                    'status': 'SUCCESS'
                },
                {
                    'device_id': 'DEVICE_002',
                    'sync_timestamp': '2024-01-15T14:15:00Z',
                    'records_processed': 8,
                    'status': 'SUCCESS'
                }
            ]
        }
        
        if device_id:
            # Filter for specific device
            device_syncs = [s for s in sample_sync_status['recent_syncs'] if s['device_id'] == device_id]
            return {
                'device_id': device_id,
                'recent_syncs': device_syncs,
                'total_syncs': len(device_syncs)
            }
        
        return sample_sync_status
        
    except Exception as e:
        logger.error(f"Failed to get sync status: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get sync status: {str(e)}"
        )


def _validate_signature(device_id: str, payload: Dict[str, Any], signature: str) -> bool:
    """Validate digital signature for sync data"""
    try:
        # In production, this would use proper cryptographic validation
        # For now, use a simple hash-based validation
        
        # Create a hash of the payload
        payload_str = json.dumps(payload, sort_keys=True)
        payload_hash = hashlib.sha256((device_id + payload_str).encode()).hexdigest()
        
        # Compare with provided signature (simplified validation)
        # In production, this would use proper digital signature verification
        return signature == payload_hash
        
    except Exception as e:
        logger.error(f"Signature validation failed: {str(e)}")
        return False


def _process_field_survey(payload: Dict[str, Any]) -> int:
    """Process field survey data"""
    # This would insert field survey data into the database in production
    # For now, just count the records
    records = payload.get('records', [])
    logger.info(f"Processing {len(records)} field survey records")
    return len(records)


def _process_shelter_update(payload: Dict[str, Any]) -> int:
    """Process shelter update data"""
    # This would update shelter data in the database in production
    # For now, just count the records
    records = payload.get('records', [])
    logger.info(f"Processing {len(records)} shelter update records")
    return len(records)


def _process_hazard_report(payload: Dict[str, Any]) -> int:
    """Process hazard report data"""
    # This would insert hazard report data into the database in production
    # For now, just count the records
    records = payload.get('records', [])
    logger.info(f"Processing {len(records)} hazard report records")
    return len(records)