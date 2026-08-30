"""Live hazard scoring model.

This replaces the previous startup-trained synthetic RandomForest with a
transparent, physically weighted risk scorer that reacts directly to live
meteorology, terrain, and soil conditions.
"""

from __future__ import annotations

import logging
import math
from datetime import datetime
from typing import Any, Dict, List

from app.core.config import get_risk_threshold
from app.ml.base_model import BaseMLModel, model_registry, prediction_cache

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class HazardPredictor(BaseMLModel):
    """Operational hazard scorer for red-zone mapping."""

    def __init__(self, model_name: str = "hazard_predictor"):
        super().__init__(model_name)
        self.required_features = [
            "precipitation_24h_mm",
            "precipitation_72h_mm",
            "slope_percentage",
            "elevation",
            "lithology",
            "soil_moisture_index",
            "vegetation_index",
        ]

    def load_model(self) -> bool:
        self.model = None
        self.is_loaded = True
        self.model_version = "live-physical-3.1"
        self.last_loaded = datetime.utcnow()
        logger.info("Hazard predictor ready: %s", self.model_name)
        return True

    def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        cached_result = prediction_cache.get(self.model_name, features)
        if cached_result is not None:
            return cached_result
        if not self.validate_features(features, self.required_features):
            raise ValueError("Missing required features for hazard prediction")

        hazard_type = str(features.get("hazard_type") or "flood").lower()
        precip_24 = float(features.get("precipitation_24h_mm") or 0.0)
        precip_72 = float(features.get("precipitation_72h_mm") or 0.0)
        slope = float(features.get("slope_percentage") or 0.0)
        elevation = float(features.get("elevation") or 0.0)
        soil = float(features.get("soil_moisture_index") or 0.35)
        vegetation = float(features.get("vegetation_index") or 0.4)
        lithology = str(features.get("lithology") or "OTHER").upper()

        lithology_factor = {
            "SHALE": 1.12,
            "SANDSTONE": 1.06,
            "LIMESTONE": 1.02,
            "GRANITE": 0.97,
            "BASALT": 0.95,
            "OTHER": 1.0,
        }.get(lithology, 1.0)

        if hazard_type == "landslide":
            raw = (
                precip_24 * 0.48
                + precip_72 * 0.18
                + slope * 1.55
                + max(0.0, elevation - 450.0) / 55.0
                + soil * 26.0
                - vegetation * 14.0
            ) * lithology_factor
        elif hazard_type == "cloudburst":
            raw = (
                precip_24 * 0.72
                + precip_72 * 0.12
                + slope * 0.9
                + soil * 15.0
                + max(0.0, elevation - 700.0) / 80.0
            ) * lithology_factor
        elif hazard_type == "coastal_erosion":
            raw = (
                precip_24 * 0.25
                + precip_72 * 0.15
                + max(0.0, 30.0 - elevation) * 1.8
                + soil * 14.0
                + max(0.0, 6.0 - slope) * 1.5
            ) * lithology_factor
        else:
            raw = (
                precip_24 * 0.62
                + precip_72 * 0.21
                + max(0.0, 140.0 - elevation) * 0.16
                + soil * 24.0
                + max(0.0, 10.0 - slope) * 1.2
            ) * lithology_factor

        centered = (raw - 58.0) / 12.0
        risk_probability = 1.0 / (1.0 + math.exp(-centered))
        risk_score = max(0.0, min(100.0, risk_probability * 100.0))
        risk_threshold = get_risk_threshold(hazard_type, features.get("region"))
        result = {
            "risk_score": round(risk_score, 2),
            "risk_probability": round(risk_probability, 4),
            "risk_threshold": risk_threshold,
            "is_red_zone": bool(risk_score >= risk_threshold),
            "risk_level": self._classify_risk_level(risk_score),
            "hazard_type": hazard_type.upper(),
            "prediction_timestamp": datetime.utcnow().isoformat(),
            "model_version": self.model_version,
            "features_used": list(features.keys()),
        }
        prediction_cache.set(self.model_name, features, result)
        return result

    def _classify_risk_level(self, risk_score: float) -> str:
        if risk_score >= 90:
            return "CRITICAL"
        if risk_score >= 75:
            return "HIGH"
        if risk_score >= 50:
            return "MEDIUM"
        return "LOW"

    def predict_batch(
        self, features_list: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        results = []
        for features in features_list:
            try:
                results.append(self.predict(features))
            except Exception as exc:
                logger.error("Error predicting hazard: %s", exc)
                results.append(
                    {"error": str(exc), "risk_score": None, "is_red_zone": False}
                )
        return results

    def get_feature_importance(self) -> Dict[str, float]:
        return {
            "precipitation_24h_mm": 30.0,
            "precipitation_72h_mm": 20.0,
            "slope_percentage": 18.0,
            "elevation": 10.0,
            "soil_moisture_index": 12.0,
            "vegetation_index": 6.0,
            "lithology": 4.0,
        }

    def generate_red_zone_polygons(
        self, grid_predictions: List[Dict[str, Any]], min_cluster_size: int = 5
    ) -> List[Dict[str, Any]]:
        try:
            import numpy as np
            from shapely.geometry import MultiPoint
            from sklearn.cluster import DBSCAN

            high_risk_grids = [
                pred
                for pred in grid_predictions
                if pred.get("is_red_zone")
                and "latitude" in pred
                and "longitude" in pred
            ]
            if len(high_risk_grids) < min_cluster_size:
                return []
            coordinates = np.array(
                [[grid["latitude"], grid["longitude"]] for grid in high_risk_grids]
            )
            clustering = DBSCAN(eps=0.08, min_samples=min_cluster_size).fit(coordinates)
            clusters: Dict[int, List[Dict[str, Any]]] = {}
            for idx, label in enumerate(clustering.labels_):
                if label != -1:
                    clusters.setdefault(int(label), []).append(high_risk_grids[idx])

            red_zones = []
            for cluster_id, cluster_grids in clusters.items():
                hull = MultiPoint(
                    [(grid["longitude"], grid["latitude"]) for grid in cluster_grids]
                ).convex_hull
                red_zones.append(
                    {
                        "cluster_id": cluster_id,
                        "grid_count": len(cluster_grids),
                        "average_risk_score": sum(
                            g["risk_score"] for g in cluster_grids
                        )
                        / len(cluster_grids),
                        "max_risk_score": max(g["risk_score"] for g in cluster_grids),
                        "polygon": hull.wkt,
                        "grid_cells": cluster_grids,
                    }
                )
            return red_zones
        except Exception as exc:
            logger.error("Error generating red zone polygons: %s", exc)
            return []


hazard_predictor = HazardPredictor()
model_registry.register_model(
    hazard_predictor,
    {
        "description": "Live physically weighted hazard scorer for red-zone mapping",
        "model_type": "physics_calibrated",
        "supported_hazards": ["LANDSLIDE", "FLOOD", "COASTAL_EROSION", "CLOUDBURST"],
    },
)
