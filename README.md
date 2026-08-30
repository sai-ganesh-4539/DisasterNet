# Disaster Management Platform

An AI-driven GIS platform for intelligent identification of hazard-based red zones, carrying capacity assessment, and immediate relocation needs for vulnerable habitations in India's disaster-prone regions.

## Overview

This platform provides State Disaster Management Authorities (SDMAs) with:

- **Real-time Red Zone Mapping**: AI-powered dynamic identification of unsafe areas using environmental data
- **Carrying Capacity Assessment**: Multi-resource evaluation of potential relocation sites
- **Relocation Prioritization**: Time-horizon classification (Immediate, Short-term, Medium-term) for vulnerable habitations
- **Offline-First Field Operations**: Simplified sync for ground-truth data collection

## Architecture

```
[Data Sources] → [Data Ingestion] → [PostgreSQL+PostGIS] → [AI/ML Engines] → [FastAPI APIs] → [Future UI Layers]
```

### Components

- **Data Ingestion**: Hybrid pipelines for ISRO Bhuvan terrain data, IMD rainfall data, and Census demographic data
- **Spatial Database**: PostgreSQL + PostGIS with cluster-ready design for national scale
- **AI/ML Engines**: Pre-trained models for hazard prediction, capacity evaluation, and priority classification
- **REST API**: FastAPI-based backend with authentication and RBAC
- **Offline Sync**: Simplified sync protocol for field data collection

## Features

### Core AI Engines

1. **AI Hazard Predictor**
   - Grid-based risk assessment (configurable resolution)
   - Multi-hazard support (landslide, flood, coastal erosion, cloudburst)
   - Dynamic red zone polygon generation
   - Real-time risk scoring (0-100)

2. **Multi-Resource Capacity Evaluator**
   - Safety intersect checks with red zones
   - Bottleneck-based capacity calculation
   - Resource constraints: beds, water, food, medical
   - Overall suitability assessment

3. **Time-Horizon Priority Classifier**
   - Hybrid scoring (expert weights + ML refinement)
   - Three action windows:
     - Immediate (0-24 hours)
     - Short-term (1-4 weeks)
     - Medium-term (1-6 months)
   - Comprehensive vulnerability assessment

### Data Sources

- **ISRO Bhuvan**: Terrain data (elevation, slope, lithology, land use)
- **IMD**: Live rainfall and weather data
- **Census**: Demographic and socio-economic data

## Setup Instructions

### Prerequisites

- Python 3.10+
- PostgreSQL 14+ with PostGIS 3.3+
- GDAL library
- PROJ library

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd sih
```

2. **Create virtual environment**
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. **Install dependencies**
```bash
pip install -r backend/requirements.txt
```

4. **Configure environment**
```bash
cp backend/.env.example backend/.env
# Edit backend/.env with your configuration
```

5. **Set up database**
```bash
# Create PostgreSQL database
createdb disaster_management

# Run schema migrations
psql -d disaster_management -f database/schemas/01_spatial_extensions.sql
psql -d disaster_management -f database/schemas/02_hazard_grids.sql
psql -d disaster_management -f database/schemas/03_red_zones.sql
psql -d disaster_management -f database/schemas/04_habitations.sql
psql -d disaster_management -f database/schemas/05_shelters.sql
psql -d disaster_management -f database/schemas/06_census_data.sql
psql -d disaster_management -f database/schemas/07_environmental_data.sql
psql -d disaster_management -f database/schemas/08_users_roles.sql
psql -d disaster_management -f database/schemas/09_audit_log.sql
```

6. **Start the API server**
```bash
cd backend
python -m app.main
```

The API will be available at `http://localhost:8000`

### API Documentation

Once the server is running, access the interactive API documentation:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Configuration

Key configuration files:

- `config.yaml`: Main configuration (grid resolution, risk thresholds, time horizons)
- `backend/.env`: Environment variables (database credentials, API keys)

### Dynamic Configuration

The system supports dynamic configuration for:

- **Grid Resolution**: 50m-500m (default: 100m)
- **Risk Thresholds**: Hazard-specific and region-specific overrides
- **Time Horizons**: Configurable action windows
- **Priority Weights**: Expert-defined with ML refinement

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for detailed configuration options.

## Usage Examples

### Hazard Prediction

```bash
curl -X POST "http://localhost:8000/api/v1/hazards/predict" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 28.5,
    "longitude": 77.2,
    "precipitation_24h_mm": 45.0,
    "precipitation_72h_mm": 120.0,
    "slope_percentage": 25.0,
    "elevation": 1500.0,
    "lithology": "GRANITE",
    "soil_moisture_index": 0.7,
    "vegetation_index": 0.6,
    "hazard_type": "landslide"
  }'
```

