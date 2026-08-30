-- Red Zones Schema
-- This schema defines dynamic red zone polygons for unsafe areas

-- Red zones table
CREATE TABLE red_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id VARCHAR(50) UNIQUE NOT NULL,  -- Unique identifier for the red zone
    
    -- Spatial data
    geometry GEOMETRY(POLYGON, 4326) NOT NULL,  -- Red zone boundary (WGS84)
    center_lat DECIMAL(10, 7) NOT NULL,  -- Center latitude
    center_lon DECIMAL(10, 7) NOT NULL,  -- Center longitude
    area_sq_km DECIMAL(10, 3),  -- Area in square kilometers
    
    -- Classification
    hazard_type VARCHAR(50) NOT NULL,  -- Primary hazard type: LANDSLIDE, FLOOD, COASTAL_EROSION, CLOUDBURST
    severity_level VARCHAR(20) NOT NULL,  -- Severity: LOW, MEDIUM, HIGH, CRITICAL
    risk_threshold_used DECIMAL(5, 2),  -- Risk threshold used for classification
    
    -- Spatial analysis results
    grid_cells_count INTEGER,  -- Number of grid cells in this red zone
    average_risk_score DECIMAL(5, 2),  -- Average risk score of grid cells
    max_risk_score DECIMAL(5, 2),  -- Maximum risk score in the zone
    
    -- Geographic context
    state_code VARCHAR(10),  -- State code
    district_code VARCHAR(10),  -- District code
    tehsil_code VARCHAR(10),  -- Tehsil code
    village_names TEXT[],  -- Array of village names in the zone
    
    -- Population at risk
    estimated_population INTEGER,  -- Estimated population in the zone
    household_count INTEGER,  -- Number of households
    
    -- Affected infrastructure
    affected_road_km DECIMAL(10, 2),  -- Length of affected roads in km
    affected_bridges INTEGER,  -- Number of affected bridges
    affected_buildings INTEGER,  -- Number of affected buildings
    critical_facilities TEXT[],  -- Array of critical facility names
    
    -- Time context
    detection_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,  -- When the red zone was detected
    last_validated TIMESTAMP WITH TIME ZONE,  -- Last validation timestamp
    predicted_expiry TIMESTAMP WITH TIME ZONE,  -- Predicted expiry time
    
    -- Status
    status VARCHAR(20) DEFAULT 'ACTIVE',  -- Status: ACTIVE, EXPIRED, REVOKED
    validation_status VARCHAR(20) DEFAULT 'PENDING',  -- Validation status: PENDING, VALIDATED, REJECTED
    validated_by VARCHAR(100),  -- User who validated
    
    -- Metadata
    detection_method VARCHAR(50),  -- Method used for detection: AI_PREDICTION, MANUAL, SATELLITE
    confidence_score DECIMAL(5, 2),  -- Confidence in the red zone detection (0-100)
    data_sources TEXT[],  -- Array of data sources used
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create spatial index on geometry
CREATE INDEX idx_red_zones_geometry ON red_zones USING GIST (geometry);

-- Create indexes on frequently queried columns
CREATE INDEX idx_red_zones_zone_id ON red_zones (zone_id);
CREATE INDEX idx_red_zones_hazard_type ON red_zones (hazard_type);
CREATE INDEX idx_red_zones_severity ON red_zones (severity_level);
CREATE INDEX idx_red_zones_status ON red_zones (status);
CREATE INDEX idx_red_zones_state_district ON red_zones (state_code, district_code);
CREATE INDEX idx_red_zones_detection_time ON red_zones (detection_timestamp);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_red_zones_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_red_zones_updated_at
    BEFORE UPDATE ON red_zones
    FOR EACH ROW
    EXECUTE FUNCTION update_red_zones_updated_at();

-- Add comments
COMMENT ON TABLE red_zones IS 'Dynamic red zone polygons representing areas unsuitable for permanent habitation';
COMMENT ON COLUMN red_zones.geometry IS 'Red zone boundary in WGS84 (EPSG:4326)';
COMMENT ON COLUMN red_zones.hazard_type IS 'Primary hazard type: LANDSLIDE, FLOOD, COASTAL_EROSION, CLOUDBURST';
COMMENT ON COLUMN red_zones.status IS 'Current status: ACTIVE, EXPIRED, REVOKED';
