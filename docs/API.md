# API Documentation

Complete API reference for the Disaster Management Platform.

## Base URL

```
http://localhost:8000/api/v1
```

## Authentication

All endpoints require authentication using JWT tokens or API keys.

### JWT Authentication

Include the token in the Authorization header:

```
Authorization: Bearer <your-jwt-token>
```

### API Key Authentication

Include the API key in the Authorization header:

```
Authorization: ApiKey <your-api-key>
```

## Response Format

All responses follow this structure:

```json
{
  "data": { ... },
  "error": null,
  "timestamp": "2024-01-15T10:00:00Z"
}
```

Error responses:

```json
{
  "detail": "Error message",
  "error": "error_code"
}
```

## Endpoints

### Health Check

Check API health status.

**Endpoint:** `GET /health`

**Authentication:** None

**Response:**
```json
{
  "status": "healthy",
  "service": "Disaster Management Platform API",
  "version": "1.0.0"
}
```

### Hazards

#### Predict Hazard Risk

Predict hazard risk for a specific location.

**Endpoint:** `POST /hazards/predict`

**Authentication:** Required

**Request Body:**
```json
{
  "latitude": 28.5,
  "longitude": 77.2,
  "precipitation_24h_mm": 45.0,
  "precipitation_72h_mm": 120.0,
  "slope_percentage": 25.0,
  "elevation": 1500.0,
  "lithology": "GRANITE",
  "soil_moisture_index": 0.7,
  "vegetation_index": 0.6,
  "hazard_type": "landslide",
  "region": null
}
```

**Response:**
```json
{
  "risk_score": 75.5,
  "risk_probability": 0.755,
  "risk_threshold": 75,
  "is_red_zone": true,
  "risk_level": "HIGH",
  "hazard_type": "LANDSLIDE",
  "prediction_timestamp": "2024-01-15T10:00:00Z",
  "model_version": "1.0.0",
  "features_used": ["precipitation_24h_mm", "slope_percentage", ...]
}
```

#### Batch Hazard Prediction

Predict hazard risks for multiple grid cells.

**Endpoint:** `POST /hazards/predict-batch`

**Authentication:** Required

**Request Body:**
```json
{
  "grid_cells": [
    {
      "latitude": 28.5,
      "longitude": 77.2,
      "precipitation_24h_mm": 45.0,
      ...
    }
  ],
  "generate_red_zones": true,
  "min_cluster_size": 5
}
```

**Response:**
```json
{
  "total_cells": 10,
  "predictions": [...],
  "high_risk_count": 3,
  "red_zones": [...],
  "red_zone_count": 1
}
```

#### Get Model Information

Get information about the hazard prediction model.

**Endpoint:** `GET /hazards/model-info`

**Authentication:** Required

**Response:**
```json
{
  "model_info": {
    "model_name": "hazard_predictor",
    "model_version": "1.0.0",
    "is_loaded": true,
    "last_loaded": "2024-01-15T09:00:00Z"
  },
  "feature_importance": {
    "precipitation_24h_mm": 30.5,
    "slope_percentage": 25.2,
    ...
  }
}
```

### Red Zones

#### Get Red Zones

Query red zones with optional filters.

**Endpoint:** `GET /red-zones/`

**Authentication:** Required

**Query Parameters:**
- `state_code` (optional): Filter by state code
- `district_code` (optional): Filter by district code
- `hazard_type` (optional): Filter by hazard type
- `status` (optional): Filter by status (default: ACTIVE)

**Response:**
```json
{
  "count": 2,
  "red_zones": [...],
  "geojson": {
    "type": "FeatureCollection",
    "features": [...]
  }
}
```

#### Get Specific Red Zone

Get a specific red zone by ID.

**Endpoint:** `GET /red-zones/{zone_id}`

**Authentication:** Required

**Response:**
```json
{
  "zone_id": "RZ_001",
  "hazard_type": "LANDSLIDE",
  "severity_level": "HIGH",
  "geometry": "POLYGON(...)",
  "center_lat": 28.55,
  "center_lon": 77.25,
  "area_sq_km": 12.5,
  "status": "ACTIVE",
  ...
}
```

#### Create Red Zone

Create a new red zone.

**Endpoint:** `POST /red-zones/`

**Authentication:** Required (WRITE permission)

