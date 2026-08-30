"""
Data ingestion tests
"""
import pytest
from datetime import datetime, timedelta
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.ingestion.isro_bhuvan import ISROBhuvanIngestor
from app.ingestion.imd_rainfall import IMDRainfallIngestor
from app.ingestion.census_data import CensusDataIngestor
from app.ingestion.validators import (
    EnvironmentalDataValidator,
    CensusDataValidator,
    DataQualityValidator,
    validate_batch
)


def test_isro_bhuvan_ingestor():
    """Test ISRO Bhuvan ingestor initialization and data fetching"""
    config = {
        'data_types': ['elevation', 'slope'],
        'resolution': 30
    }
    
    ingestor = ISROBhuvanIngestor(config)
    assert ingestor is not None
    assert ingestor.data_types == ['elevation', 'slope']
    
    # Test data fetching
    data = ingestor.fetch_data()
    assert isinstance(data, list)
    assert len(data) > 0


def test_isro_bhuvan_validation():
    """Test ISRO Bhuvan data validation"""
    config = {'data_types': ['elevation']}
    ingestor = ISROBhuvanIngestor(config)
    
    # Fetch sample data
    data = ingestor.fetch_data()
    
    # Validate data
    validated_data = ingestor.validate_data(data)
    assert isinstance(validated_data, list)
    assert len(validated_data) <= len(data)  # Some may be filtered out


def test_isro_bhuvan_transformation():
    """Test ISRO Bhuvan data transformation"""
    config = {'data_types': ['elevation']}
    ingestor = ISROBhuvanIngestor(config)
    
    # Fetch and validate data
    data = ingestor.fetch_data()
    validated_data = ingestor.validate_data(data)
    
    # Transform data
    transformed_data = ingestor.transform_data(validated_data)
    assert isinstance(transformed_data, list)
    
    # Check that geometry is added
    if transformed_data:
        assert 'geometry' in transformed_data[0]
        assert 'observation_timestamp' in transformed_data[0]


def test_imd_rainfall_ingestor():
    """Test IMD rainfall ingestor initialization and data fetching"""
    config = {
        'radar_data': True,
        'station_data': True
    }
    
    ingestor = IMDRainfallIngestor(config)
    assert ingestor is not None
    assert ingestor.include_radar is True
    assert ingestor.include_station is True
    
    # Test data fetching
    data = ingestor.fetch_data()
    assert isinstance(data, list)
    assert len(data) > 0


def test_imd_rainfall_validation():
    """Test IMD rainfall data validation"""
    config = {'radar_data': True}
    ingestor = IMDRainfallIngestor(config)
    
    # Fetch sample data
    data = ingestor.fetch_data()
    
    # Validate data
    validated_data = ingestor.validate_data(data)
    assert isinstance(validated_data, list)
    assert len(validated_data) <= len(data)


def test_imd_rainfall_transformation():
    """Test IMD rainfall data transformation"""
    config = {'radar_data': True}
    ingestor = IMDRainfallIngestor(config)
    
    # Fetch and validate data
    data = ingestor.fetch_data()
    validated_data = ingestor.validate_data(data)
    
    # Transform data
    transformed_data = ingestor.transform_data(validated_data)
    assert isinstance(transformed_data, list)
    
    # Check that derived fields are added
    if transformed_data:
        assert 'geometry' in transformed_data[0]
        assert 'soil_moisture_index' in transformed_data[0] or 'soil_saturation_percentage' in transformed_data[0]


def test_census_data_ingestor():
    """Test Census data ingestor initialization and data fetching"""
    config = {
        'data_types': ['population', 'demographics']
    }
    
    ingestor = CensusDataIngestor(config)
    assert ingestor is not None
    assert ingestor.data_types == ['population', 'demographics']
    
    # Test data fetching
    data = ingestor.fetch_data()
    assert isinstance(data, list)
    assert len(data) > 0


def test_census_data_validation():
    """Test Census data validation"""
    config = {'data_types': ['population']}
    ingestor = CensusDataIngestor(config)
    
    # Fetch sample data
    data = ingestor.fetch_data()
    
    # Validate data
    validated_data = ingestor.validate_data(data)
    assert isinstance(validated_data, list)
    assert len(validated_data) <= len(data)


def test_census_data_transformation():
    """Test Census data transformation"""
    config = {'data_types': ['population']}
    ingestor = CensusDataIngestor(config)
    
    # Fetch and validate data
    data = ingestor.fetch_data()
    validated_data = ingestor.validate_data(data)
    
    # Transform data
    transformed_data = ingestor.transform_data(validated_data)
    assert isinstance(transformed_data, list)
    
    # Check that derived fields are added
    if transformed_data:
        assert 'import_timestamp' in transformed_data[0]
        assert 'population_density_per_sqkm' in transformed_data[0]
        assert 'elderly_percentage' in transformed_data[0]


