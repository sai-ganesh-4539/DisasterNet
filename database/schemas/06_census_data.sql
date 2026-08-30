-- Census Data Schema
-- This schema stores demographic and socio-economic census data

-- Census data table
CREATE TABLE census_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    census_id VARCHAR(50) UNIQUE NOT NULL,  -- Unique identifier for census record
    
    -- Geographic identifiers
    state_code VARCHAR(10) NOT NULL,  -- State code
    state_name VARCHAR(100) NOT NULL,  -- State name
    district_code VARCHAR(10) NOT NULL,  -- District code
    district_name VARCHAR(100) NOT NULL,  -- District name
    tehsil_code VARCHAR(10),  -- Tehsil code
    tehsil_name VARCHAR(100),  -- Tehsil name
    village_code VARCHAR(20),  -- Village census code
    village_name VARCHAR(200),  -- Village name
    
    -- Spatial reference
    geometry GEOMETRY(POINT, 4326),  -- Location point (WGS84)
    
    -- Population demographics
    total_population INTEGER NOT NULL,  -- Total population
    male_population INTEGER,  -- Male population
    female_population INTEGER,  -- Female population
    population_0_6 INTEGER,  -- Population aged 0-6
    population_7_14 INTEGER,  -- Population aged 7-14
    population_15_59 INTEGER,  -- Population aged 15-59
    population_60_plus INTEGER,  -- Population aged 60+
    sc_population INTEGER,  -- Scheduled Caste population
    st_population INTEGER,  -- Scheduled Tribe population
    
    -- Household data
    total_households INTEGER,  -- Total households
    occupied_households INTEGER,  -- Occupied households
    vacant_households INTEGER,  -- Vacant households
    
    -- Housing characteristics
    pucca_households INTEGER,  -- Pucca (permanent) households
    semi_pucca_households INTEGER,  -- Semi-pucca households
    kuccha_households INTEGER,  -- Kuccha (temporary) households
    households_with_electricity INTEGER,  -- Households with electricity
    households_with_water INTEGER,  -- Households with water supply
    households_with_sanitation INTEGER,  -- Households with sanitation
    
    -- Economic indicators
    main_workers INTEGER,  -- Main workers
    marginal_workers INTEGER,  -- Marginal workers
    non_workers INTEGER,  -- Non-workers
    cultivators INTEGER,  -- Cultivators
    agricultural_laborers INTEGER,  -- Agricultural laborers
    household_industry_workers INTEGER,  -- Household industry workers
    other_workers INTEGER,  -- Other workers
    
    -- Education indicators
    literacy_rate DECIMAL(5, 2),  -- Overall literacy rate
    male_literacy_rate DECIMAL(5, 2),  -- Male literacy rate
    female_literacy_rate DECIMAL(5, 2),  -- Female literacy rate
    
    -- Amenities
    has_school BOOLEAN,  -- Has school facility
    has_health_center BOOLEAN,  -- Has health center
    has_post_office BOOLEAN,  -- Has post office
    has_bank BOOLEAN,  -- Has bank
    has_market BOOLEAN,  -- Has market
    
    -- Metadata
    census_year INTEGER NOT NULL,  -- Census year
    census_version VARCHAR(20),  -- Census version/phase
    data_source VARCHAR(50),  -- Data source
    import_timestamp TIMESTAMP WITH TIME ZONE,  -- Data import timestamp
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create spatial index on geometry
CREATE INDEX idx_census_data_geometry ON census_data USING GIST (geometry);

-- Create indexes on frequently queried columns
CREATE INDEX idx_census_data_census_id ON census_data (census_id);
CREATE INDEX idx_census_data_state_district ON census_data (state_code, district_code);
CREATE INDEX idx_census_data_village_code ON census_data (village_code);
CREATE INDEX idx_census_data_census_year ON census_data (census_year);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_census_data_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_census_data_updated_at
    BEFORE UPDATE ON census_data
    FOR EACH ROW
    EXECUTE FUNCTION update_census_data_updated_at();

-- Add comments
COMMENT ON TABLE census_data IS 'Demographic and socio-economic census data for habitations';
COMMENT ON COLUMN census_data.geometry IS 'Location point in WGS84 (EPSG:4326)';
COMMENT ON COLUMN census_data.census_year IS 'Census year for the data';