**Request Body:**
```json
{
  "zone_id": "RZ_003",
  "hazard_type": "LANDSLIDE",
  "severity_level": "HIGH",
  "geometry": "POLYGON(...)",
  "confidence_score": 85.0,
  "detection_method": "AI_PREDICTION"
}
```

**Response:**
```json
{
  "success": true,
  "zone_id": "RZ_003",
  "message": "Red zone created successfully",
  "created_by": "username",
  "created_at": "2024-01-15T12:00:00Z"
}
```

#### Update Red Zone

Update an existing red zone.

**Endpoint:** `PUT /red-zones/{zone_id}`

**Authentication:** Required (WRITE permission)

**Request Body:**
```json
{
  "severity_level": "CRITICAL",
  "validation_status": "VALIDATED",
  "status": "ACTIVE"
}
```

#### Delete Red Zone

Delete a red zone.

**Endpoint:** `DELETE /red-zones/{zone_id}`

**Authentication:** Required (DELETE permission)

### Habitations

#### Get Habitations

Query habitations with optional filters.

**Endpoint:** `GET /habitations/`

**Authentication:** Required

**Query Parameters:**
- `state_code` (optional): Filter by state code
- `district_code` (optional): Filter by district code
- `priority_category` (optional): Filter by priority category
- `limit` (optional): Maximum results (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "count": 100,
  "limit": 50,
  "offset": 0,
  "habitations": [...]
}
```

#### Get Habitation Risk

Get risk assessment for a specific habitation.

**Endpoint:** `GET /habitations/{habitation_id}/risk`

**Authentication:** Required

**Response:**
```json
{
  "habitation_id": "HAB_001",
  "vulnerability_score": 72.5,
  "hazard_exposure_score": 85.0,
  "overall_risk_score": 75.0,
  "risk_level": "HIGH",
  "red_zone_proximity_km": 0.5,
  ...
}
```

#### Assess Priority

Assess relocation priority for a habitation.

**Endpoint:** `POST /habitations/assess`

**Authentication:** Required

**Request Body:**
```json
{
  "habitation_id": "HAB_001",
  "latitude": 18.5,
  "longitude": 73.9,
  "total_population": 500,
  "elderly_percentage": 8.0,
  "child_percentage": 12.0,
  "disability_percentage": 3.0,
  "population_density_per_sqkm": 100.0,
  "economic_status": "MIXED",
  "road_connectivity": "PAVED",
  "road_distance_km": 5.0,
  "nearest_emergency_km": 15.0,
  "communication_availability": "MOBILE",
  "evacuation_route_status": "CLEAR",
  "evacuation_time_hours": 3.0,
  "red_zone_proximity_km": 2.5,
  "hazard_history": [],
  "disaster_frequency_score": 20.0
}
```

**Response:**
```json
{
  "priority_score": 65.0,
  "priority_category": "SHORT_TERM",
  "expert_category": "SHORT_TERM",
  "ml_category": "SHORT_TERM",
  "time_horizon_details": {
    "name": "Short-Term",
    "min_weeks": 1,
    "max_weeks": 4,
    "description": "High priority - pre-stage assets"
  },
  "calculation_breakdown": { ... },
  "prediction_timestamp": "2024-01-15T10:00:00Z"
}
```

#### Batch Priority Assessment

Assess priorities for multiple habitations.

**Endpoint:** `POST /habitations/assess-batch`

**Authentication:** Required

**Response:**
```json
{
  "total_habitations": 10,
  "assessments": [...],
  "summary": {
    "immediate_count": 2,
    "short_term_count": 5,
    "medium_term_count": 3
  },
  "prioritized_list": [...]
}
```

### Shelters

#### Get Shelters

Query shelters with optional filters.

**Endpoint:** `GET /shelters/`

**Authentication:** Required

**Query Parameters:**
- `state_code` (optional): Filter by state code
- `district_code` (optional): Filter by district code
- `shelter_type` (optional): Filter by shelter type
- `status` (optional): Filter by status (default: OPERATIONAL)
- `limit` (optional): Maximum results (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "count": 50,
  "limit": 50,
  "offset": 0,
  "shelters": [...]
}
```

#### Get Shelter Capacity

Get shelter capacity information.

**Endpoint:** `GET /shelters/capacity`

**Authentication:** Required

**Query Parameters:**
- `shelter_id` (optional): Specific shelter ID
- `state_code` (optional): Filter by state code
- `district_code` (optional): Filter by district code

