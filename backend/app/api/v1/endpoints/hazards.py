"""
Hazard prediction endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from app.ml.hazard_predictor import hazard_predictor
from app.ml.model_registry import get_model
from app.core.security import get_current_user

router = APIRouter()


class HazardPredictionRequest(BaseModel):
    """Request model for hazard prediction"""
    latitude: float
    longitude: float
    precipitation_24h_mm: float
    precipitation_72h_mm: float
    slope_percentage: float
    elevation: float
    lithology: str
    soil_moisture_index: float
    vegetation_index: float
    hazard_type: str = "landslide"
    region: Optional[str] = None


class BatchHazardPredictionRequest(BaseModel):
    """Request model for batch hazard prediction"""
    grid_cells: List[HazardPredictionRequest]
    generate_red_zones: bool = True
    min_cluster_size: int = 5


class HazardPredictionResponse(BaseModel):
    """Response model for hazard prediction"""
    risk_score: float
    risk_probability: float
    risk_threshold: int
    is_red_zone: bool
    risk_level: str
    hazard_type: str
    prediction_timestamp: str
    model_version: str


@router.post("/predict", response_model=HazardPredictionResponse)
async def predict_hazard(
    request: HazardPredictionRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Predict hazard risk for a specific location
    
    - **latitude**: Location latitude
    - **longitude**: Location longitude
    - **precipitation_24h_mm**: 24-hour precipitation in mm
    - **precipitation_72h_mm**: 72-hour precipitation in mm
    - **slope_percentage**: Slope in percentage
    - **elevation**: Elevation in meters
    - **lithology**: Lithology type
    - **soil_moisture_index**: Soil moisture index (0-1)
    - **vegetation_index**: Vegetation index (0-1)
    - **hazard_type**: Type of hazard (landslide, flood, coastal_erosion, cloudburst)
    - **region**: Optional region for specific thresholds
    """
    try:
        # Get hazard predictor model
        model = get_model("hazard_predictor")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Hazard prediction model not available"
            )
        
        # Prepare features
        features = request.dict()
        features['latitude'] = request.latitude
        features['longitude'] = request.longitude
        
        # Make prediction
        prediction = model.predict(features)
        
        return prediction
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Hazard prediction failed: {str(e)}"
        )


@router.post("/predict-batch")
async def predict_hazards_batch(
    request: BatchHazardPredictionRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Predict hazard risks for multiple grid cells
    
    - **grid_cells**: List of grid cell features
    - **generate_red_zones**: Whether to generate red zone polygons
    - **min_cluster_size**: Minimum cluster size for red zone generation
    """
    try:
        # Get hazard predictor model
        model = get_model("hazard_predictor")
        if not model or not model.is_loaded:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Hazard prediction model not available"
            )
        
        # Add coordinates to features
        grid_features = []
        for cell in request.grid_cells:
            features = cell.dict()
            features['latitude'] = cell.latitude
            features['longitude'] = cell.longitude
            grid_features.append(features)
        
        # Make batch predictions
        predictions = model.predict_batch(grid_features)
        
        result = {
            'total_cells': len(grid_features),
            'predictions': predictions,
            'high_risk_count': sum(1 for p in predictions if p.get('is_red_zone', False))
        }
        
        # Generate red zones if requested
        if request.generate_red_zones:
            # Add coordinates to predictions for clustering
            for i, (prediction, features) in enumerate(zip(predictions, grid_features)):
                prediction['latitude'] = features['latitude']
                prediction['longitude'] = features['longitude']
            
            red_zones = model.generate_red_zone_polygons(predictions, request.min_cluster_size)
            result['red_zones'] = red_zones
            result['red_zone_count'] = len(red_zones)
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Batch hazard prediction failed: {str(e)}"
        )


@router.get("/model-info")
async def get_hazard_model_info(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Get information about the hazard prediction model"""
    try:
        model = get_model("hazard_predictor")
        if not model:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Hazard prediction model not found"
            )
        
        return {
            'model_info': model.get_model_info(),
            'feature_importance': model.get_feature_importance()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get model info: {str(e)}"
        )