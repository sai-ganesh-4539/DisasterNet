"""
Configuration endpoints for AI model parameters
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


class ModelConfig(BaseModel):
    """AI Model Configuration"""
    gridResolution: int = 100  # meters
    riskThreshold: int = 65  # percentage
    weights: Dict[str, float] = {
        "slope": 0.4,
        "rainfall": 0.35,
        "demographics": 0.25
    }


# In-memory configuration storage (in production, use database)
current_config = ModelConfig()


@router.get("/config/model")
async def get_model_config():
    """Get current AI model configuration"""
    try:
        return current_config
    except Exception as e:
        logger.error(f"Error getting model config: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to retrieve configuration")


@router.post("/config/model")
async def update_model_config(config: ModelConfig):
    """Update AI model configuration"""
    try:
        # Validate weights sum to 1.0
        total_weight = sum(config.weights.values())
        if abs(total_weight - 1.0) > 0.01:
            raise HTTPException(
                status_code=400,
                detail=f"Weights must sum to 1.0, current sum: {total_weight:.2f}"
            )
        
        # Validate configuration ranges
        if not (50 <= config.gridResolution <= 500):
            raise HTTPException(
                status_code=400,
                detail="Grid resolution must be between 50m and 500m"
            )
        
        if not (50 <= config.riskThreshold <= 90):
            raise HTTPException(
                status_code=400,
                detail="Risk threshold must be between 50% and 90%"
            )
        
        # Update configuration
        global current_config
        current_config = config
        
        logger.info(f"Model configuration updated: {config}")
        
        return {
            "success": True,
            "message": "Configuration updated successfully",
            "config": current_config
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating model config: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to update configuration")


@router.get("/config/default")
async def get_default_config():
    """Get default configuration"""
    return ModelConfig()