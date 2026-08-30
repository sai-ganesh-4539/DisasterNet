# Database Schema Documentation

Complete database schema documentation for the Disaster Management Platform.

## Database Technology

- **Database**: PostgreSQL 14+
- **Spatial Extension**: PostGIS 3.3+
- **Design**: Cluster-ready with partitioning support

## Schema Overview

The database consists of 9 main schema files:

1. `01_spatial_extensions.sql` - Spatial extensions setup
2. `02_hazard_grids.sql` - Hazard grid cells
3. `03_red_zones.sql` - Red zone polygons
4. `04_habitations.sql` - Vulnerable habitations
5. `05_shelters.sql` - Relocation shelters
6. `06_census_data.sql` - Census demographic data
7. `07_environmental_data.sql` - Environmental data
8. `08_users_roles.sql` - Users, roles, and authentication
9. `09_audit_log.sql` - System audit logging

## Table Details

### hazard_grids

Spatial grid cells for hazard analysis with environmental factors and risk predictions.

**Columns:**
- `id` (UUID, PK): Unique identifier
- `grid_id` (VARCHAR, UNIQUE): Grid cell identifier
- `geometry` (GEOMETRY, POLYGON): Grid cell boundary (WGS84)
- `resolution_meters` (INTEGER): Grid resolution in meters
- `center_lat` (DECIMAL): Center latitude
- `center_lon` (DECIMAL): Center longitude
- `state_code` (VARCHAR): State code
- `district_code` (VARCHAR): District code
- `elevation` (DECIMAL): Elevation in meters
- `slope_percentage` (DECIMAL): Slope in percentage
- `lithology` (VARCHAR): Lithology type
- `soil_type` (VARCHAR): Soil type
- `vegetation_index` (DECIMAL): NDVI or similar index
- `precipitation_24h_mm` (DECIMAL): 24-hour precipitation
- `precipitation_72h_mm` (DECIMAL): 72-hour precipitation
- `soil_moisture_index` (DECIMAL): Soil moisture index
- `landslide_risk_score` (DECIMAL): Landslide risk score (0-100)
- `flood_risk_score` (DECIMAL): Flood risk score (0-100)
- `overall_risk_score` (DECIMAL): Overall risk score (0-100)
- `is_red_zone` (BOOLEAN): Whether in red zone
- `red_zone_id` (UUID): Reference to red zone
- `risk_level` (VARCHAR): Risk level (LOW, MEDIUM, HIGH, CRITICAL)
- `last_prediction_timestamp` (TIMESTAMP): Last ML prediction
- `last_data_update` (TIMESTAMP): Last data update
- `created_at` (TIMESTAMP): Creation timestamp
- `updated_at` (TIMESTAMP): Update timestamp

**Indexes:**
- Spatial index on `geometry`
- Indexes on `grid_id`, `state_code`, `district_code`, `is_red_zone`, `risk_level`, `overall_risk_score`

### red_zones

Dynamic red zone polygons representing areas unsuitable for permanent habitation.

**Columns:**
- `id` (UUID, PK): Unique identifier
- `zone_id` (VARCHAR, UNIQUE): Red zone identifier
- `geometry` (GEOMETRY, POLYGON): Red zone boundary (WGS84)
- `center_lat` (DECIMAL): Center latitude
- `center_lon` (DECIMAL): Center longitude
- `area_sq_km` (DECIMAL): Area in square kilometers
- `hazard_type` (VARCHAR): Primary hazard type
- `severity_level` (VARCHAR): Severity (LOW, MEDIUM, HIGH, CRITICAL)
- `risk_threshold_used` (DECIMAL): Risk threshold used
- `grid_cells_count` (INTEGER): Number of grid cells
- `average_risk_score` (DECIMAL): Average risk score
- `max_risk_score` (DECIMAL): Maximum risk score
- `state_code` (VARCHAR): State code
- `district_code` (VARCHAR): District code
- `estimated_population` (INTEGER): Estimated population
- `household_count` (INTEGER): Number of households
- `status` (VARCHAR): Status (ACTIVE, EXPIRED, REVOKED)
- `validation_status` (VARCHAR): Validation status
- `detection_timestamp` (TIMESTAMP): Detection time
- `confidence_score` (DECIMAL): Confidence in detection (0-100)
- `created_at` (TIMESTAMP): Creation timestamp
- `updated_at` (TIMESTAMP): Update timestamp

