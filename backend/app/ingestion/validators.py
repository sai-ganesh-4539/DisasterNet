"""
Data validation schemas and utilities
"""
from typing import Dict, List, Any, Optional
from pydantic import BaseModel, field_validator, Field
from datetime import datetime
import re


class CoordinateValidator(BaseModel):
    """Validator for geographic coordinates"""
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class EnvironmentalDataValidator(BaseModel):
    """Validator for environmental data"""
    data_id: str
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    data_type: str
    data_source: str
    
    # Optional environmental fields
    elevation: Optional[float] = Field(ge=-500, le=9000)  # Dead Sea to Everest
    slope_percentage: Optional[float] = Field(ge=0, le=100)
    precipitation_current_mm: Optional[float] = Field(ge=0)
    precipitation_24h_mm: Optional[float] = Field(ge=0)
    temperature_celsius: Optional[float] = Field(ge=-50, le=60)
    humidity_percentage: Optional[float] = Field(ge=0, le=100)
    wind_speed_kmh: Optional[float] = Field(ge=0, le=500)
    
    @field_validator('data_type')
    def validate_data_type(cls, v):
        valid_types = ['TERRAIN', 'WEATHER', 'HYDROLOGICAL', 'SEISMIC', 'COASTAL']
        if v.upper() not in valid_types:
            raise ValueError(f'Invalid data_type: {v}. Must be one of {valid_types}')
        return v.upper()
    
    @field_validator('data_source')
    def validate_data_source(cls, v):
        valid_sources = ['ISRO_BHUVAN', 'IMD', 'CENSUS', 'MANUAL', 'OTHER']
        if v.upper() not in valid_sources:
            raise ValueError(f'Invalid data_source: {v}. Must be one of {valid_sources}')
        return v.upper()


class CensusDataValidator(BaseModel):
    """Validator for census data"""
    census_id: str
    state_code: str
    district_name: str
    village_name: str
    total_population: int = Field(gt=0)
    
    # Optional demographic fields
    male_population: Optional[int] = Field(ge=0)
    female_population: Optional[int] = Field(ge=0)
    population_0_6: Optional[int] = Field(ge=0)
    population_60_plus: Optional[int] = Field(ge=0)
    literacy_rate: Optional[float] = Field(ge=0, le=100)
    
    @field_validator('state_code')
    def validate_state_code(cls, v):
        # Validate Indian state codes (2-3 characters)
        if not re.match(r'^[A-Z]{2,3}$', v.upper()):
            raise ValueError('state_code must be 2-3 uppercase letters')
        return v.upper()
    
    @field_validator('census_id')
    def validate_census_id(cls, v):
        if not re.match(r'^CEN_[A-Z]{2,3}_[A-Z]+_\d{4}$', v):
            raise ValueError('census_id must match pattern: CEN_STATE_DISTRICT_####')
        return v


class HabitationDataValidator(BaseModel):
    """Validator for habitation data"""
    habitation_id: str
    state_code: str
    district_name: str
    village_name: str
    total_population: int = Field(gt=0)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    
    # Optional vulnerability fields
    elderly_percentage: Optional[float] = Field(ge=0, le=100)
    child_percentage: Optional[float] = Field(ge=0, le=100)
    disability_percentage: Optional[float] = Field(ge=0, le=100)
    vulnerability_score: Optional[float] = Field(ge=0, le=100)
    
    @field_validator('vulnerability_score')
    def validate_vulnerability_score(cls, v):
        if v is not None and (v < 0 or v > 100):
            raise ValueError('vulnerability_score must be between 0 and 100')
        return v


class ShelterDataValidator(BaseModel):
    """Validator for shelter data"""
    shelter_id: str
    shelter_name: str
    shelter_type: str
    state_code: str
    district_name: str
    total_capacity: int = Field(gt=0)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    
    # Optional capacity fields
    current_occupancy: Optional[int] = Field(ge=0)
    water_sufficiency_days: Optional[float] = Field(ge=0)
    food_ration_storage_days: Optional[float] = Field(ge=0)
    effective_capacity: Optional[int] = Field(ge=0)
    
    @field_validator('shelter_type')
    def validate_shelter_type(cls, v):
        valid_types = ['PERMANENT', 'TEMPORARY', 'EMERGENCY', 'COMMUNITY']
        if v.upper() not in valid_types:
            raise ValueError(f'Invalid shelter_type: {v}. Must be one of {valid_types}')
        return v.upper()
    
    @field_validator('current_occupancy')
    def validate_occupancy(cls, v, values):
        if v is not None and 'total_capacity' in values and v > values['total_capacity']:
            raise ValueError('current_occupancy cannot exceed total_capacity')
        return v


