# Configuration Reference

Complete reference for configuring the Disaster Management Platform.

## Configuration Files

The platform uses two main configuration files:

1. `config.yaml` - Main application configuration
2. `backend/.env` - Environment variables and secrets

## Main Configuration (config.yaml)

### Spatial Configuration

```yaml
spatial:
  grid:
    default_resolution: 100  # meters
    min_resolution: 50
    max_resolution: 500
    regional_overrides:
      # Example: "uttarakhand": 50, "kerala": 75
  
  risk_thresholds:
    default: 75  # percentage
    hazard_specific:
      landslide: 70
      flood: 75
      coastal_erosion: 80
      cloudburst: 65
    regional_specific:
      # Example: "himachal_pradesh": 70
```

**Grid Resolution:**
- **default_resolution**: Base grid cell size in meters
- **min_resolution**: Minimum allowed resolution
- **max_resolution**: Maximum allowed resolution
- **regional_overrides**: Region-specific resolution overrides

**Risk Thresholds:**
- **default**: Default risk threshold for red zone classification
- **hazard_specific**: Thresholds for different hazard types
- **regional_specific**: Region-specific threshold overrides

### Time Horizon Configuration

```yaml
time_horizons:
  immediate:
    name: "Immediate"
    description: "Critical priority - evacuation required"
    max_hours: 24
    color: "#FF0000"
  
  short_term:
    name: "Short-Term"
    description: "High priority - pre-stage assets"
    min_weeks: 1
    max_weeks: 4
    color: "#FFA500"
  
  medium_term:
    name: "Medium-Term"
    description: "Moderate priority - planned relocation"
    min_months: 1
    max_months: 6
    color: "#00FF00"
```

**Time Horizons:**
- **immediate**: 0-24 hours for critical situations
- **short_term**: 1-4 weeks for high priority
- **medium_term**: 1-6 months for planned relocation

### Priority Scoring Configuration

```yaml
priority_scoring:
  weights:
    hazard_intensity: 0.35
    population_vulnerability: 0.30
    access_limitations: 0.20
    disaster_history: 0.15
  
  vulnerability_factors:
    population_density: 0.3
    elderly_percentage: 0.25
    child_percentage: 0.2
    disability_percentage: 0.15
    economic_status: 0.1
  
  access_factors:
    road_connectivity: 0.4
    distance_to_emergency: 0.3
    communication_availability: 0.2
    evacuation_route_status: 0.1
  
  ml_refinement:
    enabled: true
    min_data_points: 1000
    retraining_interval_days: 30
    confidence_threshold: 0.7
```

**Priority Weights:**
- **hazard_intensity**: Weight for hazard exposure (35%)
- **population_vulnerability**: Weight for demographic vulnerability (30%)
- **access_limitations**: Weight for infrastructure access (20%)
- **disaster_history**: Weight for historical disaster frequency (15%)

**ML Refinement:**
- **enabled**: Whether to use ML for weight refinement
- **min_data_points**: Minimum data points required for ML training
- **retraining_interval_days**: How often to retrain ML model
- **confidence_threshold**: Minimum confidence for ML predictions

### Shelter Capacity Configuration

```yaml
shelter_capacity:
  resource_weights:
    physical_beds: 1.0
    water_sufficiency_days: 1.0
    food_ration_storage: 1.0
    medical_facility_depth: 1.0
  
  minimum_resources:
    water_liters_per_day: 15
    food_calories_per_day: 2000
    medical_beds_per_1000: 5
  
  safety_buffer: 0.1  # 10% buffer
```

**Resource Weights:**
- All resources weighted equally for bottleneck calculation
- Adjust weights if certain resources are more critical

**Minimum Resources:**
- Per-person minimum resource requirements
- Used for capacity calculations

**Safety Buffer:**
- Percentage buffer to prevent over-capacity
- Default 10% can be adjusted based on requirements

### Data Ingestion Configuration

```yaml
data_ingestion:
  isro_bhuvan:
    enabled: true
    update_frequency: "weekly"
    data_types:
      - elevation
      - slope
      - lithology
      - land_use
  
  imd_rainfall:
    enabled: true
    update_frequency: "hourly"
    api_type: "live"
    radar_data: true
    station_data: true
  
  census:
    enabled: true
    update_frequency: "yearly"
    api_type: "batch"
    data_types:
      - population
      - demographics
      - housing
      - amenities
```

