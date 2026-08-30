"""
API endpoint tests
"""
import pytest
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from fastapi.testclient import TestClient
from unittest.mock import Mock, patch


def test_health_check():
    """Test health check endpoint"""
    from app.main import app
    client = TestClient(app)
    
    response = client.get("/health")  # No auth required for health check
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "service" in data
    assert "version" in data


def test_hazard_prediction(sample_hazard_request, auth_headers):
    """Test hazard prediction endpoint"""
    from app.main import app
    client = TestClient(app)
    
    # Use auth headers instead of mocking
    with patch('app.api.v1.endpoints.hazards.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        # Mock the model
        with patch('app.api.v1.endpoints.hazards.get_model') as mock_get_model:
            mock_model = Mock()
            mock_model.is_loaded = True
            mock_model.predict.return_value = {
                'risk_score': 75.5,
                'risk_probability': 0.755,
                'risk_threshold': 75,
                'is_red_zone': True,
                'risk_level': 'HIGH',
                'hazard_type': 'LANDSLIDE',
                'prediction_timestamp': '2024-01-15T10:00:00Z',
                'model_version': '1.0.0'
            }
            mock_get_model.return_value = mock_model
            
            response = client.post("/api/v1/hazards/predict", json=sample_hazard_request, headers=auth_headers)
            assert response.status_code == 200
            data = response.json()
            assert 'risk_score' in data
            assert 'is_red_zone' in data


def test_batch_hazard_prediction(sample_grid_cells, auth_headers):
    """Test batch hazard prediction endpoint"""
    from app.main import app
    client = TestClient(app)
    
    request_data = {
        'grid_cells': sample_grid_cells,
        'generate_red_zones': True,
        'min_cluster_size': 5
    }
    
    with patch('app.api.v1.endpoints.hazards.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        with patch('app.api.v1.endpoints.hazards.get_model') as mock_get_model:
            mock_model = Mock()
            mock_model.is_loaded = True
            mock_model.predict_batch.return_value = [
                {
                    'risk_score': 70.0 + i,
                    'is_red_zone': i > 5,
                    'latitude': cell['latitude'],
                    'longitude': cell['longitude']
                }
                for i, cell in enumerate(sample_grid_cells)
            ]
            mock_model.generate_red_zone_polygons.return_value = []
            mock_get_model.return_value = mock_model
            
            response = client.post("/api/v1/hazards/predict-batch", json=request_data, headers=auth_headers)
            assert response.status_code == 200
            data = response.json()
            assert 'total_cells' in data
            assert 'predictions' in data


def test_get_red_zones(auth_headers):
    """Test get red zones endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.red_zones.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        response = client.get("/api/v1/red-zones/", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert 'count' in data
        assert 'red_zones' in data


def test_get_habitations(auth_headers):
    """Test get habitations endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.habitations.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        response = client.get("/api/v1/habitations/", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert 'count' in data
        assert 'habitations' in data


def test_habitation_priority_assessment(sample_habitation_request, auth_headers):
    """Test habitation priority assessment endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.habitations.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        with patch('app.api.v1.endpoints.habitations.get_model') as mock_get_model:
            mock_model = Mock()
            mock_model.is_loaded = True
            mock_model.predict.return_value = {
                'priority_score': 65.0,
                'priority_category': 'SHORT_TERM',
                'expert_category': 'SHORT_TERM',
                'ml_category': 'SHORT_TERM',
                'time_horizon_details': {
                    'name': 'Short-Term',
                    'min_weeks': 1,
                    'max_weeks': 4
                },
                'calculation_breakdown': {},
                'prediction_timestamp': '2024-01-15T10:00:00Z',
                'model_version': '1.0.0'
            }
            mock_get_model.return_value = mock_model
            
            response = client.post("/api/v1/habitations/assess", json=sample_habitation_request, headers=auth_headers)
            assert response.status_code == 200
            data = response.json()
            assert 'priority_score' in data
            assert 'priority_category' in data


def test_get_shelters(auth_headers):
    """Test get shelters endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.shelters.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        response = client.get("/api/v1/shelters/", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert 'count' in data
        assert 'shelters' in data


def test_shelter_capacity_evaluation(sample_shelter_request, auth_headers):
    """Test shelter capacity evaluation endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.shelters.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        with patch('app.api.v1.endpoints.shelters.get_model') as mock_get_model:
            mock_model = Mock()
            mock_model.is_loaded = True
            mock_model.predict.return_value = {
                'total_capacity': 500,
                'effective_capacity': 350,
                'available_capacity': 200,
                'capacity_constraint': 'WATER',
                'utilization_percentage': 30.0,
                'capacity_status': 'LOW',
                'evaluation_timestamp': '2024-01-15T10:00:00Z',
                'model_version': '1.0.0',
                'resource_breakdown': {}
            }
            mock_get_model.return_value = mock_model
            
            response = client.post("/api/v1/shelters/evaluate", json=sample_shelter_request, headers=auth_headers)
            assert response.status_code == 200
            data = response.json()
            assert 'effective_capacity' in data
            assert 'capacity_constraint' in data


def test_get_priorities(auth_headers):
    """Test get priorities endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.priorities.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        response = client.get("/api/v1/priorities/", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert 'count' in data
        assert 'priorities' in data
        assert 'summary' in data


def test_get_immediate_priorities(auth_headers):
    """Test get immediate priorities endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.priorities.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        response = client.get("/api/v1/priorities/immediate", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert 'count' in data
        assert 'priorities' in data


def test_data_status(auth_headers):
    """Test data status endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.data.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        response = client.get("/api/v1/data/status", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert 'last_ingestion' in data
        assert 'system_status' in data


def test_sync_upload(sample_sync_data, auth_headers):
    """Test sync upload endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.sync.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        with patch('app.api.v1.endpoints.sync._validate_signature', return_value=True):
            response = client.post("/api/v1/sync/upload", json=sample_sync_data, headers=auth_headers)
            assert response.status_code == 200
            data = response.json()
            assert 'success' in data
            assert 'sync_id' in data


def test_sync_download(auth_headers):
    """Test sync download endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.sync.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        response = client.get("/api/v1/sync/download?device_id=DEVICE_TEST_001", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert 'device_id' in data
        assert 'data' in data


def test_sync_status(auth_headers):
    """Test sync status endpoint"""
    from app.main import app
    client = TestClient(app)
    
    with patch('app.api.v1.endpoints.sync.get_current_user', return_value={'user_id': 'test', 'username': 'admin', 'role': 'ADMIN'}):
        response = client.get("/api/v1/sync/status", headers=auth_headers)
        assert response.status_code == 200
        data = response.json()
        assert 'total_sync_operations' in data
        assert 'success_rate' in data