class RedZoneDataValidator(BaseModel):
    """Validator for red zone data"""
    zone_id: str
    hazard_type: str
    severity_level: str
    geometry: str  # WKT format
    
    # Optional red zone fields
    risk_threshold_used: Optional[float] = Field(ge=0, le=100)
    confidence_score: Optional[float] = Field(ge=0, le=100)
    
    @field_validator('hazard_type')
    def validate_hazard_type(cls, v):
        valid_types = ['LANDSLIDE', 'FLOOD', 'COASTAL_EROSION', 'CLOUDBURST']
        if v.upper() not in valid_types:
            raise ValueError(f'Invalid hazard_type: {v}. Must be one of {valid_types}')
        return v.upper()
    
    @field_validator('severity_level')
    def validate_severity_level(cls, v):
        valid_levels = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
        if v.upper() not in valid_levels:
            raise ValueError(f'Invalid severity_level: {v}. Must be one of {valid_levels}')
        return v.upper()
    
    @field_validator('geometry')
    def validate_geometry(cls, v):
        # Basic WKT validation
        if not v.startswith(('POLYGON', 'MULTIPOLYGON')):
            raise ValueError('geometry must be a valid WKT POLYGON or MULTIPOLYGON')
        return v


class DataQualityValidator:
    """Data quality assessment utilities"""
    
    @staticmethod
    def assess_completeness(record: Dict[str, Any], required_fields: List[str]) -> float:
        """Assess data completeness (0-100)"""
        if not required_fields:
            return 100.0
        
        present_fields = sum(1 for field in required_fields if field in record and record[field] is not None)
        completeness = (present_fields / len(required_fields)) * 100
        return round(completeness, 2)
    
    @staticmethod
    def assess_consistency(record: Dict[str, Any]) -> float:
        """Assess data consistency (0-100)"""
        consistency_score = 100.0
        issues = []
        
        # Check population consistency
        if 'total_population' in record:
            total = record['total_population']
            male = record.get('male_population', 0)
            female = record.get('female_population', 0)
            
            if male + female > total:
                issues.append('population_mismatch')
                consistency_score -= 20
        
        # Check literacy rate consistency
        if 'literacy_rate' in record:
            literacy = record['literacy_rate']
            male_lit = record.get('male_literacy_rate', 0)
            female_lit = record.get('female_literacy_rate', 0)
            
            # Overall literacy should be between male and female rates
            if not (min(male_lit, female_lit) <= literacy <= max(male_lit, female_lit)):
                issues.append('literacy_mismatch')
                consistency_score -= 15
        
        # Check percentage fields
        percentage_fields = ['elderly_percentage', 'child_percentage', 'disability_percentage']
        for field in percentage_fields:
            if field in record:
                value = record[field]
                if not (0 <= value <= 100):
                    issues.append(f'{field}_out_of_range')
                    consistency_score -= 10
        
        return max(0.0, round(consistency_score, 2))
    
    @staticmethod
    def assess_temporal_freshness(record: Dict[str, Any], max_age_days: int = 365) -> float:
        """Assess data temporal freshness (0-100)"""
        timestamp_fields = ['observation_timestamp', 'last_data_update', 'import_timestamp', 'created_at']
        
        for field in timestamp_fields:
            if field in record:
                try:
                    timestamp_str = record[field]
                    if isinstance(timestamp_str, str):
                        timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                    else:
                        timestamp = timestamp_str
                    
                    age_days = (datetime.utcnow() - timestamp).days
                    if age_days <= max_age_days:
                        freshness = ((max_age_days - age_days) / max_age_days) * 100
                        return round(freshness, 2)
                except Exception:
                    continue
        
        return 50.0  # Default freshness if timestamp not available
    
    @staticmethod
    def get_overall_quality_score(record: Dict[str, Any], required_fields: List[str]) -> Dict[str, Any]:
        """Get overall data quality assessment"""
        completeness = DataQualityValidator.assess_completeness(record, required_fields)
        consistency = DataQualityValidator.assess_consistency(record)
        freshness = DataQualityValidator.assess_temporal_freshness(record)
        
        # Weighted average
        overall_score = (completeness * 0.4) + (consistency * 0.4) + (freshness * 0.2)
        
        return {
            'overall_score': round(overall_score, 2),
            'completeness': completeness,
            'consistency': consistency,
            'freshness': freshness,
            'quality_level': DataQualityValidator._get_quality_level(overall_score)
        }
    
    @staticmethod
    def _get_quality_level(score: float) -> str:
        """Get quality level from score"""
        if score >= 90:
            return 'EXCELLENT'
        elif score >= 75:
            return 'GOOD'
        elif score >= 60:
            return 'ACCEPTABLE'
        elif score >= 40:
            return 'POOR'
        else:
            return 'UNACCEPTABLE'


def validate_batch(data: List[Dict[str, Any]], validator_class: type) -> Dict[str, Any]:
    """Validate a batch of data records"""
    validation_results = {
        'total_records': len(data),
        'valid_records': 0,
        'invalid_records': 0,
        'errors': [],
        'quality_scores': []
    }
    
    for record in data:
        try:
            validator_class(**record)
            validation_results['valid_records'] += 1
            
            # Assess quality
            required_fields = validator_class.__fields__.keys()
            quality_assessment = DataQualityValidator.get_overall_quality_score(record, list(required_fields))
            validation_results['quality_scores'].append(quality_assessment)
            
        except Exception as e:
            validation_results['invalid_records'] += 1
            validation_results['errors'].append({
                'record_id': record.get('id', record.get('data_id', 'unknown')),
                'error': str(e)
            })
    
    # Calculate average quality
    if validation_results['quality_scores']:
        avg_quality = sum(q['overall_score'] for q in validation_results['quality_scores']) / len(validation_results['quality_scores'])
        validation_results['average_quality_score'] = round(avg_quality, 2)
    
    return validation_results