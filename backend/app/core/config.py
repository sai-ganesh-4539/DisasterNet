"""
Configuration management for the Disaster Management Platform
"""

import os
from typing import Optional

import yaml
from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings from environment variables"""

    # Database Configuration
    database_url: str = Field(default="sqlite:///./disaster_management.db")
    postgres_user: str = Field(default="postgres")
    postgres_password: str = Field(default="password")
    postgres_db: str = Field(default="disaster_management")
    postgres_host: str = Field(default="localhost")
    postgres_port: int = Field(default=5432)

    # API Configuration
    api_host: str = Field(default="0.0.0.0")
    api_port: int = Field(default=8000)
    api_reload: bool = Field(default=True)
    debug: bool = Field(default=True)

    # Security
    secret_key: str = Field(default="your-secret-key-change-this-in-production")
    algorithm: str = Field(default="HS256")
    access_token_expire_minutes: int = Field(default=30)

    # Data Source API Keys
    isro_api_key: Optional[str] = Field(default=None)
    imd_api_key: Optional[str] = Field(default=None)
    census_api_key: Optional[str] = Field(default=None)

    # Demo mode
    demo_mode: bool = Field(default=True)
    default_demo_scenario: str = Field(default="odisha_cyclone")

    # Local bootstrap operator accounts for prototype / local deployments
    bootstrap_admin_username: str = Field(default="sdma_admin")
    bootstrap_admin_password: str = Field(default="ChangeMe123!")
    bootstrap_analyst_username: str = Field(default="sdma_analyst")
    bootstrap_analyst_password: str = Field(default="ChangeMe123!")
    bootstrap_field_username: str = Field(default="field_survey")
    bootstrap_field_password: str = Field(default="ChangeMe123!")

    # ML Model Configuration
    model_path: str = Field(default="./models")
    hazard_model_name: str = Field(default="landslide_predictor.pkl")
    priority_model_name: str = Field(default="priority_classifier.pkl")

    # Spatial Configuration
    default_grid_resolution: int = Field(default=100)
    default_risk_threshold: int = Field(default=75)

    # Time Horizons
    immediate_horizon_hours: int = Field(default=24)
    short_term_horizon_weeks: int = Field(default=4)
    medium_term_horizon_months: int = Field(default=6)

    # Data Ingestion Configuration
    data_update_interval_hours: int = Field(default=6)
    batch_import_path: str = Field(default="./data/batch")

    # Logging
    log_level: str = Field(default="INFO")
    log_file: str = Field(default="./logs/app.log")

    class Config:
        env_file = ".env"
        case_sensitive = False


class YAMLConfig:
    """Configuration from YAML file"""

    def __init__(self, config_path: str = "config.yaml"):
        self.config_path = config_path
        self.config = self._load_config()

    def _load_config(self) -> dict:
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, "r") as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            # Return default configuration if file not found
            return self._get_default_config()

    def _get_default_config(self) -> dict:
        """Return default configuration"""
        return {
            "spatial": {
                "grid": {
                    "default_resolution": 100,
                    "min_resolution": 50,
                    "max_resolution": 500,
                },
                "risk_thresholds": {
                    "default": 75,
                    "hazard_specific": {
                        "landslide": 70,
                        "flood": 75,
                        "coastal_erosion": 80,
                        "cloudburst": 65,
                    },
                },
            },
            "time_horizons": {
                "immediate": {"max_hours": 24},
                "short_term": {"min_weeks": 1, "max_weeks": 4},
                "medium_term": {"min_months": 1, "max_months": 6},
            },
            "priority_scoring": {
                "weights": {
                    "hazard_intensity": 0.35,
                    "population_vulnerability": 0.30,
                    "access_limitations": 0.20,
                    "disaster_history": 0.15,
                }
            },
            "ml_models": {"hazard_predictor": {"prediction_threshold": 0.75}},
        }

    def get(self, key: str, default=None):
        """Get configuration value by key (supports nested keys with dots)"""
        keys = key.split(".")
        value = self.config
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        return value

    def get_spatial_config(self) -> dict:
        """Get spatial configuration"""
        return self.config.get("spatial", {})

    def get_time_horizons(self) -> dict:
        """Get time horizon configuration"""
        return self.config.get("time_horizons", {})

    def get_priority_scoring(self) -> dict:
        """Get priority scoring configuration"""
        return self.config.get("priority_scoring", {})

    def get_ml_config(self) -> dict:
        """Get ML model configuration"""
        return self.config.get("ml_models", {})


# Global instances
settings = Settings()
yaml_config = YAMLConfig()


def get_grid_resolution(region: Optional[str] = None) -> int:
    """Get grid resolution for a specific region or default"""
    if region:
        regional_overrides = yaml_config.get("spatial.grid.regional_overrides", {})
        if region in regional_overrides:
            return regional_overrides[region]
    return yaml_config.get("spatial.grid.default_resolution", 100)


def get_risk_threshold(
    hazard_type: Optional[str] = None, region: Optional[str] = None
) -> int:
    """Get risk threshold for a specific hazard type or default"""
    if region:
        regional_specific = yaml_config.get(
            "spatial.risk_thresholds.regional_specific", {}
        )
        if region in regional_specific:
            return regional_specific[region]

    if hazard_type:
        hazard_specific = yaml_config.get("spatial.risk_thresholds.hazard_specific", {})
        if hazard_type in hazard_specific:
            return hazard_specific[hazard_type]

    return yaml_config.get("spatial.risk_thresholds.default", 75)


def get_priority_weights() -> dict:
    """Get priority scoring weights"""
    return yaml_config.get(
        "priority_scoring.weights",
        {
            "hazard_intensity": 0.35,
            "population_vulnerability": 0.30,
            "access_limitations": 0.20,
            "disaster_history": 0.15,
        },
    )