**Indexes:**
- Spatial index on `geometry`
- Indexes on `zone_id`, `hazard_type`, `severity_level`, `status`, `state_code`, `district_code`, `detection_timestamp`

### habitations

Vulnerable habitations requiring risk assessment and potential relocation.

**Columns:**
- `id` (UUID, PK): Unique identifier
- `habitation_id` (VARCHAR, UNIQUE): Habitation identifier
- `geometry` (GEOMETRY, POINT): Habitation center point (WGS84)
- `boundary_geometry` (GEOMETRY, POLYGON): Habitation boundary
- `latitude` (DECIMAL): Latitude
- `longitude` (DECIMAL): Longitude
- `elevation` (DECIMAL): Elevation in meters
- `state_code` (VARCHAR): State code
- `state_name` (VARCHAR): State name
- `district_code` (VARCHAR): District code
- `district_name` (VARCHAR): District name
- `village_name` (VARCHAR): Village name
- `total_population` (INTEGER): Total population
- `household_count` (INTEGER): Number of households
- `male_population` (INTEGER): Male population
- `female_population` (INTEGER): Female population
- `children_0_6` (INTEGER): Children aged 0-6
- `elderly_population` (INTEGER): Elderly population (60+)
- `disabled_population` (INTEGER): Disabled population
- `population_density_per_sqkm` (DECIMAL): Population density
- `elderly_percentage` (DECIMAL): Percentage of elderly
- `child_percentage` (DECIMAL): Percentage of children
- `disability_percentage` (DECIMAL): Percentage of disabled
- `economic_status` (VARCHAR): Economic status (BPL, APL, MIXED)
- `vulnerability_score` (DECIMAL): Vulnerability score (0-100)
- `road_connectivity` (VARCHAR): Road connectivity type
- `road_distance_km` (DECIMAL): Distance to main road
- `nearest_emergency_km` (DECIMAL): Distance to emergency services
- `communication_availability` (VARCHAR): Communication availability
- `evacuation_route_status` (VARCHAR): Evacuation route status
- `evacuation_time_hours` (DECIMAL): Evacuation time in hours
- `current_red_zone_id` (UUID): Reference to red zone
- `red_zone_proximity_km` (DECIMAL): Distance to red zone
- `hazard_history` (TEXT[]): Past hazard events
- `disaster_frequency_score` (DECIMAL): Disaster frequency score
- `priority_score` (DECIMAL): Priority score (0-100)
- `priority_category` (VARCHAR): Priority category
- `relocation_status` (VARCHAR): Relocation status
- `target_shelter_id` (UUID): Target shelter reference
- `last_assessment_timestamp` (TIMESTAMP): Last assessment
- `created_at` (TIMESTAMP): Creation timestamp
- `updated_at` (TIMESTAMP): Update timestamp

**Indexes:**
- Spatial indexes on `geometry` and `boundary_geometry`
- Indexes on `habitation_id`, `state_code`, `district_code`, `priority_category`, `relocation_status`, `priority_score`, `red_zone_proximity_km`
- Foreign key to `red_zones(id)`

### shelters

Relocation shelters with capacity and safety assessment.

