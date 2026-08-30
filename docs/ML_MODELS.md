# ML Models Documentation

Documentation for the machine learning models used in the Disaster Management Platform.

## Overview

The platform uses three main ML engines:

1. **Hazard Predictor** - Real-time red zone mapping
2. **Capacity Evaluator** - Multi-resource carrying capacity assessment
3. **Priority Classifier** - Time-horizon relocation prioritization

## Model Architecture

### Hazard Predictor

**Model Type**: Random Forest Classifier
**Framework**: XGBoost/Scikit-learn
**Purpose**: Predict hazard risk for grid cells

#### Input Features

- `precipitation_24h_mm` (0-100): 24-hour precipitation in mm
- `precipitation_72h_mm` (0-200): 72-hour precipitation in mm
- `slope_percentage` (0-50): Slope in percentage
- `elevation` (0-2000): Elevation in meters
- `lithology` (categorical): GRANITE, SANDSTONE, LIMESTONE, SHALE, BASALT, OTHER
- `soil_moisture_index` (0-1): Soil moisture index
- `vegetation_index` (0-1): NDVI or similar vegetation index

#### Output

- `risk_score` (0-100): Overall risk score
- `risk_probability` (0-1): Probability of high risk
- `is_red_zone` (boolean): Whether area is unsuitable for habitation
- `risk_level` (string): LOW, MEDIUM, HIGH, CRITICAL

#### Training Data

The model is trained on historical disaster data including:
- Past landslide occurrences
- Rainfall patterns
- Terrain characteristics
- Soil properties

#### Performance Metrics

- **Accuracy**: Target >85%
- **Precision**: Target >80%
- **Recall**: Target >75%
- **F1 Score**: Target >77%

#### Feature Importance

Typical feature importance distribution:
- Precipitation (24h): 30%
- Slope: 25%
- Elevation: 15%
- Soil moisture: 15%
- Vegetation: 10%
- Lithology: 5%

### Capacity Evaluator

**Model Type**: Rule-based system
**Framework**: Custom Python implementation
**Purpose**: Evaluate shelter capacity based on resource bottlenecks

#### Input Features

- `total_capacity` (integer): Total shelter capacity
- `physical_beds` (integer): Number of physical beds
- `water_sufficiency_days` (float): Days of water sufficiency
- `food_ration_storage_days` (float): Days of food storage
- `medical_facility_depth` (categorical): FULL, BASIC, LIMITED, NONE

#### Output

- `effective_capacity` (integer): Capacity based on bottlenecks
- `capacity_constraint` (string): Primary limiting resource
- `utilization_percentage` (float): Current utilization
- `capacity_status` (string): AVAILABLE, LOW, MODERATE, HIGH, CRITICAL, FULL

#### Capacity Calculation

```
effective_capacity = min(
    physical_beds,
    total_capacity * (water_sufficiency_days / 7),
    total_capacity * (food_ration_storage_days / 7),
    total_capacity * medical_capacity_multiplier
) * (1 - safety_buffer)
```

#### Resource Weights

All resources are weighted equally in the bottleneck calculation:
- Physical beds: 1.0
- Water sufficiency: 1.0
- Food storage: 1.0
- Medical facilities: 1.0

### Priority Classifier

**Model Type**: Hybrid (Expert weights + ML)
**Framework**: Random Forest Classifier
**Purpose**: Classify relocation priority time horizons

#### Input Features

- `hazard_intensity` (0-100): Hazard exposure score
- `population_vulnerability` (0-100): Population vulnerability score
- `access_limitations` (0-100): Access and infrastructure limitations
- `disaster_history` (0-100): Historical disaster frequency

#### Output

- `priority_score` (0-100): Overall priority score
- `priority_category` (string): IMMEDIATE, SHORT_TERM, MEDIUM_TERM
- `expert_category` (string): Expert-weighted classification
- `ml_category` (string): ML model classification

#### Hybrid Approach

The classifier uses a hybrid approach:

1. **Expert Weights** (60%):
   - Hazard intensity: 35%
   - Population vulnerability: 30%
   - Access limitations: 20%
   - Disaster history: 15%

2. **ML Model** (40%):
   - Random Forest classifier
   - Trained on historical relocation decisions
   - Refines expert classifications

#### Time Horizon Categories

- **IMMEDIATE** (0-24 hours): Critical priority, evacuation required
  - Trigger: Priority score ≥80 or in red zone
  - Action: Immediate evacuation alerts

- **SHORT_TERM** (1-4 weeks): High priority, pre-stage assets
  - Trigger: Priority score 60-79
  - Action: Prepare local shelters, mobilize resources

- **MEDIUM_TERM** (1-6 months): Moderate priority, planned relocation
  - Trigger: Priority score <60
  - Action: Plan land allocation, construct permanent housing