**Update Frequencies:**
- **hourly**: For real-time data (IMD rainfall)
- **daily**: For frequently changing data
- **weekly**: For moderate-frequency data (ISRO Bhuvan)
- **monthly**: For slow-changing data
- **yearly**: For static data (Census)

### ML Model Configuration

```yaml
ml_models:
  hazard_predictor:
    model_type: "pretrained"
    framework: "xgboost"
    features:
      - precipitation
      - slope
      - elevation
      - lithology
      - soil_moisture
      - vegetation_index
    prediction_threshold: 0.75
  
  capacity_evaluator:
    model_type: "rule_based"
    framework: "custom"
  
  priority_classifier:
    model_type: "hybrid"
    framework: "scikit-learn"
    algorithm: "random_forest"
    expert_weight: 0.6
    ml_weight: 0.4
```

### API Configuration

```yaml
api:
  rate_limiting:
    enabled: true
    requests_per_minute: 60
    burst_size: 10
  
  pagination:
    default_page_size: 50
    max_page_size: 500
  
  caching:
    enabled: true
    ttl_seconds: 300  # 5 minutes
    spatial_query_cache: true
```

### Sync Configuration

```yaml
sync:
  enabled: true
  compression: true
  compression_level: 6
  conflict_resolution: "last_write_wins"
  max_payload_size_mb: 10
  signature_validation: true
```

### Logging Configuration

```yaml
logging:
  level: "INFO"
  format: "json"
  file:
    enabled: true
    path: "./logs/app.log"
    max_size_mb: 100
    backup_count: 5
  console:
    enabled: true
```

### Performance Configuration

```yaml
performance:
  connection_pool_size: 20
  max_overflow: 10
  pool_timeout: 30
  query_timeout: 60
  
  spatial_indexing: true
  query_caching: true
  parallel_processing: true
  max_workers: 4
```

## Environment Variables (.env)

### Database Configuration

```bash
DATABASE_URL=postgresql://username:password@localhost:5432/disaster_management
POSTGRES_USER=postgres
POSTGRES_PASSWORD=secure_password
POSTGRES_DB=disaster_management
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
```

### API Configuration

```bash
API_HOST=0.0.0.0
API_PORT=8000
API_RELOAD=false  # Set to false in production
DEBUG=false  # Set to false in production
```

### Security Configuration

```bash
SECRET_KEY=your-very-secure-secret-key-change-this
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

**Generating Secure Secret Key:**
```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Data Source API Keys

```bash
ISRO_API_KEY=your-isro-api-key
IMD_API_KEY=your-imd-api-key
CENSUS_API_KEY=your-census-api-key
```

### ML Model Configuration

```bash
MODEL_PATH=./models
HAZARD_MODEL_NAME=landslide_predictor.pkl
PRIORITY_MODEL_NAME=priority_classifier.pkl
```

### Spatial Configuration

```bash
DEFAULT_GRID_RESOLUTION=100
DEFAULT_RISK_THRESHOLD=75
```

### Time Horizon Configuration

```bash
IMMEDIATE_HORIZON_HOURS=24
SHORT_TERM_HORIZON_WEEKS=4
MEDIUM_TERM_HORIZON_MONTHS=6
```

### Data Ingestion Configuration

```bash
DATA_UPDATE_INTERVAL_HOURS=6
BATCH_IMPORT_PATH=./data/batch
```

### Logging Configuration

```bash
LOG_LEVEL=INFO
LOG_FILE=./logs/app.log
```

## Configuration Best Practices

### Security

1. **Never commit secrets to version control**
   - Use `.env.example` as template
   - Add `.env` to `.gitignore`
   - Use environment variables in production

2. **Use strong secrets**
   - Generate random secret keys
   - Rotate secrets regularly
   - Use different secrets for different environments

3. **Encrypt sensitive data**
   - Encrypt database passwords
   - Use SSL/TLS for connections
   - Secure API keys

### Performance

1. **Optimize database connections**
   - Use connection pooling
   - Set appropriate pool sizes
   - Monitor connection usage

2. **Enable caching**
   - Cache frequently accessed data
   - Set appropriate TTL values
   - Monitor cache hit rates