**Columns:**
- `id` (UUID, PK): Unique identifier
- `shelter_id` (VARCHAR, UNIQUE): Shelter identifier
- `geometry` (GEOMETRY, POINT): Shelter location point (WGS84)
- `boundary_geometry` (GEOMETRY, POLYGON): Shelter boundary
- `latitude` (DECIMAL): Latitude
- `longitude` (DECIMAL): Longitude
- `elevation` (DECIMAL): Elevation in meters
- `area_sq_meters` (DECIMAL): Area in square meters
- `shelter_type` (VARCHAR): Shelter type
- `shelter_name` (VARCHAR): Shelter name
- `shelter_category` (VARCHAR): Shelter category
- `ownership` (VARCHAR): Ownership type
- `state_code` (VARCHAR): State code
- `district_name` (VARCHAR): District name
- `total_capacity` (INTEGER): Total capacity
- `current_occupancy` (INTEGER): Current occupancy
- `available_capacity` (INTEGER): Available capacity
- `physical_beds` (INTEGER): Number of physical beds
- `water_sufficiency_days` (DECIMAL): Days of water sufficiency
- `food_ration_storage_days` (DECIMAL): Days of food storage
- `medical_facility_depth` (VARCHAR): Medical facility depth
- `effective_capacity` (INTEGER): Effective capacity
- `capacity_constraint` (VARCHAR): Primary constraint
- `safety_check_passed` (BOOLEAN): Safety check result
- `intersects_red_zone` (BOOLEAN): Intersects with red zone
- `nearest_red_zone_distance_km` (DECIMAL): Distance to red zone
- `hazard_exposure_score` (DECIMAL): Hazard exposure score
- `safety_score` (DECIMAL): Safety score (0-100)
- `road_accessibility` (VARCHAR): Road accessibility
- `electricity` (BOOLEAN): Electricity availability
- `water_supply` (BOOLEAN): Water supply availability
- `sanitation_facilities` (BOOLEAN): Sanitation facilities
- `operational_status` (VARCHAR): Operational status
- `readiness_level` (VARCHAR): Readiness level
- `assigned_habitations` (TEXT[]): Assigned habitation IDs
- `assigned_population` (INTEGER): Assigned population
- `last_capacity_update` (TIMESTAMP): Last capacity update
- `created_at` (TIMESTAMP): Creation timestamp
- `updated_at` (TIMESTAMP): Update timestamp

**Indexes:**
- Spatial indexes on `geometry` and `boundary_geometry`
- Indexes on `shelter_id`, `state_code`, `district_code`, `shelter_type`, `operational_status`, `safety_check_passed`, `effective_capacity`, `intersects_red_zone`

### census_data

Demographic and socio-economic census data for habitations.

**Columns:**
- `id` (UUID, PK): Unique identifier
- `census_id` (VARCHAR, UNIQUE): Census identifier
- `state_code` (VARCHAR): State code
- `state_name` (VARCHAR): State name
- `district_code` (VARCHAR): District code
- `district_name` (VARCHAR): District name
- `tehsil_code` (VARCHAR): Tehsil code
- `tehsil_name` (VARCHAR): Tehsil name
- `village_code` (VARCHAR): Village census code
- `village_name` (VARCHAR): Village name
- `geometry` (GEOMETRY, POINT): Location point (WGS84)
- `total_population` (INTEGER): Total population
- `male_population` (INTEGER): Male population
- `female_population` (INTEGER): Female population
- `population_0_6` (INTEGER): Population aged 0-6
- `population_7_14` (INTEGER): Population aged 7-14
- `population_15_59` (INTEGER): Population aged 15-59
- `population_60_plus` (INTEGER): Population aged 60+
- `sc_population` (INTEGER): Scheduled Caste population
- `st_population` (INTEGER): Scheduled Tribe population
- `total_households` (INTEGER): Total households
- `occupied_households` (INTEGER): Occupied households
- `vacant_households` (INTEGER): Vacant households
- `pucca_households` (INTEGER): Pucca households
- `literacy_rate` (DECIMAL): Overall literacy rate
- `male_literacy_rate` (DECIMAL): Male literacy rate
- `female_literacy_rate` (DECIMAL): Female literacy rate
- `has_school` (BOOLEAN): Has school facility
- `has_health_center` (BOOLEAN): Has health center
- `census_year` (INTEGER): Census year
- `import_timestamp` (TIMESTAMP): Data import timestamp
- `created_at` (TIMESTAMP): Creation timestamp
- `updated_at` (TIMESTAMP): Update timestamp

