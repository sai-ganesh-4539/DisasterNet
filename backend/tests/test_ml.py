"""
ML model tests
"""
import pytest
import numpy as np
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.ml.hazard_predictor import HazardPredictor
from app.ml.capacity_evaluator import CapacityEvaluator
from app.ml.priority_classifier import PriorityClassifier
from app.ml.model_registry import model_registry, prediction_cache


def test_hazard_predictor_load():
    """Test hazard predictor model loading"""
    predictor = HazardPredictor()
    success = predictor.load_model()
    assert success is True
    assert predictor.is_loaded is True
    assert predictor.model is not None


def test_hazard_predictor_prediction(sample_hazard_request):
    """Test hazard prediction"""
    predictor = HazardPredictor()
    predictor.load_model()
    
    result = predictor.predict(sample_hazard_request)
    
    assert 'risk_score' in result
    assert 'is_red_zone' in result
    assert 'risk_level' in result
    assert 0 <= result['risk_score'] <= 100
    assert isinstance(result['is_red_zone'], bool)


def test_hazard_predictor_batch_prediction(sample_grid_cells):
    """Test batch hazard prediction"""
    predictor = HazardPredictor()
    predictor.load_model()
    
    results = predictor.predict_batch(sample_grid_cells)
    
    assert len(results) == len(sample_grid_cells)
    for result in results:
        assert 'risk_score' in result or 'error' in result


def test_hazard_predictor_red_zone_generation(sample_grid_cells):
    """Test red zone polygon generation"""
    predictor = HazardPredictor()
    predictor.load_model()
    
    # Add red zone flags to grid cells
    predictions = []
    for i, cell in enumerate(sample_grid_cells):
        pred = predictor.predict(cell)
        pred['latitude'] = cell['latitude']
        pred['longitude'] = cell['longitude']
        pred['is_red_zone'] = i > 5  # Make some cells red zone
        predictions.append(pred)
    
    red_zones = predictor.generate_red_zone_polygons(predictions, min_cluster_size=3)
    
    assert isinstance(red_zones, list)


def test_hazard_predictor_feature_importance():
    """Test hazard predictor feature importance"""
    predictor = HazardPredictor()
    predictor.load_model()
    
    importance = predictor.get_feature_importance()
    
    assert isinstance(importance, dict)
    assert len(importance) > 0


def test_capacity_evaluator_load():
    """Test capacity evaluator loading"""
    evaluator = CapacityEvaluator()
    success = evaluator.load_model()
    assert success is True
    assert evaluator.is_loaded is True


def test_capacity_evaluator_prediction(sample_shelter_request):
    """Test capacity evaluation"""
    evaluator = CapacityEvaluator()
    evaluator.load_model()
    
    result = evaluator.predict(sample_shelter_request)
    
    assert 'effective_capacity' in result
    assert 'capacity_constraint' in result
    assert 'utilization_percentage' in result
    assert result['effective_capacity'] >= 0


def test_capacity_evaluator_safety_intersect():
    """Test safety intersect evaluation"""
    evaluator = CapacityEvaluator()
    evaluator.load_model()
    
    shelter_geometry = 'POINT(73.85 18.52)'
    red_zone_geometries = [
        'POLYGON((73.8 18.5, 73.9 18.5, 73.9 18.6, 73.8 18.6, 73.8 18.5))',
        'POLYGON((75.0 19.0, 75.1 19.0, 75.1 19.1, 75.0 19.1, 75.0 19.0))'
    ]
    
    result = evaluator.evaluate_safety_intersect(shelter_geometry, red_zone_geometries)
    
    assert 'safety_check_passed' in result
    assert 'intersects_red_zone' in result


