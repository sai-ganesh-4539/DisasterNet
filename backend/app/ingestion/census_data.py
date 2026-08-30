"""
Census data ingestion (batch import)
"""
from typing import Dict, List, Optional, Any
import pandas as pd
from datetime import datetime
import logging
from app.ingestion.base_ingestor import BaseIngestor
from app.core.config import settings
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class CensusDataIngestor(BaseIngestor):
    """Ingestor for Census data (batch import)"""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        super().__init__(config)
        self.batch_import_path = settings.batch_import_path
        self.data_types = config.get('data_types', ['population', 'demographics', 'housing', 'amenities'])
        self.current_year = datetime.now().year
    
    def fetch_data(self) -> List[Dict[str, Any]]:
        """Fetch census data from batch files"""
        data = []
        
        try:
            logger.info(f"Looking for census data in: {self.batch_import_path}")
            
            # Check if batch import directory exists
            if not os.path.exists(self.batch_import_path):
                logger.warning(f"Batch import directory does not exist: {self.batch_import_path}")
                # Create sample data for development
                return self._get_sample_census_data()
            
            # Look for census data files
            # This would read actual CSV/Excel files in production
            # For now, return sample data
            logger.info("Using sample census data for development")
            data = self._get_sample_census_data()
            
        except Exception as e:
            logger.error(f"Error fetching census data: {str(e)}")
            raise
        
        return data
    
    def _get_sample_census_data(self) -> List[Dict[str, Any]]:
        """Generate sample census data for development/testing"""
        sample_data = []
        
        # Generate sample village-level census data
        states = ['MH', 'KA', 'TN', 'UP', 'GJ']  # Maharashtra, Karnataka, Tamil Nadu, Uttar Pradesh, Gujarat
        districts = {
            'MH': ['PUNE', 'MUMBAI', 'NASHIK'],
            'KA': ['BENGALURU', 'MYSURU', 'HUBBALLI'],
            'TN': ['CHENNAI', 'COIMBATORE', 'MADURAI'],
            'UP': ['LUCKNOW', 'KANPUR', 'AGRA'],
            'GJ': ['AHMEDABAD', 'SURAT', 'VADODARA']
        }
        
        for i, state in enumerate(states):
            for j, district in enumerate(districts[state]):
                for k in range(3):  # 3 villages per district
                    village_num = (i * 9) + (j * 3) + k
                    
                    # Sample demographic data
                    total_pop = 500 + (village_num * 50)
                    male_pop = int(total_pop * 0.52)
                    female_pop = total_pop - male_pop
                    children_0_6 = int(total_pop * 0.12)
                    elderly = int(total_pop * 0.08)
                    
                    sample_data.append({
                        'census_id': f'CEN_{state}_{district}_{village_num:04d}',
                        'state_code': state,
                        'state_name': self._get_state_name(state),
                        'district_code': f'{state}{district[:2].upper()}',
                        'district_name': district,
                        'tehsil_code': f'{state}{district[:2].upper()}T{k+1}',
                        'tehsil_name': f'{district} TEHSIL {k+1}',
                        'village_code': f'{state}{district[:2].upper()}V{village_num:04d}',
                        'village_name': f'VILLAGE {village_num+1}',
                        'latitude': 18.0 + (i * 2.0) + (j * 0.5) + (k * 0.1),
                        'longitude': 73.0 + (i * 2.0) + (j * 0.5) + (k * 0.1),
                        'total_population': total_pop,
                        'male_population': male_pop,
                        'female_population': female_pop,
                        'population_0_6': children_0_6,
                        'population_7_14': int(total_pop * 0.15),
                        'population_15_59': int(total_pop * 0.65),
                        'population_60_plus': elderly,
                        'sc_population': int(total_pop * 0.15),
                        'st_population': int(total_pop * 0.10),
                        'total_households': int(total_pop / 5),
                        'occupied_households': int(total_pop / 5.2),
                        'vacant_households': int(total_pop / 50),
                        'pucca_households': int(total_pop / 8),
                        'semi_pucca_households': int(total_pop / 10),
                        'kuccha_households': int(total_pop / 20),
                        'households_with_electricity': int(total_pop / 5.5),
                        'households_with_water': int(total_pop / 5.3),
                        'households_with_sanitation': int(total_pop / 6),
                        'main_workers': int(total_pop * 0.35),
                        'marginal_workers': int(total_pop * 0.10),
                        'non_workers': int(total_pop * 0.55),
                        'cultivators': int(total_pop * 0.20),
                        'agricultural_laborers': int(total_pop * 0.12),
                        'household_industry_workers': int(total_pop * 0.03),
                        'other_workers': int(total_pop * 0.25),
                        'literacy_rate': round(70.0 + (village_num * 0.5), 2),
                        'male_literacy_rate': round(78.0 + (village_num * 0.4), 2),
                        'female_literacy_rate': round(62.0 + (village_num * 0.6), 2),
                        'has_school': village_num % 2 == 0,
                        'has_health_center': village_num % 3 == 0,
                        'has_post_office': village_num % 4 == 0,
                        'has_bank': village_num % 5 == 0,
                        'has_market': village_num % 3 != 0,
                        'census_year': 2011,  # Last census year
                        'census_version': 'FINAL',
                        'data_source': 'CENSUS'
                    })
        
        return sample_data
    
    def _get_state_name(self, state_code: str) -> str:
        """Get full state name from code"""
        state_names = {
            'MH': 'MAHARASHTRA',
            'KA': 'KARNATAKA',
            'TN': 'TAMIL NADU',
            'UP': 'UTTAR PRADESH',
            'GJ': 'GUJARAT'
        }
        return state_names.get(state_code, state_code)
    
    def validate_data(self, data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Validate census data"""
        validated_data = []
        
        for record in data:
            try:
                # Check required fields
                required_fields = ['census_id', 'state_code', 'district_name', 'village_name', 'total_population']
                if not all(key in record for key in required_fields):
                    logger.warning(f"Missing required fields in record: {record.get('census_id')}")
                    continue
                
                # Validate coordinate ranges
                lat = record.get('latitude')
                lon = record.get('longitude')
                
                if lat is not None and not (-90 <= lat <= 90):
                    logger.warning(f"Invalid latitude in record: {record.get('census_id')}")
                    continue
                
                if lon is not None and not (-180 <= lon <= 180):
                    logger.warning(f"Invalid longitude in record: {record.get('census_id')}")
                    continue
                
                # Validate population data (should be positive)
                if record['total_population'] <= 0:
                    logger.warning(f"Invalid population in record: {record.get('census_id')}")
                    continue
                
                # Validate demographic consistency
                male_pop = record.get('male_population', 0)
                female_pop = record.get('female_population', 0)
                total_pop = record['total_population']
                
                if male_pop + female_pop > total_pop:
                    logger.warning(f"Demographic inconsistency in record: {record.get('census_id')}")
                    continue
                
                # Validate literacy rates (0-100)
                for lit_field in ['literacy_rate', 'male_literacy_rate', 'female_literacy_rate']:
                    if lit_field in record:
                        rate = record[lit_field]
                        if not (0 <= rate <= 100):
                            logger.warning(f"Invalid literacy rate in record: {record.get('census_id')}")
                            continue
                
                validated_data.append(record)
                
            except Exception as e:
                logger.warning(f"Validation error for record: {str(e)}")
                continue
        
        return validated_data
    
    def transform_data(self, data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Transform data to database format"""
        transformed_data = []
        
        for record in data:
            try:
                # Add geometry if coordinates are available
                if 'latitude' in record and 'longitude' in record:
                    lat = record['latitude']
                    lon = record['longitude']
                    record['geometry'] = f'POINT({lon} {lat})'
                
                # Add import timestamp
                record['import_timestamp'] = datetime.utcnow().isoformat()
                
                # Calculate derived demographic indicators
                total_pop = record['total_population']
                
                # Calculate population density (assuming 5 sq km area per village)
                record['population_density_per_sqkm'] = round(total_pop / 5.0, 2)
                
                # Calculate vulnerability factors
                elderly = record.get('population_60_plus', 0)
                children = record.get('population_0_6', 0)
                disabled = record.get('disabled_population', 0)  # If available
                
                record['elderly_percentage'] = round((elderly / total_pop) * 100, 2) if total_pop > 0 else 0
                record['child_percentage'] = round((children / total_pop) * 100, 2) if total_pop > 0 else 0
                record['disability_percentage'] = round((disabled / total_pop) * 100, 2) if total_pop > 0 else 0
                
                # Economic status estimation based on housing
                pucca = record.get('pucca_households', 0)
                total_households = record.get('total_households', 1)
                pucca_ratio = pucca / total_households if total_households > 0 else 0
                
                if pucca_ratio > 0.7:
                    record['economic_status'] = 'APL'  # Above Poverty Line
                elif pucca_ratio > 0.3:
                    record['economic_status'] = 'MIXED'
                else:
                    record['economic_status'] = 'BPL'  # Below Poverty Line
                
                transformed_data.append(record)
                
            except Exception as e:
                logger.error(f"Transform error for record: {str(e)}")
                continue
        
        return transformed_data
    
    def save_data(self, data: List[Dict[str, Any]]) -> bool:
        """Save census data to database"""
        try:
            # This would insert data into the census_data table
            # For now, just log the operation
            logger.info(f"Saving {len(data)} census records to database")
            
            # Example SQL structure (would use SQLAlchemy in production):
            # INSERT INTO census_data (census_id, state_code, state_name, district_code, 
            # district_name, tehsil_code, tehsil_name, village_code, village_name, 
            # geometry, total_population, male_population, female_population, 
            # population_0_6, population_7_14, population_15_59, population_60_plus, 
            # sc_population, st_population, total_households, occupied_households, 
            # vacant_households, pucca_households, semi_pucca_households, kuccha_households, 
            # households_with_electricity, households_with_water, households_with_sanitation, 
            # main_workers, marginal_workers, non_workers, cultivators, agricultural_laborers, 
            # household_industry_workers, other_workers, literacy_rate, male_literacy_rate, 
            # female_literacy_rate, has_school, has_health_center, has_post_office, has_bank, 
            # has_market, census_year, census_version, data_source, import_timestamp, 
            # population_density_per_sqkm, elderly_percentage, child_percentage, 
            # disability_percentage, economic_status)
            # VALUES (...)
            
            return True
            
        except Exception as e:
            logger.error(f"Error saving census data: {str(e)}")
            return False