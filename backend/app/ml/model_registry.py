"""
Model registry and management utilities
"""

import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from app.ml.base_model import BaseMLModel, model_registry, prediction_cache

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def initialize_models() -> Dict[str, bool]:
    """Initialize all ML models"""
    logger.info("Initializing ML models...")

    # Import models to register them
    from app.ml.capacity_evaluator import capacity_evaluator
    from app.ml.hazard_predictor import hazard_predictor
    from app.ml.priority_classifier import priority_classifier

    # Load all models
    load_results = model_registry.load_all_models()

    logger.info(f"Model initialization complete: {load_results}")
    return load_results


def get_model(model_name: str) -> Optional[BaseMLModel]:
    """Get a specific model by name"""
    return model_registry.get_model(model_name)


def get_all_model_status() -> Dict[str, Dict[str, Any]]:
    """Get status of all registered models"""
    return model_registry.get_model_status()


def reload_model(model_name: str) -> bool:
    """Reload a specific model"""
    model = model_registry.get_model(model_name)
    if model:
        return model.load_model()
    return False


def clear_prediction_cache():
    """Clear the prediction cache"""
    prediction_cache.clear()


def get_cache_stats() -> Dict[str, Any]:
    """Get prediction cache statistics"""
    return {
        "cache_size": len(prediction_cache.cache),
        "ttl_seconds": prediction_cache.ttl_seconds,
    }


def register_custom_model(
    model: BaseMLModel, metadata: Optional[Dict[str, Any]] = None
):
    """Register a custom model"""
    model_registry.register_model(model, metadata)


def get_available_models() -> List[str]:
    """Get list of available model names"""
    return list(model_registry.models.keys())
