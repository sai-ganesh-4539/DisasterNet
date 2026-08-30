"""
Multi-Resource Carrying Capacity & Suitability Evaluator
"""
from typing import Dict, List, Any, Optional
import logging
from datetime import datetime
from app.ml.base_model import BaseMLModel, model_registry, prediction_cache
from app.core.config import yaml_config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class CapacityEvaluator(BaseMLModel):
    """Evaluator for shelter capacity based on resource bottlenecks"""
    
    def __init__(self, model_name: str = "capacity_evaluator"):
        super().__init__(model_name)
        self.required_shelter_features = [
            'total_capacity',
            'physical_beds',
            'water_sufficiency_days',
            'food_ration_storage_days',
            'medical_facility_depth'
        ]
        
    def load_model(self) -> bool:
        """Load the capacity evaluator (rule-based, no ML model needed)"""
        try:
            # This is a rule-based system, so no ML model to load
            self.is_loaded = True
            self.model_version = "1.0.0"
            self.last_loaded = datetime.utcnow()
            
            logger.info(f"Capacity evaluator loaded: {self.model_name}")
            return True
            
        except Exception as e:
            logger.error(f"Error loading capacity evaluator: {str(e)}")
            return False
    
    def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Evaluate shelter capacity (rule-based evaluation)"""
        try:
            # Check cache first
            cached_result = prediction_cache.get(self.model_name, features)
            if cached_result is not None:
                return cached_result
            
            # Extract shelter features
            total_capacity = features.get('total_capacity', 0)
            physical_beds = features.get('physical_beds', total_capacity)
            water_sufficiency_days = features.get('water_sufficiency_days', 7)
            food_ration_storage_days = features.get('food_ration_storage_days', 7)
            medical_facility_depth = features.get('medical_facility_depth', 'BASIC')
            
            # Calculate capacity based on bottlenecks
            effective_capacity = self._calculate_effective_capacity(
                total_capacity, physical_beds, water_sufficiency_days, 
                food_ration_storage_days, medical_facility_depth
            )
            
            # Identify primary constraint
            capacity_constraint = self._identify_constraint(
                total_capacity, physical_beds, water_sufficiency_days,
                food_ration_storage_days, medical_facility_depth
            )
            
            # Calculate capacity utilization
            current_occupancy = features.get('current_occupancy', 0)
            utilization_percentage = (current_occupancy / effective_capacity * 100) if effective_capacity > 0 else 0
            
            # Prepare result
            result = {
                'total_capacity': total_capacity,
                'effective_capacity': effective_capacity,
                'available_capacity': max(0, effective_capacity - current_occupancy),
                'capacity_constraint': capacity_constraint,
                'utilization_percentage': round(utilization_percentage, 2),
                'current_occupancy': current_occupancy,
                'capacity_status': self._classify_capacity_status(utilization_percentage),
                'evaluation_timestamp': datetime.utcnow().isoformat(),
                'model_version': self.model_version,
                'resource_breakdown': {
                    'physical_beds': physical_beds,
                    'water_sufficiency_days': water_sufficiency_days,
                    'food_ration_storage_days': food_ration_storage_days,
                    'medical_facility_depth': medical_facility_depth
                }
            }
            
            # Cache the result
            prediction_cache.set(self.model_name, features, result)
            
            return result
            
        except Exception as e:
            logger.error(f"Error in capacity evaluation: {str(e)}")
            raise
    
    def _calculate_effective_capacity(self, total_capacity: int, physical_beds: int,
                                      water_sufficiency_days: float, 
                                      food_ration_storage_days: float,
                                      medical_facility_depth: str) -> int:
        """Calculate effective capacity based on resource bottlenecks"""
        config = yaml_config.get('shelter_capacity', {})
        min_resources = config.get('minimum_resources', {})
        safety_buffer = config.get('safety_buffer', 0.1)
        
        # Calculate capacity based on each resource
        bed_capacity = physical_beds
        
        # Water capacity: days of water supply for full capacity
        if water_sufficiency_days > 0:
            water_capacity = int(total_capacity * (water_sufficiency_days / 7.0))  # 7 days baseline
        else:
            water_capacity = 0
        
        # Food capacity: days of food storage for full capacity
        if food_ration_storage_days > 0:
            food_capacity = int(total_capacity * (food_ration_storage_days / 7.0))  # 7 days baseline
        else:
            food_capacity = 0
        
        # Medical capacity: based on facility depth
        medical_capacity_map = {
            'FULL': total_capacity,
            'BASIC': int(total_capacity * 0.7),
            'LIMITED': int(total_capacity * 0.4),
            'NONE': int(total_capacity * 0.1)
        }
        medical_capacity = medical_capacity_map.get(medical_facility_depth.upper(), int(total_capacity * 0.5))
        
        # Effective capacity is the minimum of all capacities (bottleneck)
        effective_capacity = min(bed_capacity, water_capacity, food_capacity, medical_capacity)
        
        # Apply safety buffer
        effective_capacity = int(effective_capacity * (1 - safety_buffer))
        
        return max(0, effective_capacity)
    
    def _identify_constraint(self, total_capacity: int, physical_beds: int,
                           water_sufficiency_days: float, food_ration_storage_days: float,
                           medical_facility_depth: str) -> str:
        """Identify the primary resource constraint"""
        config = yaml_config.get('shelter_capacity', {})
        min_resources = config.get('minimum_resources', {})
        
        # Calculate each resource capacity
        bed_capacity = physical_beds
        water_capacity = int(total_capacity * (water_sufficiency_days / 7.0)) if water_sufficiency_days > 0 else 0
        food_capacity = int(total_capacity * (food_ration_storage_days / 7.0)) if food_ration_storage_days > 0 else 0
        
        medical_capacity_map = {
            'FULL': total_capacity,
            'BASIC': int(total_capacity * 0.7),
            'LIMITED': int(total_capacity * 0.4),
            'NONE': int(total_capacity * 0.1)
        }
        medical_capacity = medical_capacity_map.get(medical_facility_depth.upper(), int(total_capacity * 0.5))
        
        # Find the minimum (bottleneck)
        capacities = {
            'BEDS': bed_capacity,
            'WATER': water_capacity,
            'FOOD': food_capacity,
            'MEDICAL': medical_capacity
        }
        
        # Return the constraint with minimum capacity
        constraint = min(capacities, key=capacities.get)
        
        # If all are equal to total capacity, no constraint
        if all(cap == total_capacity for cap in capacities.values()):
            return 'NONE'
        
        return constraint
    
    def _classify_capacity_status(self, utilization_percentage: float) -> str:
        """Classify capacity status based on utilization"""
        if utilization_percentage >= 100:
            return 'FULL'
        elif utilization_percentage >= 90:
            return 'CRITICAL'
        elif utilization_percentage >= 75:
            return 'HIGH'
        elif utilization_percentage >= 50:
            return 'MODERATE'
        elif utilization_percentage >= 25:
            return 'LOW'
        else:
            return 'AVAILABLE'
    
    def evaluate_safety_intersect(self, shelter_geometry: str, 
                                 red_zone_geometries: List[str]) -> Dict[str, Any]:
        """Evaluate if shelter intersects with any red zone"""
        try:
            from shapely.geometry import Polygon
            from shapely.wkt import loads as wkt_loads
            
            # Parse shelter geometry
            try:
                shelter_polygon = wkt_loads(shelter_geometry)
            except:
                # If point geometry, create a small buffer
                from shapely.geometry import Point
                shelter_point = wkt_loads(shelter_geometry)
                shelter_polygon = shelter_point.buffer(0.01)  # ~1km buffer
            
            # Check intersection with each red zone
            intersections = []
            for i, red_zone_wkt in enumerate(red_zone_geometries):
                try:
                    red_zone_polygon = wkt_loads(red_zone_wkt)
                    
                    if shelter_polygon.intersects(red_zone_polygon):
                        intersection_area = shelter_polygon.intersection(red_zone_polygon).area
                        shelter_area = shelter_polygon.area
                        
                        intersection_percentage = (intersection_area / shelter_area * 100) if shelter_area > 0 else 0
                        
                        intersections.append({
                            'red_zone_index': i,
                            'intersects': True,
                            'intersection_area': intersection_area,
                            'intersection_percentage': round(intersection_percentage, 2)
                        })
                except Exception as e:
                    logger.warning(f"Error checking intersection with red zone {i}: {str(e)}")
                    continue
            
            # Determine overall safety
            safety_check_passed = len(intersections) == 0
            
            return {
                'safety_check_passed': safety_check_passed,
                'intersects_red_zone': not safety_check_passed,
                'intersection_count': len(intersections),
                'intersections': intersections,
                'evaluation_timestamp': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error in safety intersect evaluation: {str(e)}")
            return {
                'safety_check_passed': False,
                'error': str(e)
            }
    
    def evaluate_shelter_suitability(self, shelter_features: Dict[str, Any],
                                   red_zone_geometries: List[str]) -> Dict[str, Any]:
        """Comprehensive shelter suitability evaluation"""
        try:
            # Evaluate capacity
            capacity_result = self.predict(shelter_features)
            
            # Evaluate safety intersect
            shelter_geometry = shelter_features.get('geometry', '')
            safety_result = self.evaluate_safety_intersect(shelter_geometry, red_zone_geometries)
            
            # Calculate overall safety score
            safety_score = self._calculate_safety_score(shelter_features, safety_result)
            
            # Determine overall suitability
            suitability = self._determine_suitability(capacity_result, safety_result, safety_score)
            
            return {
                'capacity_evaluation': capacity_result,
                'safety_evaluation': safety_result,
                'safety_score': safety_score,
                'overall_suitability': suitability,
                'evaluation_timestamp': datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error in shelter suitability evaluation: {str(e)}")
            raise
    
    def _calculate_safety_score(self, shelter_features: Dict[str, Any], 
                               safety_result: Dict[str, Any]) -> float:
        """Calculate overall safety score (0-100)"""
        score = 100.0
        
        # Reduce score if intersects red zone
        if not safety_result.get('safety_check_passed', True):
            score -= 50.0
        
        # Consider road accessibility
        road_access = shelter_features.get('road_accessibility', 'GOOD')
        road_scores = {'GOOD': 0, 'FAIR': -10, 'POOR': -25, 'NONE': -40}
        score += road_scores.get(road_access.upper(), -15)
        
        # Consider utilities
        utilities = ['electricity', 'water_supply', 'sanitation_facilities']
        for utility in utilities:
            if not shelter_features.get(utility, False):
                score -= 5.0
        
        # Consider distance to red zones
        nearest_red_zone_distance = shelter_features.get('nearest_red_zone_distance_km', 10)
        if nearest_red_zone_distance < 1:
            score -= 20.0
        elif nearest_red_zone_distance < 5:
            score -= 10.0
        
        return max(0.0, min(100.0, round(score, 2)))
    
    def _determine_suitability(self, capacity_result: Dict[str, Any],
                             safety_result: Dict[str, Any], 
                             safety_score: float) -> str:
        """Determine overall shelter suitability"""
        # Must pass safety check
        if not safety_result.get('safety_check_passed', True):
            return 'UNSUITABLE'
        
        # Must have some available capacity
        if capacity_result.get('available_capacity', 0) <= 0:
            return 'FULL'
        
        # Consider safety score
        if safety_score >= 80:
            return 'HIGHLY_SUITABLE'
        elif safety_score >= 60:
            return 'SUITABLE'
        elif safety_score >= 40:
            return 'CONDITIONALLY_SUITABLE'
        else:
            return 'MARGINAL'
    
    def get_feature_importance(self) -> Dict[str, float]:
        """Get feature importance (not applicable for rule-based system)"""
        return {
            'physical_beds': 25.0,
            'water_sufficiency_days': 25.0,
            'food_ration_storage_days': 25.0,
            'medical_facility_depth': 15.0,
            'safety_intersect': 10.0
        }


# Register the model
capacity_evaluator = CapacityEvaluator()
model_registry.register_model(capacity_evaluator, {
    'description': 'Multi-resource carrying capacity evaluator for shelters',
    'model_type': 'rule_based',
    'evaluation_method': 'bottleneck_analysis'
})