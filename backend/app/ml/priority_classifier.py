"""
Time-Horizon Relocation Prioritization Classifier
"""
from typing import Dict, List, Any, Optional
import numpy as np
from sklearn.ensemble import RandomForestClassifier
import logging
from datetime import datetime
from app.ml.base_model import BaseMLModel, model_registry, prediction_cache
from app.core.config import settings, yaml_config, get_priority_weights

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PriorityClassifier(BaseMLModel):
    """Classifier for relocation prioritization based on hybrid scoring"""
    
    def __init__(self, model_name: str = "priority_classifier"):
        super().__init__(model_name)
        self.required_features = [
            'hazard_intensity',
            'population_vulnerability',
            'access_limitations',
            'disaster_history'
        ]
        self.time_horizons = yaml_config.get('time_horizons', {})
        
    def load_model(self) -> bool:
        """Load the priority classification model"""
        try:
            # For this implementation, we'll create a pre-trained model
            # In production, this would load from: f"{self.model_path}/{settings.priority_model_name}"
            
            # Create a Random Forest model for priority classification
            self.model = RandomForestClassifier(
                n_estimators=50,
                max_depth=8,
                random_state=42,
                n_jobs=-1
            )
            
            # Fit with sample data to simulate a pre-trained model
            self._initialize_with_sample_data()
            
            self.is_loaded = True
            self.model_version = "1.0.0"
            self.last_loaded = datetime.utcnow()
            
            logger.info(f"Priority classifier model loaded: {self.model_name}")
            return True
            
        except Exception as e:
            logger.error(f"Error loading priority classifier: {str(e)}")
            return False
    
    def _initialize_with_sample_data(self):
        """Initialize model with sample training data (simulates pre-trained model)"""
        # Generate synthetic training data for demonstration
        n_samples = 500
        np.random.seed(42)
        
        # Generate features
        X = np.random.rand(n_samples, 4)
        
        # Generate labels based on heuristic rules
        y = []
        for i in range(n_samples):
            hazard_intensity = X[i, 0]  # 0-1
            population_vulnerability = X[i, 1]  # 0-1
            access_limitations = X[i, 2]  # 0-1
            disaster_history = X[i, 3]  # 0-1
            
            # Calculate priority score using expert weights
            weights = get_priority_weights()
            priority_score = (
                hazard_intensity * weights['hazard_intensity'] +
                population_vulnerability * weights['population_vulnerability'] +
                access_limitations * weights['access_limitations'] +
                disaster_history * weights['disaster_history']
            ) * 100
            
            # Classify based on score
            if priority_score >= 80:
                y.append(2)  # IMMEDIATE
            elif priority_score >= 60:
                y.append(1)  # SHORT_TERM
            else:
                y.append(0)  # MEDIUM_TERM
        
        self.model.fit(X, np.array(y))
    
    def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Make priority classification for a habitation"""
        try:
            # Check cache first
            cached_result = prediction_cache.get(self.model_name, features)
            if cached_result is not None:
                return cached_result
            
            # Calculate hybrid priority score
            priority_score = self._calculate_priority_score(features)
            
            # Classify into time horizon
            priority_category = self._classify_priority_category(priority_score, features)
            
            # Get ML prediction if available
            ml_prediction = self._get_ml_prediction(features)
            
            # Combine expert and ML predictions (hybrid approach)
            final_category = self._combine_predictions(priority_category, ml_prediction, priority_score)
            
            # Prepare result
            result = {
                'priority_score': round(priority_score, 2),
                'priority_category': final_category,
                'expert_category': priority_category,
                'ml_category': ml_prediction,
                'time_horizon_details': self._get_time_horizon_details(final_category),
                'calculation_breakdown': self._get_calculation_breakdown(features),
                'prediction_timestamp': datetime.utcnow().isoformat(),
                'model_version': self.model_version,
                'habitation_id': features.get('habitation_id', 'unknown')
            }
            
            # Cache the result
            prediction_cache.set(self.model_name, features, result)
            
            return result
            
        except Exception as e:
            logger.error(f"Error in priority classification: {str(e)}")
            raise
    
    def _calculate_priority_score(self, features: Dict[str, Any]) -> float:
        """Calculate priority score using expert-defined weights"""
        weights = get_priority_weights()
        
        # Extract individual components
        hazard_intensity = self._calculate_hazard_intensity(features)
        population_vulnerability = self._calculate_population_vulnerability(features)
        access_limitations = self._calculate_access_limitations(features)
        disaster_history = self._calculate_disaster_history(features)
        
        # Calculate weighted score
        priority_score = (
            hazard_intensity * weights['hazard_intensity'] +
            population_vulnerability * weights['population_vulnerability'] +
            access_limitations * weights['access_limitations'] +
            disaster_history * weights['disaster_history']
        )
        
        return min(100.0, max(0.0, priority_score))
    
    def _calculate_hazard_intensity(self, features: Dict[str, Any]) -> float:
        """Calculate hazard intensity score (0-100)"""
        score = 0.0
        
        # Red zone proximity
        red_zone_proximity = features.get('red_zone_proximity_km', 100)
        if red_zone_proximity < 1:
            score += 40.0
        elif red_zone_proximity < 5:
            score += 30.0
        elif red_zone_proximity < 10:
            score += 20.0
        elif red_zone_proximity < 20:
            score += 10.0
        
        # Current risk score if available
        current_risk_score = features.get('current_risk_score', 0)
        score += current_risk_score * 0.3
        
        # Hazard history
        hazard_history = features.get('hazard_history', [])
        if hazard_history:
            score += min(30.0, len(hazard_history) * 10.0)
        
        return min(100.0, score)
    
    def _calculate_population_vulnerability(self, features: Dict[str, Any]) -> float:
        """Calculate population vulnerability score (0-100)"""
        score = 0.0
        
        # Population density
        population_density = features.get('population_density_per_sqkm', 0)
        if population_density > 1000:
            score += 30.0
        elif population_density > 500:
            score += 20.0
        elif population_density > 200:
            score += 10.0
        
        # Elderly percentage
        elderly_percentage = features.get('elderly_percentage', 0)
        score += elderly_percentage * 0.3
        
        # Child percentage
        child_percentage = features.get('child_percentage', 0)
        score += child_percentage * 0.2
        
        # Disability percentage
        disability_percentage = features.get('disability_percentage', 0)
        score += disability_percentage * 0.4
        
        # Economic status
        economic_status = features.get('economic_status', 'APL')
        if economic_status == 'BPL':
            score += 20.0
        elif economic_status == 'MIXED':
            score += 10.0
        
        return min(100.0, score)
    
    def _calculate_access_limitations(self, features: Dict[str, Any]) -> float:
        """Calculate access limitations score (0-100)"""
        score = 0.0
        
        # Road connectivity
        road_connectivity = features.get('road_connectivity', 'PAVED')
        if road_connectivity == 'NONE':
            score += 40.0
        elif road_connectivity == 'SEASONAL':
            score += 30.0
        elif road_connectivity == 'UNPAVED':
            score += 20.0
        
        # Road distance
        road_distance = features.get('road_distance_km', 0)
        if road_distance > 20:
            score += 20.0
        elif road_distance > 10:
            score += 10.0
        
        # Emergency services distance
        emergency_distance = features.get('nearest_emergency_km', 100)
        if emergency_distance > 50:
            score += 20.0
        elif emergency_distance > 25:
            score += 10.0
        
        # Communication availability
        communication = features.get('communication_availability', 'MOBILE')
        if communication == 'NONE':
            score += 20.0
        elif communication == 'LIMITED':
            score += 10.0
        
        # Evacuation route status
        evacuation_route = features.get('evacuation_route_status', 'CLEAR')
        if evacuation_route == 'BLOCKED':
            score += 30.0
        elif evacuation_route == 'DAMAGED':
            score += 20.0
        
        # Evacuation time
        evacuation_time = features.get('evacuation_time_hours', 1)
        if evacuation_time > 12:
            score += 20.0
        elif evacuation_time > 6:
            score += 10.0
        
        return min(100.0, score)
    
    def _calculate_disaster_history(self, features: Dict[str, Any]) -> float:
        """Calculate disaster history score (0-100)"""
        score = 0.0
        
        # Disaster frequency score
        disaster_frequency = features.get('disaster_frequency_score', 0)
        score += disaster_frequency
        
        # Hazard history count
        hazard_history = features.get('hazard_history', [])
        if hazard_history:
            # More recent disasters carry higher weight
            current_year = datetime.now().year
            recent_disasters = [h for h in hazard_history if h.get('year', 0) >= current_year - 5]
            score += len(recent_disasters) * 15.0
            score += (len(hazard_history) - len(recent_disasters)) * 5.0
        
        return min(100.0, score)
    
    def _classify_priority_category(self, priority_score: float, 
                                   features: Dict[str, Any]) -> str:
        """Classify priority category based on score and context"""
        # Check for immediate triggers
        red_zone_proximity = features.get('red_zone_proximity_km', 100)
        in_red_zone = features.get('current_red_zone_id') is not None
        
        # Immediate priority if in or very close to red zone
        if in_red_zone or red_zone_proximity < 1:
            return 'IMMEDIATE'
        
        # Score-based classification
        if priority_score >= 80:
            return 'IMMEDIATE'
        elif priority_score >= 60:
            return 'SHORT_TERM'
        else:
            return 'MEDIUM_TERM'
    
    def _get_ml_prediction(self, features: Dict[str, Any]) -> str:
        """Get ML model prediction for priority category"""
        try:
            if not self.is_loaded:
                return 'MEDIUM_TERM'
            
            # Prepare features for ML model
            ml_features = self._prepare_ml_features(features)
            
            # Make prediction
            prediction = self.model.predict([ml_features])[0]
            
            # Map numeric prediction to category
            category_map = {0: 'MEDIUM_TERM', 1: 'SHORT_TERM', 2: 'IMMEDIATE'}
            return category_map.get(prediction, 'MEDIUM_TERM')
            
        except Exception as e:
            logger.warning(f"ML prediction failed, using default: {str(e)}")
            return 'MEDIUM_TERM'
    
    def _prepare_ml_features(self, features: Dict[str, Any]) -> List[float]:
        """Prepare features for ML model"""
        hazard_intensity = self._calculate_hazard_intensity(features) / 100.0
        population_vulnerability = self._calculate_population_vulnerability(features) / 100.0
        access_limitations = self._calculate_access_limitations(features) / 100.0
        disaster_history = self._calculate_disaster_history(features) / 100.0
        
        return [hazard_intensity, population_vulnerability, access_limitations, disaster_history]
    
    def _combine_predictions(self, expert_category: str, ml_category: str, 
                           priority_score: float) -> str:
        """Combine expert and ML predictions using hybrid approach"""
        config = yaml_config.get('priority_scoring.ml_refinement', {})
        enabled = config.get('enabled', True)
        
        if not enabled:
            return expert_category
        
        # If both agree, return that category
        if expert_category == ml_category:
            return expert_category
        
        # If priority score is very high, trust expert
        if priority_score >= 90:
            return expert_category
        
        # If priority score is very low, trust ML (more conservative)
        if priority_score <= 30:
            return ml_category
        
        # Otherwise, take the more conservative (higher priority) option
        priority_order = {'IMMEDIATE': 3, 'SHORT_TERM': 2, 'MEDIUM_TERM': 1}
        
        if priority_order.get(expert_category, 0) >= priority_order.get(ml_category, 0):
            return expert_category
        else:
            return ml_category
    
    def _get_time_horizon_details(self, category: str) -> Dict[str, Any]:
        """Get details for the time horizon category"""
        horizons = {
            'IMMEDIATE': self.time_horizons.get('immediate', {}),
            'SHORT_TERM': self.time_horizons.get('short_term', {}),
            'MEDIUM_TERM': self.time_horizons.get('medium_term', {})
        }
        
        return horizons.get(category, {})
    
    def _get_calculation_breakdown(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Get detailed breakdown of priority score calculation"""
        weights = get_priority_weights()
        
        return {
            'weights': weights,
            'component_scores': {
                'hazard_intensity': round(self._calculate_hazard_intensity(features), 2),
                'population_vulnerability': round(self._calculate_population_vulnerability(features), 2),
                'access_limitations': round(self._calculate_access_limitations(features), 2),
                'disaster_history': round(self._calculate_disaster_history(features), 2)
            },
            'weighted_contributions': {
                'hazard_intensity': round(self._calculate_hazard_intensity(features) * weights['hazard_intensity'], 2),
                'population_vulnerability': round(self._calculate_population_vulnerability(features) * weights['population_vulnerability'], 2),
                'access_limitations': round(self._calculate_access_limitations(features) * weights['access_limitations'], 2),
                'disaster_history': round(self._calculate_disaster_history(features) * weights['disaster_history'], 2)
            }
        }
    
    def predict_batch(self, habitations_list: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Make predictions for multiple habitations"""
        results = []
        
        for habitation in habitations_list:
            try:
                result = self.predict(habitation)
                results.append(result)
            except Exception as e:
                logger.error(f"Error predicting for habitation: {str(e)}")
                results.append({
                    'error': str(e),
                    'priority_score': None,
                    'priority_category': 'UNKNOWN',
                    'habitation_id': habitation.get('habitation_id', 'unknown')
                })
        
        return results
    
    def get_feature_importance(self) -> Dict[str, float]:
        """Get feature importance from the model"""
        if not self.is_loaded or self.model is None:
            return get_priority_weights()
        
        try:
            importances = self.model.feature_importances_
            feature_names = ['hazard_intensity', 'population_vulnerability', 
                           'access_limitations', 'disaster_history']
            
            importance_dict = {}
            for name, importance in zip(feature_names, importances):
                importance_dict[name] = round(importance * 100, 2)
            
            return importance_dict
        except Exception as e:
            logger.error(f"Error getting feature importance: {str(e)}")
            return get_priority_weights()


# Register the model
priority_classifier = PriorityClassifier()
model_registry.register_model(priority_classifier, {
    'description': 'Time-horizon relocation prioritization classifier',
    'model_type': 'RandomForestClassifier',
    'approach': 'hybrid',
    'categories': ['IMMEDIATE', 'SHORT_TERM', 'MEDIUM_TERM']
})