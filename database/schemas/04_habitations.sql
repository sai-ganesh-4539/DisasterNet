-- Vulnerable Habitations Schema
-- This schema defines habitations (villages/settlements) that may need relocation

-- Habitations table
CREATE TABLE habitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    habitation_id VARCHAR(50) UNIQUE NOT NULL,  -- Unique identifier for the habitation
    
    -- Spatial data
    geometry GEOMETRY(POINT, 4326) NOT NULL,  -- Habitation center point (WGS84)
    boundary_geometry GEOMETRY(POLYGON, 4326),  -- Habitation boundary (if available)
    latitude DECIMAL(10, 7) NOT NULL,  -- Latitude
    longitude DECIMAL(10, 7) NOT NULL,  -- Longitude
    elevation DECIMAL(10, 2),  -- Elevation in meters
    
    -- Geographic identifiers
    state_code VARCHAR(10) NOT NULL,  -- State code
    state_name VARCHAR(100) NOT NULL,  -- State name
    district_code VARCHAR(10) NOT NULL,  -- District code
    district_name VARCHAR(100) NOT NULL,  -- District name
    tehsil_code VARCHAR(10),  -- Tehsil code
    tehsil_name VARCHAR(100),  -- Tehsil name
    block_name VARCHAR(100),  -- Block name
    village_name VARCHAR(200) NOT NULL,  -- Village name
    village_code VARCHAR(20),  -- Village census code
    
    -- Demographic data
    total_population INTEGER NOT NULL,  -- Total population
    household_count INTEGER,  -- Number of households
    male_population INTEGER,  -- Male population
    female_population INTEGER,  -- Female population
    children_0_6 INTEGER,  -- Children aged 0-6
    elderly_population INTEGER,  -- Elderly population (60+)
    disabled_population INTEGER,  -- Disabled population
    
    -- Vulnerability factors
    population_density_per_sqkm DECIMAL(10, 2),  -- Population density
    elderly_percentage DECIMAL(5, 2),  -- Percentage of elderly population
    child_percentage DECIMAL(5, 2),  -- Percentage of children
    disability_percentage DECIMAL(5, 2),  -- Percentage of disabled population
    economic_status VARCHAR(50),  -- Economic status: BPL, APL, MIXED
    vulnerability_score DECIMAL(5, 2),  -- Overall vulnerability score (0-100)
    
    -- Access and infrastructure
    road_connectivity VARCHAR(50),  -- Road connectivity: PAVED, UNPAVED, NONE, SEASONAL
    road_distance_km DECIMAL(7, 2),  -- Distance to main road in km
    nearest_emergency_km DECIMAL(7, 2),  -- Distance to emergency services in km
    communication_availability VARCHAR(50),  -- Communication: MOBILE, LANDLINE, NONE, LIMITED
    electricity_availability BOOLEAN,  -- Electricity availability
    water_source VARCHAR(100),  -- Water source type
    
    -- Evacuation infrastructure
    evacuation_route_status VARCHAR(50),  -- Evacuation route status: CLEAR, BLOCKED, DAMAGED
    evacuation_route_capacity VARCHAR(50),  -- Route capacity: HIGH, MEDIUM, LOW
    shelter_distance_km DECIMAL(7, 2),  -- Distance to nearest shelter in km
    evacuation_time_hours DECIMAL(5, 2),  -- Estimated evacuation time in hours
    
    -- Hazard exposure
    current_red_zone_id UUID,  -- Reference to current red zone if applicable
    red_zone_proximity_km DECIMAL(7, 2),  -- Distance to nearest red zone in km
    hazard_history TEXT[],  -- Array of past hazard events
    disaster_frequency_score DECIMAL(5, 2),  -- Score based on disaster history
    
    -- Relocation assessment
    priority_score DECIMAL(5, 2),  -- Overall priority score (0-100)
    priority_category VARCHAR(20),  -- Priority category: IMMEDIATE, SHORT_TERM, MEDIUM_TERM
    relocation_status VARCHAR(20) DEFAULT 'NOT_REQUIRED',  -- Status: NOT_REQUIRED, PENDING, IN_PROGRESS, COMPLETED
    relocation_urgency VARCHAR(20),  -- Urgency: CRITICAL, HIGH, MEDIUM, LOW
    
    -- Target relocation site (if identified)
    target_shelter_id UUID,  -- Reference to target shelter
    target_location_lat DECIMAL(10, 7),  -- Target location latitude
    target_location_lon DECIMAL(10, 7),  -- Target location longitude
    estimated_relocation_cost DECIMAL(15, 2),  -- Estimated relocation cost
    
    -- Metadata
    last_assessment_timestamp TIMESTAMP WITH TIME ZONE,  -- Last risk assessment timestamp
    assessment_method VARCHAR(50),  -- Assessment method: AI, MANUAL, HYBRID
    data_source VARCHAR(50),  -- Primary data source
    last_census_year INTEGER,  -- Last census year for demographic data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create spatial index on geometry
CREATE INDEX idx_habitations_geometry ON habitations USING GIST (geometry);
CREATE INDEX idx_habitations_boundary ON habitations USING GIST (boundary_geometry);

-- Create indexes on frequently queried columns
CREATE INDEX idx_habitations_habitation_id ON habitations (habitation_id);
CREATE INDEX idx_habitations_state_district ON habitations (state_code, district_code);
CREATE INDEX idx_habitations_priority_category ON habitations (priority_category);
CREATE INDEX idx_habitations_relocation_status ON habitations (relocation_status);
CREATE INDEX idx_habitations_priority_score ON habitations (priority_score);
CREATE INDEX idx_habitations_red_zone_proximity ON habitations (red_zone_proximity_km);

-- Create foreign key to red_zones
ALTER TABLE habitations 
ADD CONSTRAINT fk_habitations_red_zone 
FOREIGN KEY (current_red_zone_id) 
REFERENCES red_zones(id) 
ON DELETE SET NULL;

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_habitations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_habitations_updated_at
    BEFORE UPDATE ON habitations
    FOR EACH ROW
    EXECUTE FUNCTION update_habitations_updated_at();

-- Add comments
COMMENT ON TABLE habitations IS 'Vulnerable habitations requiring risk assessment and potential relocation';
COMMENT ON COLUMN habitations.geometry IS 'Habitation center point in WGS84 (EPSG:4326)';
COMMENT ON COLUMN habitations.priority_category IS 'Relocation priority: IMMEDIATE (0-24h), SHORT_TERM (1-4 weeks), MEDIUM_TERM (1-6 months)';
COMMENT ON COLUMN habitations.vulnerability_score IS 'Overall vulnerability score (0-100) based on demographic factors';