def test_capacity_evaluator_suitability(sample_shelter_request):
    """Test comprehensive shelter suitability evaluation"""
    evaluator = CapacityEvaluator()
    evaluator.load_model()
    
    red_zone_geometries = [
        'POLYGON((73.8 18.5, 73.9 18.5, 73.9 18.6, 73.8 18.6, 73.8 18.5))'
    ]
    
    result = evaluator.evaluate_shelter_suitability(sample_shelter_request, red_zone_geometries)
    
    assert 'capacity_evaluation' in result
    assert 'safety_evaluation' in result
    assert 'safety_score' in result
    assert 'overall_suitability' in result


def test_priority_classifier_load():
    """Test priority classifier loading"""
    classifier = PriorityClassifier()
    success = classifier.load_model()
    assert success is True
    assert classifier.is_loaded is True


def test_priority_classifier_prediction(sample_habitation_request):
    """Test priority classification"""
    classifier = PriorityClassifier()
    classifier.load_model()
    
    result = classifier.predict(sample_habitation_request)
    
    assert 'priority_score' in result
    assert 'priority_category' in result
    assert result['priority_category'] in ['IMMEDIATE', 'SHORT_TERM', 'MEDIUM_TERM']
    assert 0 <= result['priority_score'] <= 100


def test_priority_classifier_batch_prediction():
    """Test batch priority classification"""
    classifier = PriorityClassifier()
    classifier.load_model()
    
    habitations = [
        {
            'habitation_id': f'HAB_{i}',
            'latitude': 18.5 + (i * 0.1),
            'longitude': 73.9 + (i * 0.1),
            'total_population': 500,
            'elderly_percentage': 8.0,
            'child_percentage': 12.0,
            'disability_percentage': 3.0,
            'population_density_per_sqkm': 100.0,
            'economic_status': 'MIXED',
            'road_connectivity': 'PAVED',
            'road_distance_km': 5.0,
            'nearest_emergency_km': 15.0,
            'communication_availability': 'MOBILE',
            'evacuation_route_status': 'CLEAR',
            'evacuation_time_hours': 3.0,
            'red_zone_proximity_km': 2.5 + i,
            'current_risk_score': 60.0,
            'hazard_history': [],
            'disaster_frequency_score': 20.0
        }
        for i in range(5)
    ]
    
    results = classifier.predict_batch(habitations)
    
    assert len(results) == len(habitations)
    for result in results:
        assert 'priority_score' in result or 'error' in result


def test_priority_classifier_feature_importance():
    """Test priority classifier feature importance"""
    classifier = PriorityClassifier()
    classifier.load_model()
    
    importance = classifier.get_feature_importance()
    
    assert isinstance(importance, dict)
    assert len(importance) > 0


def test_model_registry():
    """Test model registry functionality"""
    # Test getting a model
    hazard_model = model_registry.get_model('hazard_predictor')
    assert hazard_model is not None
    
    # Test getting model status
    status = model_registry.get_model_status()
    assert isinstance(status, dict)
    assert 'hazard_predictor' in status


def test_prediction_cache():
    """Test prediction cache functionality"""
    # Test cache set and get
    test_features = {'test': 'data'}
    test_result = {'score': 0.75}
    
    prediction_cache.set('test_model', test_features, test_result)
    cached_result = prediction_cache.get('test_model', test_features)
    
    assert cached_result == test_result
    
    # Test cache clear
    prediction_cache.clear()
    cached_result = prediction_cache.get('test_model', test_features)
    assert cached_result is None


def test_prediction_cache_cleanup():
    """Test prediction cache cleanup of expired entries"""
    import time
    
    # Set cache with short TTL
    test_cache = prediction_cache.__class__(ttl_seconds=1)
    
    test_features = {'test': 'data'}
    test_result = {'score': 0.75}
    
    test_cache.set('test_model', test_features, test_result)
    
    # Wait for expiration
    time.sleep(2)
    
    # Cleanup expired
    test_cache.cleanup_expired()
    
    # Try to get expired entry
    cached_result = test_cache.get('test_model', test_features)
    assert cached_result is None