### Priority Assessment

```bash
curl -X POST "http://localhost:8000/api/v1/habitations/assess" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "habitation_id": "HAB_001",
    "latitude": 18.5,
    "longitude": 73.9,
    "total_population": 500,
    "elderly_percentage": 8.0,
    "red_zone_proximity_km": 2.5
  }'
```

### Shelter Evaluation

```bash
curl -X POST "http://localhost:8000/api/v1/shelters/evaluate" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "shelter_id": "SHELTER_001",
    "total_capacity": 500,
    "current_occupancy": 150,
    "physical_beds": 500,
    "water_sufficiency_days": 14.0,
    "food_ration_storage_days": 21.0,
    "medical_facility_depth": "FULL",
    "geometry": "POINT(73.85 18.52)"
  }'
```

## Testing

Run the test suite:

```bash
cd backend
pytest tests/ -v
```

Run specific test modules:

```bash
pytest tests/test_ml.py -v
pytest tests/test_api.py -v
pytest tests/test_ingestion.py -v
pytest tests/test_spatial.py -v
```

## Deployment

This system is designed for on-premise deployment. See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.

### Key Deployment Considerations

- **Database**: PostgreSQL + PostGIS with proper indexing and partitioning
- **Python Environment**: System Python or virtual environment
- **Performance**: Connection pooling, query optimization, caching
- **Security**: HTTPS, authentication, audit logging
- **Monitoring**: System performance logging, error tracking

## Project Structure

```
sih/
├── backend/
│   ├── app/
│   │   ├── api/v1/endpoints/    # API endpoints
│   │   ├── core/                # Configuration, security, spatial utils
│   │   ├── models/              # Database models
│   │   ├── services/            # Business logic
│   │   ├── ml/                  # ML model integration
│   │   ├── ingestion/           # Data ingestion pipelines
│   │   └── main.py              # FastAPI application
│   ├── tests/                  # Test suite
│   ├── requirements.txt         # Python dependencies
│   └── .env.example            # Environment template
├── database/
│   └── schemas/                # SQL schema files
├── docs/                       # Documentation
├── config.yaml                 # Main configuration
└── README.md                   # This file
```

## API Endpoints

### Hazards
- `POST /api/v1/hazards/predict` - Predict hazard risk for location
- `POST /api/v1/hazards/predict-batch` - Batch hazard prediction
- `GET /api/v1/hazards/model-info` - Get model information

### Red Zones
- `GET /api/v1/red-zones/` - Query red zones
- `GET /api/v1/red-zones/{zone_id}` - Get specific red zone
- `POST /api/v1/red-zones/` - Create red zone
- `PUT /api/v1/red-zones/{zone_id}` - Update red zone
- `DELETE /api/v1/red-zones/{zone_id}` - Delete red zone

### Habitations
- `GET /api/v1/habitations/` - Query habitations
- `GET /api/v1/habitations/{id}/risk` - Get habitation risk
- `POST /api/v1/habitations/assess` - Assess relocation priority
- `POST /api/v1/habitations/assess-batch` - Batch priority assessment

### Shelters
- `GET /api/v1/shelters/` - Query shelters
- `GET /api/v1/shelters/capacity` - Get shelter capacity
- `POST /api/v1/shelters/evaluate` - Evaluate shelter capacity
- `POST /api/v1/shelters/evaluate-safety` - Evaluate shelter safety
- `POST /api/v1/shelters/evaluate-suitability` - Comprehensive suitability

### Priorities
- `GET /api/v1/priorities/` - Get prioritized habitations
- `GET /api/v1/priorities/immediate` - Immediate priorities
- `GET /api/v1/priorities/short-term` - Short-term priorities
- `GET /api/v1/priorities/medium-term` - Medium-term priorities
- `GET /api/v1/priorities/summary` - Priority summary statistics

### Data Ingestion
- `GET /api/v1/data/status` - Data ingestion status
- `POST /api/v1/data/trigger` - Trigger manual ingestion
- `GET /api/v1/data/sources` - Available data sources
- `GET /api/v1/data/quality` - Data quality metrics

### Sync
- `POST /api/v1/sync/upload` - Upload field data
- `POST /api/v1/sync/upload-compressed` - Upload compressed data
- `GET /api/v1/sync/download` - Download data for offline use
- `GET /api/v1/sync/status` - Sync operation status

## License

This project is developed for the Smart India Hackathon.

## Support

For support and documentation, see the `docs/` directory or contact the development team.