## Model Training

### Training Pipeline

1. **Data Collection**
   - Historical disaster data
   - Demographic census data
   - Infrastructure data
   - Environmental monitoring data

2. **Feature Engineering**
   - Normalization of numeric features
   - One-hot encoding of categorical features
   - Temporal feature extraction
   - Spatial feature calculation

3. **Model Training**
   - Train/test split (80/20)
   - Cross-validation (5-fold)
   - Hyperparameter tuning
   - Model evaluation

4. **Model Validation**
   - Performance metrics calculation
   - Feature importance analysis
   - Error analysis
   - Validation on holdout set

### Hyperparameters

#### Hazard Predictor

```python
RandomForestClassifier(
    n_estimators=100,
    max_depth=10,
    min_samples_split=5,
    min_samples_leaf=2,
    random_state=42,
    n_jobs=-1
)
```

#### Priority Classifier

```python
RandomForestClassifier(
    n_estimators=50,
    max_depth=8,
    min_samples_split=10,
    min_samples_leaf=4,
    random_state=42,
    n_jobs=-1
)
```

## Model Deployment

### Model Loading

Models are loaded at application startup:

```python
from backend.app.ml.model_registry import initialize_models

model_load_results = initialize_models()
```

### Model Registry

All models are registered in a central registry:

```python
from backend.app.ml.model_registry import get_model

hazard_model = get_model("hazard_predictor")
priority_model = get_model("priority_classifier")
```

### Prediction Caching

Predictions are cached for 5 minutes by default to improve performance:

```python
from backend.app.ml.model_registry import prediction_cache

# Automatic caching
result = model.predict(features)

# Manual cache management
prediction_cache.clear()
```

## Model Monitoring

### Performance Monitoring

Track model performance metrics:
- Prediction latency
- Accuracy over time
- Feature distribution drift
- Prediction confidence distribution

### Retraining Strategy

- **Continuous monitoring** of model performance
- **Monthly evaluation** of model degradation
- **Quarterly retraining** with new data
- **Annual comprehensive review** of model architecture

### Model Versioning

- Semantic versioning (MAJOR.MINOR.PATCH)
- Track training data version
- Maintain model registry
- Rollback capability for failed deployments

## Model Explainability

### Feature Importance

Each model provides feature importance:

```python
importance = model.get_feature_importance()
# Returns: {'precipitation_24h_mm': 30.5, 'slope_percentage': 25.2, ...}
```

### Prediction Explanation

Detailed breakdown of predictions:

```python
breakdown = model._get_calculation_breakdown(features)
# Returns: component scores, weighted contributions, etc.
```

### SHAP Values (Future Enhancement)

Plan to implement SHAP (SHapley Additive exPlanations) for:
- Individual prediction explanation
- Feature contribution analysis
- Model interpretability improvement

## Model Limitations

### Hazard Predictor

- **Limited to trained hazard types**: Currently landslide, flood, coastal erosion, cloudburst
- **Spatial resolution**: Limited by grid resolution (100m default)
- **Temporal lag**: Depends on data freshness (IMD data hourly)
- **Regional bias**: May perform better in regions with more training data

### Capacity Evaluator

- **Simplified resource modeling**: Assumes linear resource consumption
- **Static constraints**: Does not account for dynamic resource changes
- **No behavioral factors**: Assumes optimal resource usage

### Priority Classifier

- **Expert weight bias**: Initial weights may not reflect all regions
- **ML data requirements**: Requires sufficient historical data for training
- **Binary classification**: Limited to three time horizons

## Future Enhancements

### Planned Improvements

1. **Deep Learning Models**
   - LSTM for temporal hazard prediction
   - CNN for spatial pattern recognition
   - Graph neural networks for network analysis

2. **Ensemble Methods**
   - Model stacking for improved accuracy
   - Bayesian model averaging
   - Voting classifiers

3. **Real-time Learning**
   - Online learning for continuous model updates
   - Adaptive thresholds based on conditions
   - Transfer learning for new regions

4. **Explainable AI**
   - SHAP values for model interpretability
   - Counterfactual explanations
   - Attention mechanisms for feature importance

## Model Safety

### Input Validation

- Range checking for numeric features
- Category validation for categorical features
- Geometry validation for spatial features
- Missing value handling

### Output Validation

- Score range validation (0-100)
- Category validation
- Consistency checks
- Anomaly detection

### Fallback Mechanisms

- Rule-based fallback when models unavailable
- Default values for missing features
- Graceful degradation for reduced performance
- Manual override capabilities

## Data Privacy

### Model Training Data

- Anonymization of personal data
- Aggregation at appropriate levels
- Compliance with data protection regulations
- Secure data storage and transfer

### Prediction Data

- No personal data in predictions
- Aggregated results only
- Data retention policies
- Audit logging for compliance