**Response:**
```json
{
  "shelter_id": "SHELTER_001",
  "total_capacity": 500,
  "current_occupancy": 150,
  "available_capacity": 350,
  "effective_capacity": 350,
  "capacity_constraint": "NONE",
  "utilization_percentage": 30.0,
  "capacity_status": "LOW",
  "resource_breakdown": { ... }
}
```

#### Evaluate Shelter

Evaluate shelter capacity and suitability.

**Endpoint:** `POST /shelters/evaluate`

**Authentication:** Required

**Request Body:**
```json
{
  "shelter_id": "SHELTER_001",
  "shelter_name": "Community Hall 1",
  "total_capacity": 500,
  "current_occupancy": 150,
  "physical_beds": 500,
  "water_sufficiency_days": 14.0,
  "food_ration_storage_days": 21.0,
  "medical_facility_depth": "FULL",
  "geometry": "POINT(73.85 18.52)",
  "road_accessibility": "GOOD",
  "nearest_red_zone_distance_km": 10.0,
  "electricity": true,
  "water_supply": true,
  "sanitation_facilities": true
}
```

**Response:**
```json
{
  "total_capacity": 500,
  "effective_capacity": 350,
  "available_capacity": 200,
  "capacity_constraint": "WATER",
  "utilization_percentage": 30.0,
  "capacity_status": "LOW",
  "evaluation_timestamp": "2024-01-15T10:00:00Z",
  "resource_breakdown": { ... }
}
```

#### Evaluate Safety

Evaluate shelter safety against red zones.

**Endpoint:** `POST /shelters/evaluate-safety`

**Authentication:** Required

**Request Body:**
```json
{
  "shelter_geometry": "POINT(73.85 18.52)",
  "red_zone_geometries": [
    "POLYGON((73.8 18.5, 73.9 18.5, 73.9 18.6, 73.8 18.6, 73.8 18.5))"
  ]
}
```

**Response:**
```json
{
  "safety_check_passed": true,
  "intersects_red_zone": false,
  "intersection_count": 0,
  "intersections": [],
  "evaluation_timestamp": "2024-01-15T10:00:00Z"
}
```

#### Evaluate Suitability

Comprehensive shelter suitability evaluation.

**Endpoint:** `POST /shelters/evaluate-suitability`

**Authentication:** Required

**Request Body:**
```json
{
  "shelter_id": "SHELTER_001",
  "total_capacity": 500,
  "current_occupancy": 150,
  "physical_beds": 500,
  "water_sufficiency_days": 14.0,
  "food_ration_storage_days": 21.0,
  "medical_facility_depth": "FULL",
  "geometry": "POINT(73.85 18.52)",
  "road_accessibility": "GOOD",
  "nearest_red_zone_distance_km": 10.0,
  "electricity": true,
  "water_supply": true,
  "sanitation_facilities": true
}
```

**Response:**
```json
{
  "capacity_evaluation": { ... },
  "safety_evaluation": { ... },
  "safety_score": 85.0,
  "overall_suitability": "HIGHLY_SUITABLE",
  "evaluation_timestamp": "2024-01-15T10:00:00Z"
}
```

### Priorities

#### Get Priorities

Get prioritized habitations for relocation.

**Endpoint:** `GET /priorities/`

**Authentication:** Required

