-- Hazard Grids Schema
-- This schema defines the spatial grid system for hazard analysis

-- Hazard grid cells table
CREATE TABLE hazard_grids (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    grid_id VARCHAR(50) UNIQUE NOT NULL,  -- Unique identifier for the grid cell
    geometry GEOMETRY(POLYGON, 4326) NOT NULL,  -- Grid cell boundary (WGS84)
    
    -- Grid metadata
    resolution_meters INTEGER NOT NULL,  -- Grid resolution in meters
    center_lat DECIMAL(10, 7) NOT NULL,  -- Center latitude
    center_lon DECIMAL(10, 7) NOT NULL,  -- Center longitude
    state_code VARCHAR(10),  -- State code
    district_code VARCHAR(10),  -- District code
    region_name VARCHAR(100),  -- Region name
    
    -- Environmental factors (static)
    elevation DECIMAL(10, 2),  -- Elevation in meters
    slope_percentage DECIMAL(7, 2),  -- Slope in percentage
    aspect DECIMAL(7, 2),  -- Aspect in degrees
    lithology VARCHAR(100),  -- Lithology type
    soil_type VARCHAR(100),  -- Soil type
    land_use VARCHAR(100),  -- Land use classification
    vegetation_index DECIMAL(5, 3),  -- NDVI or similar vegetation index
    
    -- Environmental factors (dynamic)
    current_precipitation_mm DECIMAL(7, 2),  -- Current precipitation in mm
    precipitation_24h_mm DECIMAL(7, 2),  -- 24-hour precipitation in mm
    precipitation_72h_mm DECIMAL(7, 2),  -- 72-hour precipitation in mm
    soil_moisture DECIMAL(5, 3),  -- Soil moisture index
    water_table_depth DECIMAL(7, 2),  -- Water table depth in meters
    
    -- Hazard predictions
    landslide_risk_score DECIMAL(5, 2),  -- Landslide risk score (0-100)
    flood_risk_score DECIMAL(5, 2),  -- Flood risk score (0-100)
    coastal_erosion_risk_score DECIMAL(5, 2),  -- Coastal erosion risk score (0-100)
    cloudburst_risk_score DECIMAL(5, 2),  -- Cloudburst risk score (0-100)
    overall_risk_score DECIMAL(5, 2),  -- Overall risk score (0-100)
    
    -- Risk classification
    is_red_zone BOOLEAN DEFAULT FALSE,  -- Whether this grid is in a red zone
    red_zone_id UUID,  -- Reference to red zone polygon if part of one
    risk_level VARCHAR(20),  -- Risk level: LOW, MEDIUM, HIGH, CRITICAL
    
    -- Metadata
    data_source VARCHAR(50),  -- Source of the data
    last_prediction_timestamp TIMESTAMP WITH TIME ZONE,  -- Last ML prediction time
    last_data_update TIMESTAMP WITH TIME ZONE,  -- Last data update time
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create spatial index on geometry
CREATE INDEX idx_hazard_grids_geometry ON hazard_grids USING GIST (geometry);

-- Create indexes on frequently queried columns
CREATE INDEX idx_hazard_grids_grid_id ON hazard_grids (grid_id);
CREATE INDEX idx_hazard_grids_state_district ON hazard_grids (state_code, district_code);
CREATE INDEX idx_hazard_grids_red_zone ON hazard_grids (is_red_zone);
CREATE INDEX idx_hazard_grids_risk_level ON hazard_grids (risk_level);
CREATE INDEX idx_hazard_grids_overall_risk ON hazard_grids (overall_risk_score);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_hazard_grids_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hazard_grids_updated_at
    BEFORE UPDATE ON hazard_grids
    FOR EACH ROW
    EXECUTE FUNCTION update_hazard_grids_updated_at();

-- Add comment
COMMENT ON TABLE hazard_grids IS 'Spatial grid cells for hazard analysis with environmental factors and risk predictions';
COMMENT ON COLUMN hazard_grids.geometry IS 'Grid cell boundary in WGS84 (EPSG:4326)';
COMMENT ON COLUMN hazard_grids.overall_risk_score IS 'Overall risk score (0-100) calculated by ML models';
