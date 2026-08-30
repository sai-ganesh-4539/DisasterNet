"""
AI Hazard Predictor - Real-time red zone mapping using ML models
"""
from typing import Dict, List, Any, Optional
import numpy as np
from sklearn.ensemble import RandomForestClassifier
import logging
from datetime import datetime
from app.ml.base_model import BaseMLModel, model_registry, prediction_cache
from app.core.config import settings, yaml_config, get_risk_threshold

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class HazardPredictor(BaseMLModel):
    """AI-powered hazard prediction for red zone mapping"""
    
    def __init__(self, model_name: str = "hazard_predictor"):
        super().__init__(model_name)
        self.required_features = [
            'precipitation_24h_mm',
            'precipitation_72h_mm',
            'slope_percentage',
            'elevation',
            'lithology',
            'soil_moisture_index',
            'vegetation_index'
        ]
        self.feature_mapping = {
            'precipitation_24h_mm': 0,
            'precipitation_72h_mm': 1,
            'slope_percentage': 2,
            'elevation': 3,
            'lithology': 4,
            'soil_moisture_index': 5,
            'vegetation_index': 6
        }
        self.lithology_mapping = {
            'GRANITE': 0,
            'SANDSTONE': 1,
            'LIMESTONE': 2,
            'SHALE': 3,
            'BASALT': 4,
            'OTHER': 5
        }
        
    def load_model(self) -> bool:
        """Load the hazard prediction model"""
        try:
            # For this implementation, we'll create a pre-trained model
            # In production, this would load from: f"{self.model_path}/{settings.hazard_model_name}"
            
            # Create a pre-trained Random Forest model with reasonable defaults
            # This simulates a model that has been trained on historical data
            self.model = RandomForestClassifier(
                n_estimators=100,
                max_depth=10,
                random_state=42,
                n_jobs=-1
            )
            
            # Fit with sample data to simulate a pre-trained model
            # In production, this would be loaded from disk
            self._initialize_with_sample_data()
            
            self.is_loaded = True
            self.model_version = "1.0.0"
            self.last_loaded = datetime.utcnow()
            
            logger.info(f"Hazard predictor model loaded: {self.model_name}")
            return True
            
        except Exception as e:
            logger.error(f"Error loading hazard predictor: {str(e)}")
            return False
    
    def _initialize_with_sample_data(self):
        """Initialize model with sample training data (simulates pre-trained model)"""
        # Generate synthetic training data for demonstration
        # In production, this would be replaced with actual trained model loading
        
        n_samples = 2500
        rng = np.random.default_rng(42)

        precip_24 = rng.gamma(2.0, 18.0, n_samples).clip(0, 220)
        precip_72 = (precip_24 + rng.gamma(2.0, 25.0, n_samples)).clip(0, 400)
        slope = rng.beta(2.0, 5.0, n_samples) * 55
        elevation = rng.uniform(0, 3500, n_samples)
        lithology = rng.integers(0, 6, n_samples)
        soil = np.clip(0.15 + precip_72 / 250.0 + rng.normal(0, 0.08, n_samples), 0, 1)
        veg = np.clip(0.6 - slope / 100.0 + rng.normal(0, 0.1, n_samples), 0.05, 0.95)

        X = np.column_stack([
            precip_24 / 100.0,
            precip_72 / 200.0,
            slope / 50.0,
            elevation / 2000.0,
            lithology / 5.0,
            soil,
            veg,
        ])

        physical = (
            precip_24 * 0.45
            + precip_72 * 0.12
            + slope * 1.1
            + np.where(elevation < 40, 28.0, 0.0)
            + soil * 15.0
        )
        y = (physical >= 55).astype(int)
        self.model.fit(X, y)
    
    def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Make hazard prediction for a grid cell"""
        try:
            # Check cache first
            cached_result = prediction_cache.get(self.model_name, features)
            if cached_result is not None:
                return cached_result
            
            # Validate features
            if not self.validate_features(features, self.required_features):
                raise ValueError("Missing required features for hazard prediction")
            
            # Preprocess features
            processed_features = self._preprocess_hazard_features(features)
            
            # Make prediction
            proba = self.model.predict_proba(processed_features)
            # Handle case where predict_proba returns single column (positive class only)
            if proba.shape[1] == 1:
                risk_probability = proba[0, 0]
            else:
                risk_probability = proba[0, 1]  # Probability of high risk
            risk_score = risk_probability * 100
            
            # Get risk threshold
            hazard_type = features.get('hazard_type', 'landslide')
            risk_threshold = get_risk_threshold(hazard_type.upper(), features.get('region'))
            
            # Determine if red zone
            is_red_zone = bool(risk_score >= risk_threshold)
            risk_level = self._classify_risk_level(risk_score)
            
            # Prepare result
            result = {
                'risk_score': round(risk_score, 2),
                'risk_probability': round(risk_probability, 4),
                'risk_threshold': risk_threshold,
                'is_red_zone': is_red_zone,
                'risk_level': risk_level,
                'hazard_type': hazard_type.upper(),
                'prediction_timestamp': datetime.utcnow().isoformat(),
                'model_version': self.model_version,
                'features_used': list(features.keys())
            }
            
            # Cache the result
            prediction_cache.set(self.model_name, features, result)
            
            return result
            
        except Exception as e:
            logger.error(f"Error in hazard prediction: {str(e)}")
            raise
    
    def _preprocess_hazard_features(self, features: Dict[str, Any]) -> np.ndarray:
        """Preprocess features for hazard prediction model"""
        feature_vector = np.zeros(7)
        
        # Map features to vector indices
        for feature_name, index in self.feature_mapping.items():
            if feature_name in features:
                value = features[feature_name]
                
                # Handle categorical features
                if feature_name == 'lithology':
                    lithology_upper = str(value).upper()
                    feature_vector[index] = self.lithology_mapping.get(lithology_upper, 5)  # OTHER
                else:
                    # Normalize numeric features
                    if feature_name == 'precipitation_24h_mm':
                        feature_vector[index] = min(value / 100.0, 1.0)  # Normalize to 0-1
                    elif feature_name == 'precipitation_72h_mm':
                        feature_vector[index] = min(value / 200.0, 1.0)  # Normalize to 0-1
                    elif feature_name == 'slope_percentage':
                        feature_vector[index] = min(value / 50.0, 1.0)  # Normalize to 0-1
                    elif feature_name == 'elevation':
                        feature_vector[index] = min(value / 2000.0, 1.0)  # Normalize to 0-1
                    elif feature_name in ['soil_moisture_index', 'vegetation_index']:
                        feature_vector[index] = value  # Already 0-1
                    else:
                        feature_vector[index] = value
        
        return feature_vector.reshape(1, -1)
    
    def _classify_risk_level(self, risk_score: float) -> str:
        """Classify risk level based on score"""
        if risk_score >= 90:
            return 'CRITICAL'
        elif risk_score >= 75:
            return 'HIGH'
        elif risk_score >= 50:
            return 'MEDIUM'
        else:
            return 'LOW'
    
    def predict_batch(self, features_list: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Make predictions for multiple grid cells"""
        results = []
        
        for features in features_list:
            try:
                result = self.predict(features)
                results.append(result)
            except Exception as e:
                logger.error(f"Error predicting for features: {str(e)}")
                results.append({
                    'error': str(e),
                    'risk_score': None,
                    'is_red_zone': False
                })
        
        return results
    
    def get_feature_importance(self) -> Dict[str, float]:
        """Get feature importance from the model"""
        if not self.is_loaded or self.model is None:
            return {}
        
        try:
            importances = self.model.feature_importances_
            feature_names = list(self.feature_mapping.keys())
            
            importance_dict = {}
            for name, importance in zip(feature_names, importances):
                importance_dict[name] = round(importance * 100, 2)
            
            return importance_dict
        except Exception as e:
            logger.error(f"Error getting feature importance: {str(e)}")
            return {}
    
    def generate_red_zone_polygons(self, grid_predictions: List[Dict[str, Any]], 
                                   min_cluster_size: int = 5) -> List[Dict[str, Any]]:
        """Generate red zone polygons from clustered high-risk grid cells"""
        try:
            from sklearn.cluster import DBSCAN
            import numpy as np
            
            # Extract high-risk grid cells
            high_risk_grids = [
                pred for pred in grid_predictions 
                if pred.get('is_red_zone', False) and 'latitude' in pred and 'longitude' in pred
            ]
            
            if len(high_risk_grids) < min_cluster_size:
                logger.info(f"Insufficient high-risk grids for clustering: {len(high_risk_grids)}")
                return []
            
            # Extract coordinates
            coordinates = np.array([
                [grid['latitude'], grid['longitude']] 
                for grid in high_risk_grids
            ])
            
            # Perform clustering
            clustering = DBSCAN(eps=0.01, min_samples=min_cluster_size).fit(coordinates)
            labels = clustering.labels_
            
            # Group by clusters
            clusters = {}
            for idx, label in enumerate(labels):
                if label != -1:  # Ignore noise points
                    if label not in clusters:
                        clusters[label] = []
                    clusters[label].append(high_risk_grids[idx])
            
            # Generate polygons for each cluster
            red_zones = []
            for cluster_id, cluster_grids in clusters.items():
                polygon = self._create_polygon_from_cluster(cluster_grids)
                if polygon:
                    red_zones.append({
                        'cluster_id': cluster_id,
                        'grid_count': len(cluster_grids),
                        'average_risk_score': np.mean([g['risk_score'] for g in cluster_grids]),
                        'max_risk_score': max([g['risk_score'] for g in cluster_grids]),
                        'polygon': polygon,
                        'grid_cells': cluster_grids
                    })
            
            logger.info(f"Generated {len(red_zones)} red zone polygons")
            return red_zones
            
        except Exception as e:
            logger.error(f"Error generating red zone polygons: {str(e)}")
            return []
    
    def _create_polygon_from_cluster(self, cluster_grids: List[Dict[str, Any]]) -> str:
        """Create a polygon WKT string from cluster grid cells"""
        try:
            from shapely.geometry import MultiPoint, Polygon
            
            # Extract points
            points = [
                (grid['longitude'], grid['latitude']) 
                for grid in cluster_grids
            ]
            
            # Create convex hull
            multi_point = MultiPoint(points)
            convex_hull = multi_point.convex_hull
            
            # Convert to WKT
            if convex_hull.geom_type == 'Polygon':
                return convex_hull.wkt
            elif convex_hull.geom_type == 'MultiPolygon':
                # Return the largest polygon
                largest_polygon = max(convex_hull.geoms, key=lambda p: p.area)
                return largest_polygon.wkt
            else:
                # Fallback to bounding box
                min_x = min(p[0] for p in points)
                max_x = max(p[0] for p in points)
                min_y = min(p[1] for p in points)
                max_y = max(p[1] for p in points)
                
                return f"POLYGON(({min_x} {min_y}, {max_x} {min_y}, {max_x} {max_y}, {min_x} {max_y}, {min_x} {min_y}))"
            
        except Exception as e:
            logger.error(f"Error creating polygon: {str(e)}")
            return ""


# Register the model
hazard_predictor = HazardPredictor()
model_registry.register_model(hazard_predictor, {
    'description': 'AI-powered hazard prediction for red zone mapping',
    'model_type': 'RandomForestClassifier',
    'supported_hazards': ['LANDSLIDE', 'FLOOD', 'COASTAL_EROSION', 'CLOUDBURST']
})