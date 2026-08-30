"""
Base ML model interface and utilities
"""
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional, Tuple
import joblib
import numpy as np
import logging
from datetime import datetime
from pathlib import Path
from app.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class BaseMLModel(ABC):
    """Abstract base class for ML models"""
    
    def __init__(self, model_name: str, model_path: Optional[str] = None):
        self.model_name = model_name
        self.model_path = model_path or settings.model_path
        self.model = None
        self.is_loaded = False
        self.model_version = None
        self.last_loaded = None
        
    @abstractmethod
    def load_model(self) -> bool:
        """Load the ML model from disk"""
        pass
    
    @abstractmethod
    def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Make prediction using the model"""
        pass
    
    @abstractmethod
    def get_feature_importance(self) -> Dict[str, float]:
        """Get feature importance from the model"""
        pass
    
    def preprocess_features(self, features: Dict[str, Any]) -> np.ndarray:
        """Preprocess features for model input"""
        # Default implementation - can be overridden
        feature_values = list(features.values())
        return np.array(feature_values).reshape(1, -1)
    
    def postprocess_prediction(self, prediction: Any) -> Dict[str, Any]:
        """Postprocess model output"""
        # Default implementation - can be overridden
        return {
            'prediction': float(prediction),
            'timestamp': datetime.utcnow().isoformat()
        }
    
    def validate_features(self, features: Dict[str, Any], required_features: List[str]) -> bool:
        """Validate that required features are present"""
        missing_features = [f for f in required_features if f not in features]
        if missing_features:
            logger.warning(f"Missing required features: {missing_features}")
            return False
        return True
    
    def save_model(self, model: Any, version: str) -> bool:
        """Save model to disk"""
        try:
            model_dir = Path(self.model_path)
            model_dir.mkdir(parents=True, exist_ok=True)
            
            model_file = model_dir / f"{self.model_name}_{version}.pkl"
            joblib.dump(model, model_file)
            
            logger.info(f"Model saved to {model_file}")
            return True
        except Exception as e:
            logger.error(f"Error saving model: {str(e)}")
            return False
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get model information"""
        return {
            'model_name': self.model_name,
            'model_version': self.model_version,
            'is_loaded': self.is_loaded,
            'last_loaded': self.last_loaded.isoformat() if self.last_loaded else None,
            'model_path': self.model_path
        }


class ModelRegistry:
    """Registry for managing ML models"""
    
    def __init__(self):
        self.models: Dict[str, BaseMLModel] = {}
        self.model_metadata: Dict[str, Dict[str, Any]] = {}
        
    def register_model(self, model: BaseMLModel, metadata: Optional[Dict[str, Any]] = None):
        """Register a model in the registry"""
        self.models[model.model_name] = model
        self.model_metadata[model.model_name] = metadata or {
            'registered_at': datetime.utcnow().isoformat(),
            'status': 'registered'
        }
        logger.info(f"Model registered: {model.model_name}")
    
    def get_model(self, model_name: str) -> Optional[BaseMLModel]:
        """Get a model from the registry"""
        return self.models.get(model_name)
    
    def load_all_models(self) -> Dict[str, bool]:
        """Load all registered models"""
        load_results = {}
        for model_name, model in self.models.items():
            try:
                success = model.load_model()
                load_results[model_name] = success
                if success:
                    self.model_metadata[model_name]['status'] = 'loaded'
                    self.model_metadata[model_name]['loaded_at'] = datetime.utcnow().isoformat()
                else:
                    self.model_metadata[model_name]['status'] = 'load_failed'
            except Exception as e:
                logger.error(f"Error loading model {model_name}: {str(e)}")
                load_results[model_name] = False
                self.model_metadata[model_name]['status'] = 'error'
                self.model_metadata[model_name]['error'] = str(e)
        
        return load_results
    
    def get_model_status(self) -> Dict[str, Dict[str, Any]]:
        """Get status of all models"""
        status = {}
        for model_name, model in self.models.items():
            status[model_name] = {
                **model.get_model_info(),
                **self.model_metadata.get(model_name, {})
            }
        return status


class PredictionCache:
    """Simple in-memory cache for predictions"""
    
    def __init__(self, ttl_seconds: int = 300):
        self.cache: Dict[str, Tuple[Any, datetime]] = {}
        self.ttl_seconds = ttl_seconds
        
    def generate_cache_key(self, model_name: str, features: Dict[str, Any]) -> str:
        """Generate cache key from model name and features"""
        import hashlib
        import json
        
        # Sort features for consistent key generation
        sorted_features = json.dumps(features, sort_keys=True)
        key_string = f"{model_name}:{sorted_features}"
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def get(self, model_name: str, features: Dict[str, Any]) -> Optional[Any]:
        """Get cached prediction if available and not expired"""
        cache_key = self.generate_cache_key(model_name, features)
        
        if cache_key in self.cache:
            prediction, timestamp = self.cache[cache_key]
            age = (datetime.utcnow() - timestamp).total_seconds()
            
            if age < self.ttl_seconds:
                logger.debug(f"Cache hit for {model_name}")
                return prediction
            else:
                # Remove expired entry
                del self.cache[cache_key]
                logger.debug(f"Cache expired for {model_name}")
        
        return None
    
    def set(self, model_name: str, features: Dict[str, Any], prediction: Any):
        """Cache a prediction"""
        cache_key = self.generate_cache_key(model_name, features)
        self.cache[cache_key] = (prediction, datetime.utcnow())
        logger.debug(f"Cached prediction for {model_name}")
    
    def clear(self):
        """Clear all cache entries"""
        self.cache.clear()
        logger.info("Prediction cache cleared")
    
    def cleanup_expired(self):
        """Remove expired cache entries"""
        current_time = datetime.utcnow()
        expired_keys = [
            key for key, (_, timestamp) in self.cache.items()
            if (current_time - timestamp).total_seconds() >= self.ttl_seconds
        ]
        
        for key in expired_keys:
            del self.cache[key]
        
        if expired_keys:
            logger.info(f"Cleaned up {len(expired_keys)} expired cache entries")


# Global instances
model_registry = ModelRegistry()
prediction_cache = PredictionCache(ttl_seconds=300)  # 5 minutes default TTL