def test_environmental_data_validator():
    """Test environmental data validator"""
    valid_data = {
        'data_id': 'ENV_001',
        'latitude': 28.5,
        'longitude': 77.2,
        'data_type': 'TERRAIN',
        'data_source': 'ISRO_BHUVAN',
        'elevation': 1500.0,
        'slope_percentage': 25.0,
        'precipitation_current_mm': 10.0,
        'precipitation_24h_mm': 45.0,
        'temperature_celsius': 25.0,
        'humidity_percentage': 65.0,
        'wind_speed_kmh': 15.0
    }
    
    # Should validate successfully
    validator = EnvironmentalDataValidator(**valid_data)
    assert validator.latitude == 28.5
    assert validator.data_type == 'TERRAIN'
    
    # Test invalid data
    invalid_data = valid_data.copy()
    invalid_data['latitude'] = 95.0  # Invalid latitude
    
    with pytest.raises(Exception):
        EnvironmentalDataValidator(**invalid_data)


def test_census_data_validator():
    """Test census data validator"""
    valid_data = {
        'census_id': 'CEN_MH_PUNE_0001',
        'state_code': 'MH',
        'district_name': 'PUNE',
        'village_name': 'Test Village',
        'total_population': 500,
        'male_population': 260,
        'female_population': 240,
        'population_0_6': 60,
        'population_60_plus': 40,
        'literacy_rate': 85.0
    }
    
    # Should validate successfully
    validator = CensusDataValidator(**valid_data)
    assert validator.state_code == 'MH'
    assert validator.total_population == 500
    
    # Test invalid data
    invalid_data = valid_data.copy()
    invalid_data['total_population'] = -100  # Invalid population
    
    with pytest.raises(Exception):
        CensusDataValidator(**invalid_data)


def test_data_quality_completeness():
    """Test data quality completeness assessment"""
    record = {
        'data_id': 'TEST_001',
        'latitude': 28.5,
        'longitude': 77.2,
        'data_type': 'TERRAIN'
    }
    
    required_fields = ['data_id', 'latitude', 'longitude', 'data_type']
    completeness = DataQualityValidator.assess_completeness(record, required_fields)
    
    assert completeness == 100.0
    
    # Test with missing fields
    partial_record = {
        'data_id': 'TEST_002',
        'latitude': 28.5
    }
    partial_completeness = DataQualityValidator.assess_completeness(partial_record, required_fields)
    
    assert partial_completeness < 100.0


def test_data_quality_consistency():
    """Test data quality consistency assessment"""
    consistent_record = {
        'total_population': 500,
        'male_population': 260,
        'female_population': 240,
        'literacy_rate': 75.0,
        'male_literacy_rate': 80.0,
        'female_literacy_rate': 70.0
    }
    
    consistency = DataQualityValidator.assess_consistency(consistent_record)
    assert consistency >= 80.0  # Should be high for consistent data
    
    # Test with inconsistent data
    inconsistent_record = {
        'total_population': 500,
        'male_population': 300,
        'female_population': 300,  # Sum exceeds total
        'literacy_rate': 75.0,
        'male_literacy_rate': 60.0,
        'female_literacy_rate': 90.0  # Inconsistent with overall
    }
    
    inconsistency = DataQualityValidator.assess_consistency(inconsistent_record)
    assert inconsistency < consistency  # Should be lower for inconsistent data


def test_data_quality_temporal_freshness():
    """Test data quality temporal freshness assessment"""
    # Fresh data
    fresh_record = {
        'observation_timestamp': (datetime.utcnow() - timedelta(hours=1)).isoformat()
    }
    freshness = DataQualityValidator.assess_temporal_freshness(fresh_record, max_age_days=7)
    assert freshness > 90.0
    
    # Old data
    old_record = {
        'observation_timestamp': (datetime.utcnow() - timedelta(days=30)).isoformat()
    }
    old_freshness = DataQualityValidator.assess_temporal_freshness(old_record, max_age_days=7)
    assert old_freshness < freshness


def test_overall_quality_assessment():
    """Test overall data quality assessment"""
    record = {
        'data_id': 'TEST_001',
        'latitude': 28.5,
        'longitude': 77.2,
        'data_type': 'TERRAIN',
        'observation_timestamp': (datetime.utcnow()).isoformat()
    }
    
    required_fields = ['data_id', 'latitude', 'longitude', 'data_type']
    quality = DataQualityValidator.get_overall_quality_score(record, required_fields)
    
    assert 'overall_score' in quality
    assert 'completeness' in quality
    assert 'consistency' in quality
    assert 'freshness' in quality
    assert 'quality_level' in quality
    assert 0 <= quality['overall_score'] <= 100


def test_batch_validation():
    """Test batch data validation"""
    records = [
        {
            'data_id': f'ENV_{i}',
            'latitude': 28.5 + (i * 0.1),
            'longitude': 77.2 + (i * 0.1),
            'data_type': 'TERRAIN',
            'data_source': 'ISRO_BHUVAN'
        }
        for i in range(10)
    ]
    
    validation_results = validate_batch(records, EnvironmentalDataValidator)
    
    assert 'total_records' in validation_results
    assert 'valid_records' in validation_results
    assert 'invalid_records' in validation_results
    assert validation_results['total_records'] == 10


def test_ingestion_pipeline():
    """Test complete ingestion pipeline"""
    config = {'data_types': ['elevation']}
    ingestor = ISROBhuvanIngestor(config)
    
    # Run full ingestion pipeline
    result = ingestor.ingest()
    
    assert 'success' in result
    assert 'records_processed' in result
    assert 'start_time' in result
    assert 'end_time' in result