**Indexes:**
- Spatial index on `geometry`
- Indexes on `census_id`, `state_code`, `district_code`, `village_code`, `census_year`

### environmental_data

Environmental and terrain data from ISRO Bhuvan, IMD, and other sources.

**Columns:**
- `id` (UUID, PK): Unique identifier
- `data_id` (VARCHAR, UNIQUE): Data identifier
- `geometry` (GEOMETRY, POINT): Location point (WGS84)
- `latitude` (DECIMAL): Latitude
- `longitude` (DECIMAL): Longitude
- `grid_id` (VARCHAR): Reference to hazard grid
- `state_code` (VARCHAR): State code
- `district_code` (VARCHAR): District code
- `elevation` (DECIMAL): Elevation in meters
- `slope_percentage` (DECIMAL): Slope in percentage
- `lithology` (VARCHAR): Lithology type
- `soil_type` (VARCHAR): Soil type
- `land_use` (VARCHAR): Land use classification
- `vegetation_index` (DECIMAL): Vegetation index
- `precipitation_current_mm` (DECIMAL): Current precipitation
- `precipitation_24h_mm` (DECIMAL): 24-hour precipitation
- `precipitation_72h_mm` (DECIMAL): 72-hour precipitation
- `temperature_celsius` (DECIMAL): Temperature in Celsius
- `humidity_percentage` (DECIMAL): Humidity percentage
- `soil_moisture_index` (DECIMAL): Soil moisture index
- `data_type` (VARCHAR): Data type (TERRAIN, WEATHER, etc.)
- `data_source` (VARCHAR): Data source (ISRO_BHUVAN, IMD, etc.)
- `observation_timestamp` (TIMESTAMP): Observation time
- `data_quality` (VARCHAR): Data quality (VALID, SUSPECT, INVALID)
- `confidence_score` (DECIMAL): Confidence score (0-100)
- `created_at` (TIMESTAMP): Creation timestamp
- `updated_at` (TIMESTAMP): Update timestamp

**Indexes:**
- Spatial index on `geometry`
- Indexes on `data_id`, `grid_id`, `state_code`, `district_code`, `data_type`, `data_source`, `observation_timestamp`, `data_quality`

### users

User accounts with authentication and role assignments.

**Columns:**
- `id` (UUID, PK): Unique identifier
- `user_id` (VARCHAR, UNIQUE): User identifier
- `username` (VARCHAR, UNIQUE): Username
- `email` (VARCHAR, UNIQUE): Email address
- `password_hash` (VARCHAR): Bcrypt password hash
- `full_name` (VARCHAR): Full name
- `phone_number` (VARCHAR): Phone number
- `designation` (VARCHAR): Designation
- `department` (VARCHAR): Department
- `organization` (VARCHAR): Organization
- `state_code` (VARCHAR): Assigned state code
- `district_code` (VARCHAR): Assigned district code
- `role_id` (UUID): Assigned role
- `is_active` (BOOLEAN): Account status
- `is_verified` (BOOLEAN): Email verification status
- `last_login` (TIMESTAMP): Last login timestamp
- `failed_login_attempts` (INTEGER): Failed login attempts
- `api_key` (VARCHAR, UNIQUE): API key
- `api_key_expires` (TIMESTAMP): API key expiration
- `created_at` (TIMESTAMP): Creation timestamp
- `updated_at` (TIMESTAMP): Update timestamp

**Indexes:**
- Indexes on `user_id`, `username`, `email`, `role_id`, `state_code`, `district_code`, `is_active`
- Foreign key to `roles(id)`

### roles

User roles with permissions for RBAC.