**Query Parameters:**
- `state_code` (optional): Filter by state code
- `district_code` (optional): Filter by district code
- `priority_category` (optional): Filter by priority category
- `limit` (optional): Maximum results (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "count": 85,
  "limit": 50,
  "offset": 0,
  "priorities": [...],
  "summary": {
    "immediate_count": 15,
    "short_term_count": 35,
    "medium_term_count": 35
  }
}
```

#### Get Immediate Priorities

Get immediate priority habitations (0-24 hours).

**Endpoint:** `GET /priorities/immediate`

**Authentication:** Required

#### Get Short-Term Priorities

Get short-term priority habitations (1-4 weeks).

**Endpoint:** `GET /priorities/short-term`

**Authentication:** Required

#### Get Medium-Term Priorities

Get medium-term priority habitations (1-6 months).

**Endpoint:** `GET /priorities/medium-term`

**Authentication:** Required

#### Get Priority Summary

Get summary statistics for relocation priorities.

**Endpoint:** `GET /priorities/summary`

**Authentication:** Required

**Response:**
```json
{
  "total_habitations": 150,
  "prioritized_habitations": 85,
  "priority_distribution": {
    "immediate": 15,
    "short_term": 35,
    "medium_term": 35
  },
  "population_at_risk": {
    "immediate": 7500,
    "short_term": 17500,
    "medium_term": 12500
  },
  "resource_requirements": {
    "total_shelter_capacity_needed": 37500,
    "immediate_capacity_needed": 7500,
    "short_term_capacity_needed": 17500,
    "medium_term_capacity_needed": 12500
  }
}
```

### Data Ingestion

#### Get Data Status

Get current data ingestion status.

**Endpoint:** `GET /data/status`

**Authentication:** Required

**Response:**
```json
{
  "last_ingestion": {
    "isro_bhuvan": "2024-01-14T02:00:00Z",
    "imd_rainfall": "2024-01-15T01:00:00Z",
    "census": "2024-01-01T00:00:00Z"
  },
  "next_scheduled": { ... },
  "data_freshness": { ... },
  "record_counts": { ... },
  "system_status": "OPERATIONAL"
}
```

#### Trigger Data Ingestion

Trigger manual data ingestion for a specific source.

**Endpoint:** `POST /data/trigger`

**Authentication:** Required (WRITE permission)

**Request Body:**
```json
{
  "source": "imd_rainfall"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Data ingestion triggered for imd_rainfall",
  "triggered_by": "username",
  "source": "imd_rainfall"
}
```

#### Get Data Sources

Get available data sources and their configuration.

**Endpoint:** `GET /data/sources`

**Authentication:** Required

**Response:**
```json
{
  "sources": {
    "isro_bhuvan": { ... },
    "imd_rainfall": { ... },
    "census": { ... }
  },
  "scheduler_status": "ACTIVE"
}
```

#### Get Data Quality

Get data quality metrics.

**Endpoint:** `GET /data/quality`

**Authentication:** Required

**Query Parameters:**
- `source` (optional): Filter by data source

**Response:**
```json
{
  "overall_quality_score": 87.5,
  "quality_level": "GOOD",
  "source_quality": { ... },
  "quality_issues": [...]
}
```

### Sync

#### Upload Sync Data

Upload field data for offline-first sync.

**Endpoint:** `POST /sync/upload`

**Authentication:** Required

**Request Body:**
```json
{
  "device_id": "DEVICE_001",
  "data_type": "field_survey",
  "payload": {
    "records": [...]
  },
  "timestamp": "2024-01-15T10:00:00Z",
  "signature": "digital_signature"
}
```

**Response:**
```json
{
  "success": true,
  "sync_id": "SYNC_20240115100000_DEVICE_001",
  "records_processed": 15,
  "message": "Data synced successfully",
  "server_timestamp": "2024-01-15T10:00:00Z"
}
```

#### Upload Compressed Sync Data

Upload compressed field data.

**Endpoint:** `POST /sync/upload-compressed`

**Authentication:** Required

**Request:**
- `device_id`: Device ID
- `data_type`: Data type
- `timestamp`: Client timestamp
- `signature`: Digital signature
- `file`: Compressed data file

#### Download Sync Data

Download data for offline-first sync.

**Endpoint:** `GET /sync/download`

**Authentication:** Required

**Query Parameters:**
- `device_id`: Device ID
- `last_sync_timestamp` (optional): Last sync timestamp
- `data_types` (optional): Comma-separated data types

**Response:**
```json
{
  "device_id": "DEVICE_001",
  "server_timestamp": "2024-01-15T10:00:00Z",
  "data": {
    "red_zones": [...],
    "shelters": [...],
    "habitations": [...]
  },
  "compression_enabled": true,
  "data_size_bytes": 2048
}
```

#### Get Sync Status

Get sync status for devices.

**Endpoint:** `GET /sync/status`

**Authentication:** Required

**Query Parameters:**
- `device_id` (optional): Filter by specific device

**Response:**
```json
{
  "total_sync_operations": 1250,
  "successful_syncs": 1180,
  "failed_syncs": 70,
  "success_rate": 94.4,
  "recent_syncs": [...]
}
```

## Error Codes

| Code | Description |
|------|-------------|
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

## Rate Limiting

API requests are rate-limited to 60 requests per minute per user by default.

## Pagination

List endpoints support pagination using `limit` and `offset` parameters.

## GeoJSON Support

Spatial data endpoints support GeoJSON format for better integration with mapping applications.