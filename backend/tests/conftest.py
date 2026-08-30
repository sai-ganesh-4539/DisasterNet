"""
Pytest configuration and fixtures
"""
import pytest
import sys
import os
from typing import Dict, Any
from datetime import datetime, timedelta
from jose import jwt

# Add parent directory to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Import configuration
from app.core.config import settings


# Autouse auth fixture for all tests
@pytest.fixture(autouse=True)
def auth_token():
    """Generate a valid mock JWT token for testing"""
    # Create token payload with state_admin role
    payload = {
        "sub": "test_admin_user",
        "username": "admin",
        "role": "ADMIN",  # Give admin role to bypass permission checks
        "exp": datetime.utcnow() + timedelta(hours=24)  # Token valid for 24 hours
    }
    
    # Generate JWT token
    token = jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)
    
    return f"Bearer {token}"


@pytest.fixture
def auth_headers(auth_token):
    """Return authorization headers dict for API requests"""
    return {"Authorization": auth_token}


@pytest.fixture
def sample_hazard_request():
    """Sample hazard prediction request"""
    return {
        'latitude': 28.5,
        'longitude': 77.2,
        'precipitation_24h_mm': 45.0,
        'precipitation_72h_mm': 120.0,
        'slope_percentage': 25.0,
        'elevation': 1500.0,
        'lithology': 'GRANITE',
        'soil_moisture_index': 0.7,
        'vegetation_index': 0.6,
        'hazard_type': 'landslide',
        'region': None
    }


@pytest.fixture
def sample_habitation_request():
    """Sample habitation priority assessment request"""
    return {
        'habitation_id': 'HAB_TEST_001',
        'latitude': 18.5,
        'longitude': 73.9,
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
        'red_zone_proximity_km': 2.5,
        'current_risk_score': 60.0,
        'hazard_history': [],
        'disaster_frequency_score': 20.0
    }


@pytest.fixture
def sample_shelter_request():
    """Sample shelter capacity evaluation request"""
    return {
        'shelter_id': 'SHELTER_TEST_001',
        'shelter_name': 'Test Community Hall',
        'total_capacity': 500,
        'current_occupancy': 150,
        'physical_beds': 500,
        'water_sufficiency_days': 14.0,
        'food_ration_storage_days': 21.0,
        'medical_facility_depth': 'FULL',
        'geometry': 'POINT(73.85 18.52)',
        'road_accessibility': 'GOOD',
        'nearest_red_zone_distance_km': 10.0,
        'electricity': True,
        'water_supply': True,
        'sanitation_facilities': True
    }


@pytest.fixture
def sample_red_zone():
    """Sample red zone data"""
    return {
        'zone_id': 'RZ_TEST_001',
        'hazard_type': 'LANDSLIDE',
        'severity_level': 'HIGH',
        'geometry': 'POLYGON((77.2 28.5, 77.3 28.5, 77.3 28.6, 77.2 28.6, 77.2 28.5))',
        'center_lat': 28.55,
        'center_lon': 77.25,
        'area_sq_km': 12.5,
        'status': 'ACTIVE',
        'confidence_score': 85.0
    }


@pytest.fixture
def mock_user():
    """Mock authenticated user"""
    return {
        'user_id': 'test_user_001',
        'username': 'testuser',
        'role': 'ANALYST',
        'exp': 9999999999
    }


@pytest.fixture
def admin_user():
    """Mock admin user"""
    return {
        'user_id': 'admin_user_001',
        'username': 'admin',
        'role': 'ADMIN',
        'exp': 9999999999
    }


@pytest.fixture
def sample_sync_data():
    """Sample sync data"""
    return {
        'device_id': 'DEVICE_TEST_001',
        'data_type': 'field_survey',
        'payload': {
            'records': [
                {
                    'habitation_id': 'HAB_001',
                    'field_observation': 'Road condition damaged',
                    'timestamp': '2024-01-15T10:00:00Z'
                }
            ]
        },
        'timestamp': '2024-01-15T10:00:00Z',
        'signature': 'test_signature'
    }


@pytest.fixture
def sample_grid_cells():
    """Sample grid cells for batch prediction"""
    return [
        {
            'latitude': 28.5 + (i * 0.01),
            'longitude': 77.2 + (i * 0.01),
            'precipitation_24h_mm': 40.0 + (i * 5.0),
            'precipitation_72h_mm': 100.0 + (i * 10.0),
            'slope_percentage': 20.0 + (i * 2.0),
            'elevation': 1400.0 + (i * 50.0),
            'lithology': 'GRANITE' if i % 2 == 0 else 'SANDSTONE',
            'soil_moisture_index': 0.6 + (i * 0.05),
            'vegetation_index': 0.5 + (i * 0.05),
            'hazard_type': 'landslide'
        }
        for i in range(10)
    ]


@pytest.fixture
def sample_census_data():
    """Sample census data"""
    return {
        'census_id': 'CEN_TEST_001',
        'state_code': 'MH',
        'state_name': 'MAHARASHTRA',
        'district_code': 'MHPU',
        'district_name': 'PUNE',
        'village_code': 'MHPUV0001',
        'village_name': 'Test Village',
        'latitude': 18.5,
        'longitude': 73.9,
        'total_population': 500,
        'male_population': 260,
        'female_population': 240,
        'population_0_6': 60,
        'population_7_14': 75,
        'population_15_59': 325,
        'population_60_plus': 40,
        'sc_population': 75,
        'st_population': 50,
        'total_households': 100,
        'literacy_rate': 78.5,
        'census_year': 2011,
        'data_source': 'CENSUS'
    }


@pytest.fixture
def sample_environmental_data():
    """Sample environmental data"""
    return {
        'data_id': 'ENV_TEST_001',
        'latitude': 28.5,
        'longitude': 77.2,
        'elevation': 1500.0,
        'slope_percentage': 25.0,
        'lithology': 'GRANITE',
        'soil_type': 'SANDY_LOAM',
        'land_use': 'AGRICULTURE',
        'vegetation_index': 0.6,
        'precipitation_24h_mm': 45.0,
        'temperature_celsius': 25.0,
        'humidity_percentage': 75.0,
        'data_type': 'TERRAIN',
        'data_source': 'ISRO_BHUVAN'
    }


# Async test configuration
@pytest.fixture
async def async_client():
    """Async HTTP client for testing"""
    from httpx import AsyncClient
    async with AsyncClient(app=None, base_url="http://test") as client:
        yield client