**Columns:**
- `id` (UUID, PK): Unique identifier
- `role_name` (VARCHAR, UNIQUE): Role name
- `display_name` (VARCHAR): Display name
- `description` (TEXT): Role description
- `parent_role_id` (UUID): Parent role for hierarchy
- `level` (INTEGER): Role level in hierarchy
- `permissions` (TEXT[]): Array of permission strings
- `can_read` (BOOLEAN): Can read data
- `can_write` (BOOLEAN): Can write data
- `can_delete` (BOOLEAN): Can delete data
- `can_admin` (BOOLEAN): Can perform admin operations
- `is_system_role` (BOOLEAN): Whether this is a system role
- `created_at` (TIMESTAMP): Creation timestamp
- `updated_at` (TIMESTAMP): Update timestamp

**Indexes:**
- Index on `role_name`, `parent_role_id`

### audit_log

Audit trail of all system actions for compliance and security.

**Columns:**
- `id` (UUID, PK): Unique identifier
- `log_id` (VARCHAR, UNIQUE): Log identifier
- `user_id` (UUID): User who performed the action
- `username` (VARCHAR): Username
- `role_name` (VARCHAR): Role at time of action
- `action_type` (VARCHAR): Action type (CREATE, READ, UPDATE, DELETE)
- `resource_type` (VARCHAR): Resource type
- `resource_id` (VARCHAR): Resource ID affected
- `action_description` (TEXT): Description of the action
- `ip_address` (VARCHAR): IP address
- `request_method` (VARCHAR): HTTP method
- `request_path` (TEXT): Request path
- `old_values` (JSONB): Old values (for updates)
- `new_values` (JSONB): New values
- `action_status` (VARCHAR): Status (SUCCESS, FAILURE, PARTIAL)
- `error_message` (TEXT): Error message if failed
- `action_timestamp` (TIMESTAMP): Action timestamp
- `processing_time_ms` (INTEGER): Processing time
- `session_id` (VARCHAR): Session ID
- `correlation_id` (VARCHAR): Correlation ID
- `additional_data` (JSONB): Additional context data

**Indexes:**
- Indexes on `user_id`, `action_type`, `resource_type`, `resource_id`, `action_timestamp`, `action_status`

## Spatial Indexes

All geometry columns have GIST spatial indexes for efficient spatial queries:

- `hazard_grids.geometry`
- `red_zones.geometry`
- `habitations.geometry`, `habitations.boundary_geometry`
- `shelters.geometry`, `shelters.boundary_geometry`
- `census_data.geometry`
- `environmental_data.geometry`

## Partitioning Strategy

For national scale deployment, consider partitioning large tables by:

- **Geographic partitioning**: By state_code or district_code
- **Time-based partitioning**: By observation_timestamp or created_at
- **Range partitioning**: By risk_score ranges

## Backup Strategy

Recommended backup strategy:

1. **Daily full backups** of critical tables
2. **Hourly transaction log backups** for point-in-time recovery
3. **Weekly full database dumps** for disaster recovery
4. **Incremental backups** for large tables

## Performance Optimization

### Query Optimization

- Use spatial indexes for all geometry queries
- Create appropriate composite indexes for frequent query patterns
- Use EXPLAIN ANALYZE to optimize slow queries
- Consider materialized views for complex aggregations

### Connection Pooling

- Configure connection pool size based on expected load
- Set appropriate timeout values
- Monitor connection pool usage

### Monitoring

- Monitor slow query logs
- Track index usage statistics
- Monitor table bloat and vacuum requirements
- Track spatial query performance

## Data Retention

### Retention Policies

- **Environmental data**: 1 year for detailed data, 5 years for aggregated
- **Audit logs**: 7 years for compliance
- **Prediction logs**: 1 year for ML model improvement
- **Sync logs**: 6 months for operational monitoring

### Archival Strategy

- Archive old data to separate tables
- Compress archived data
- Implement data lifecycle management
- Maintain data accessibility for analysis