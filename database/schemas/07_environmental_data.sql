-- Environmental Data Schema
-- This schema stores environmental and terrain data from ISRO Bhuvan and other sources

-- Environmental data table
CREATE TABLE environmental_data (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    data_id VARCHAR(50) UNIQUE NOT NULL,  -- Unique identifier for data record
    
    -- Spatial reference
    geometry GEOMETRY(POINT, 4326) NOT NULL,  -- Location point (WGS84)
    latitude DECIMAL(10, 7) NOT NULL,  -- Latitude
    longitude DECIMAL(10, 7) NOT NULL,  -- Longitude
    
    -- Grid reference
    grid_id VARCHAR(50),  -- Reference to hazard grid
    state_code VARCHAR(10),  -- State code
    district_code VARCHAR(10),  -- District code
    
    -- Terrain data (static - from ISRO Bhuvan)
    elevation DECIMAL(10, 2),  -- Elevation in meters
    slope_percentage DECIMAL(7, 2),  -- Slope in percentage
    slope_aspect DECIMAL(7, 2),  -- Slope aspect in degrees
    curvature DECIMAL(7, 2),  -- Terrain curvature
    lithology VARCHAR(100),  -- Lithology type
    soil_type VARCHAR(100),  -- Soil type
    soil_depth DECIMAL(7, 2),  -- Soil depth in cm
    land_use VARCHAR(100),  -- Land use classification
    land_cover VARCHAR(100),  -- Land cover type
    vegetation_index DECIMAL(5, 3),  -- NDVI or similar index
    vegetation_density DECIMAL(5, 2),  -- Vegetation density percentage
    
    -- Hydrological data
    drainage_density DECIMAL(7, 4),  -- Drainage density
    distance_to_river_m DECIMAL(8, 2),  -- Distance to nearest river in meters
    distance_to_water_body_m DECIMAL(8, 2),  -- Distance to water body in meters
    water_table_depth DECIMAL(7, 2),  -- Water table depth in meters
    flood_plain BOOLEAN,  -- Whether in flood plain
    flood_plain_zone VARCHAR(50),  -- Flood plain zone classification
    
    -- Seismic data
    seismic_zone VARCHAR(20),  -- Seismic zone: II, III, IV, V
    peak_ground_acceleration DECIMAL(5, 3),  -- Peak ground acceleration
    
    -- Weather data (dynamic - from IMD)
    precipitation_current_mm DECIMAL(7, 2),  -- Current precipitation in mm
    precipitation_24h_mm DECIMAL(7, 2),  -- 24-hour precipitation in mm
    precipitation_48h_mm DECIMAL(7, 2),  -- 48-hour precipitation in mm
    precipitation_72h_mm DECIMAL(7, 2),  -- 72-hour precipitation in mm
    precipitation_weekly_mm DECIMAL(8, 2),  -- Weekly precipitation in mm
    precipitation_monthly_mm DECIMAL(8, 2),  -- Monthly precipitation in mm
    
    temperature_celsius DECIMAL(5, 2),  -- Current temperature in Celsius
    humidity_percentage DECIMAL(5, 2),  -- Humidity percentage
    wind_speed_kmh DECIMAL(5, 2),  -- Wind speed in km/h
    wind_direction_degrees DECIMAL(5, 2),  -- Wind direction in degrees
    
    -- Soil moisture data
    soil_moisture_index DECIMAL(5, 3),  -- Soil moisture index (0-1)
    soil_saturation_percentage DECIMAL(5, 2),  -- Soil saturation percentage
    
    -- Coastal data (if applicable)
    distance_to_coast_m DECIMAL(8, 2),  -- Distance to coast in meters
    coastal_erosion_rate DECIMAL(7, 3),  -- Coastal erosion rate in m/year
    tidal_range DECIMAL(5, 2),  -- Tidal range in meters
    storm_surge_height DECIMAL(5, 2),  -- Storm surge height in meters
    
    -- Data provenance
    data_type VARCHAR(50) NOT NULL,  -- Data type: TERRAIN, WEATHER, HYDROLOGICAL, SEISMIC, COASTAL
    data_source VARCHAR(50) NOT NULL,  -- Data source: ISRO_BHUVAN, IMD, MANUAL, OTHER
    source_api VARCHAR(100),  -- Source API endpoint
    sensor_id VARCHAR(50),  -- Sensor or station ID
    resolution_meters INTEGER,  -- Data resolution in meters
    
    -- Temporal data
    observation_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,  -- Observation time
    forecast_timestamp TIMESTAMP WITH TIME ZONE,  -- Forecast time (if applicable)
    data_frequency VARCHAR(20),  -- Data frequency: REALTIME, HOURLY, DAILY, WEEKLY
    
    -- Quality flags
    data_quality VARCHAR(20) DEFAULT 'VALID',  -- Data quality: VALID, SUSPECT, INVALID, MISSING
    confidence_score DECIMAL(5, 2),  -- Confidence in data accuracy (0-100)
    quality_flags TEXT[],  -- Array of quality flags
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create spatial index on geometry
CREATE INDEX idx_environmental_data_geometry ON environmental_data USING GIST (geometry);

-- Create indexes on frequently queried columns
CREATE INDEX idx_environmental_data_data_id ON environmental_data (data_id);
CREATE INDEX idx_environmental_data_grid_id ON environmental_data (grid_id);
CREATE INDEX idx_environmental_data_state_district ON environmental_data (state_code, district_code);
CREATE INDEX idx_environmental_data_type ON environmental_data (data_type);
CREATE INDEX idx_environmental_data_source ON environmental_data (data_source);
CREATE INDEX idx_environmental_data_observation_time ON environmental_data (observation_timestamp);
CREATE INDEX idx_environmental_data_quality ON environmental_data (data_quality);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_environmental_data_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_environmental_data_updated_at
    BEFORE UPDATE ON environmental_data
    FOR EACH ROW
    EXECUTE FUNCTION update_environmental_data_updated_at();

-- Add comments
COMMENT ON TABLE environmental_data IS 'Environmental and terrain data from ISRO Bhuvan, IMD, and other sources';
COMMENT ON COLUMN environmental_data.geometry IS 'Location point in WGS84 (EPSG:4326)';
COMMENT ON COLUMN environmental_data.data_type IS 'Type of environmental data: TERRAIN, WEATHER, HYDROLOGICAL, SEISMIC, COASTAL';
COMMENT ON COLUMN environmental_data.data_source IS 'Source of data: ISRO_BHUVAN, IMD, MANUAL, OTHER';
