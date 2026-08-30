-- Relocation Shelters Schema
-- This schema defines potential relocation sites and their capacity

-- Shelters table
CREATE TABLE shelters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shelter_id VARCHAR(50) UNIQUE NOT NULL,  -- Unique identifier for the shelter
    
    -- Spatial data
    geometry GEOMETRY(POINT, 4326) NOT NULL,  -- Shelter location point (WGS84)
    boundary_geometry GEOMETRY(POLYGON, 4326),  -- Shelter boundary (if available)
    latitude DECIMAL(10, 7) NOT NULL,  -- Latitude
    longitude DECIMAL(10, 7) NOT NULL,  -- Longitude
    elevation DECIMAL(10, 2),  -- Elevation in meters
    area_sq_meters DECIMAL(12, 2),  -- Area in square meters
    
    -- Shelter classification
    shelter_type VARCHAR(50) NOT NULL,  -- Type: PERMANENT, TEMPORARY, EMERGENCY, COMMUNITY
    shelter_name VARCHAR(200) NOT NULL,  -- Shelter name
    shelter_category VARCHAR(50),  -- Category: SCHOOL, COMMUNITY_HALL, GOVERNMENT_BUILDING, TENT
    ownership VARCHAR(50),  -- Ownership: GOVERNMENT, PRIVATE, NGO, COMMUNITY
    
    -- Geographic identifiers
    state_code VARCHAR(10) NOT NULL,  -- State code
    state_name VARCHAR(100) NOT NULL,  -- State name
    district_code VARCHAR(10) NOT NULL,  -- District code
    district_name VARCHAR(100) NOT NULL,  -- District name
    tehsil_name VARCHAR(100),  -- Tehsil name
    village_name VARCHAR(200),  -- Village name
    
    -- Physical capacity
    total_capacity INTEGER NOT NULL,  -- Total capacity (number of people)
    current_occupancy INTEGER DEFAULT 0,  -- Current occupancy
    available_capacity INTEGER,  -- Available capacity (calculated)
    
    -- Infrastructure resources
    physical_beds INTEGER,  -- Number of physical beds
    water_sufficiency_days DECIMAL(5, 1),  -- Days of water sufficiency at full capacity
    food_ration_storage_days DECIMAL(5, 1),  -- Days of food ration storage
    medical_facility_depth VARCHAR(50),  -- Medical facility: FULL, BASIC, NONE
    medical_beds INTEGER,  -- Number of medical beds
    medical_staff_count INTEGER,  -- Number of medical staff
    
    -- Effective capacity (bottleneck calculation)
    effective_capacity INTEGER,  -- Effective capacity based on resource bottlenecks
    capacity_constraint VARCHAR(50),  -- Primary constraint: BEDS, WATER, FOOD, MEDICAL
    
    -- Safety assessment
    safety_check_passed BOOLEAN DEFAULT FALSE,  -- Safety check result
    intersects_red_zone BOOLEAN DEFAULT FALSE,  -- Whether shelter intersects with red zone
    nearest_red_zone_distance_km DECIMAL(7, 2),  -- Distance to nearest red zone
    hazard_exposure_score DECIMAL(5, 2),  -- Hazard exposure score (0-100)
    safety_score DECIMAL(5, 2),  -- Overall safety score (0-100)
    
    -- Accessibility
    road_accessibility VARCHAR(50),  -- Road access: GOOD, FAIR, POOR, NONE
    road_distance_km DECIMAL(7, 2),  -- Distance from main road in km
    helicopter_access BOOLEAN,  -- Helicopter access availability
    boat_access BOOLEAN,  -- Boat access availability
    
    -- Utilities and services
    electricity BOOLEAN,  -- Electricity availability
    water_supply BOOLEAN,  -- Water supply availability
    sanitation_facilities BOOLEAN,  -- Sanitation facilities
    kitchen_facilities BOOLEAN,  -- Kitchen facilities
    communication_facilities BOOLEAN,  -- Communication facilities
    
    -- Shelter status
    operational_status VARCHAR(20) DEFAULT 'OPERATIONAL',  -- Status: OPERATIONAL, UNDER_MAINTENANCE, CLOSED, DAMAGED
    readiness_level VARCHAR(20),  -- Readiness: READY, PARTIALLY_READY, NOT_READY
    last_inspection_date DATE,  -- Last inspection date
    inspection_status VARCHAR(20),  -- Inspection status: PASSED, FAILED, PENDING
    
    -- Assignment information
    assigned_habitations TEXT[],  -- Array of assigned habitation IDs
    assigned_population INTEGER,  -- Total assigned population
    assignment_timestamp TIMESTAMP WITH TIME ZONE,  -- Last assignment timestamp
    
    -- Metadata
    data_source VARCHAR(50),  -- Data source
    last_capacity_update TIMESTAMP WITH TIME ZONE,  -- Last capacity update
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create spatial index on geometry
CREATE INDEX idx_shelters_geometry ON shelters USING GIST (geometry);
CREATE INDEX idx_shelters_boundary ON shelters USING GIST (boundary_geometry);

-- Create indexes on frequently queried columns
CREATE INDEX idx_shelters_shelter_id ON shelters (shelter_id);
CREATE INDEX idx_shelters_state_district ON shelters (state_code, district_code);
CREATE INDEX idx_shelters_type ON shelters (shelter_type);
CREATE INDEX idx_shelters_status ON shelters (operational_status);
CREATE INDEX idx_shelters_safety_check ON shelters (safety_check_passed);
CREATE INDEX idx_shelters_effective_capacity ON shelters (effective_capacity);
CREATE INDEX idx_shelters_intersects_red_zone ON shelters (intersects_red_zone);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_shelters_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_shelters_updated_at
    BEFORE UPDATE ON shelters
    FOR EACH ROW
    EXECUTE FUNCTION update_shelters_updated_at();

-- Add comments
COMMENT ON TABLE shelters IS 'Relocation shelters with capacity and safety assessment';
COMMENT ON COLUMN shelters.geometry IS 'Shelter location point in WGS84 (EPSG:4326)';
COMMENT ON COLUMN shelters.effective_capacity IS 'Effective capacity based on resource bottlenecks (min of beds, water, food, medical)';
COMMENT ON COLUMN shelters.intersects_red_zone IS 'Whether the shelter location intersects with any active red zone';