3. **Optimize spatial queries**
   - Use spatial indexes
   - Limit query results
   - Use appropriate spatial functions

### Scalability

1. **Design for horizontal scaling**
   - Stateless application design
   - External session storage
   - Load balancer support

2. **Use appropriate data types**
   - Use efficient data types
   - Normalize data where appropriate
   - Consider partitioning for large tables

3. **Monitor resource usage**
   - Track CPU, memory, disk usage
   - Monitor database performance
   - Set up alerts for thresholds

### Reliability

1. **Implement proper error handling**
   - Graceful degradation
   - Retry logic for transient failures
   - Circuit breakers for external services

2. **Use health checks**
   - Application health endpoints
   - Database health checks
   - Dependency health monitoring

3. **Implement backup strategies**
   - Regular database backups
   - Configuration backups
   - Disaster recovery procedures

## Environment-Specific Configuration

### Development

```yaml
# config.yaml
api:
  reload: true
debug: true
logging:
  level: "DEBUG"
```

```bash
# .env
DEBUG=true
API_RELOAD=true
LOG_LEVEL=DEBUG
```

### Staging

```yaml
# config.yaml
api:
  reload: false
debug: false
logging:
  level: "INFO"
```

```bash
# .env
DEBUG=false
API_RELOAD=false
LOG_LEVEL=INFO
DATABASE_URL=postgresql://staging_user:password@staging-host/db
```

### Production

```yaml
# config.yaml
api:
  reload: false
debug: false
logging:
  level: "WARNING"
  file:
    enabled: true
performance:
  connection_pool_size: 50
  max_workers: 8
```

```bash
# .env
DEBUG=false
API_RELOAD=false
LOG_LEVEL=WARNING
DATABASE_URL=postgresql://prod_user:secure_password@prod-host/db
SECRET_KEY=<production-secret-key>
```

## Configuration Validation

### Validation Script

Create a validation script to check configuration:

```python
import yaml
import os
from pathlib import Path

def validate_config():
    """Validate configuration files"""
    errors = []
    
    # Check config.yaml
    config_path = Path('config.yaml')
    if not config_path.exists():
        errors.append("config.yaml not found")
    else:
        with open(config_path) as f:
            config = yaml.safe_load(f)
            # Validate required sections
            required_sections = ['spatial', 'time_horizons', 'priority_scoring']
            for section in required_sections:
                if section not in config:
                    errors.append(f"Missing required section: {section}")
    
    # Check .env
    env_path = Path('backend/.env')
    if not env_path.exists():
        errors.append("backend/.env not found")
    else:
        # Load and validate required variables
        required_vars = ['DATABASE_URL', 'SECRET_KEY']
        with open(env_path) as f:
            env_content = f.read()
            for var in required_vars:
                if var not in env_content:
                    errors.append(f"Missing required environment variable: {var}")
    
    return errors

if __name__ == "__main__":
    errors = validate_config()
    if errors:
        print("Configuration validation failed:")
        for error in errors:
            print(f"  - {error}")
        exit(1)
    else:
        print("Configuration validation passed")
        exit(0)
```

## Configuration Updates

### Hot Configuration Reload

For certain configuration changes, you can reload without restart:

```python
from backend.app.core.config import yaml_config

# Reload configuration
yaml_config = YAMLConfig()  # Re-initialize
```

### Database Configuration Changes

Database configuration changes require service restart:

```bash
sudo systemctl restart disaster-management
```

### ML Model Updates

ML model updates can be done without full restart:

```python
from backend.app.ml.model_registry import reload_model

# Reload specific model
reload_model("hazard_predictor")
```

## Troubleshooting Configuration

### Common Issues

**Configuration not loading:**
- Check file paths are correct
- Verify file permissions
- Check YAML syntax
- Validate environment variable format

**Database connection issues:**
- Verify DATABASE_URL format
- Check database is running
- Verify credentials
- Check network connectivity

**ML model loading issues:**
- Verify MODEL_PATH exists
- Check model file permissions
- Verify model file format
- Check dependencies are installed

### Debug Mode

Enable debug mode for detailed error messages:

```bash
DEBUG=true
LOG_LEVEL=DEBUG
```

This will provide detailed stack traces and additional logging.