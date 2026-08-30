"""Hybrid relocation-priority ranker.

This replaces the previous synthetic classifier with a transparent scorecard
that combines live hazard exposure, population vulnerability, and access
limitations into operational time horizons.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any, Dict, List

from app.core.config import get_priority_weights, yaml_config
from app.ml.base_model import BaseMLModel, model_registry, prediction_cache

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class PriorityClassifier(BaseMLModel):
    """Hybrid scorecard for habitation relocation priority."""

    def __init__(self, model_name: str = "priority_classifier"):
        super().__init__(model_name)
        self.required_features = [
            "red_zone_proximity_km",
            "current_risk_score",
            "total_population",
            "evacuation_route_status",
        ]
        self.time_horizons = yaml_config.get("time_horizons", {})

    def load_model(self) -> bool:
        self.model = None
        self.is_loaded = True
        self.model_version = "hybrid-scorecard-3.1"
        self.last_loaded = datetime.utcnow()
        logger.info("Priority classifier ready: %s", self.model_name)
        return True

    def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        cached_result = prediction_cache.get(self.model_name, features)
        if cached_result is not None:
            return cached_result

        priority_score = self._calculate_priority_score(features)
        expert_category = self._classify_priority_category(priority_score, features)
        ml_category = self._derived_model_category(features)
        final_category = self._combine_predictions(
            expert_category, ml_category, priority_score
        )
        result = {
            "priority_score": round(priority_score, 2),
            "priority_category": final_category,
            "expert_category": expert_category,
            "ml_category": ml_category,
            "time_horizon_details": self._get_time_horizon_details(final_category),
            "calculation_breakdown": self._get_calculation_breakdown(features),
            "prediction_timestamp": datetime.utcnow().isoformat(),
            "model_version": self.model_version,
            "habitation_id": features.get("habitation_id", "unknown"),
        }
        prediction_cache.set(self.model_name, features, result)
        return result

    def _calculate_priority_score(self, features: Dict[str, Any]) -> float:
        weights = get_priority_weights()
        hazard_intensity = self._calculate_hazard_intensity(features)
        population_vulnerability = self._calculate_population_vulnerability(features)
        access_limitations = self._calculate_access_limitations(features)
        disaster_history = self._calculate_disaster_history(features)
        priority_score = (
            hazard_intensity * weights["hazard_intensity"]
            + population_vulnerability * weights["population_vulnerability"]
            + access_limitations * weights["access_limitations"]
            + disaster_history * weights["disaster_history"]
        )
        return min(100.0, max(0.0, priority_score))

    def _calculate_hazard_intensity(self, features: Dict[str, Any]) -> float:
        score = 0.0
        red_zone_proximity = float(features.get("red_zone_proximity_km") or 100.0)
        current_risk_score = float(features.get("current_risk_score") or 0.0)
        if red_zone_proximity < 1.0:
            score += 42.0
        elif red_zone_proximity < 3.0:
            score += 34.0
        elif red_zone_proximity < 7.0:
            score += 24.0
        elif red_zone_proximity < 15.0:
            score += 12.0
        score += current_risk_score * 0.45
        score += min(
            18.0, float(features.get("disaster_frequency_score") or 0.0) * 0.18
        )
        if features.get("current_red_zone_id"):
            score += 12.0
        return min(100.0, score)

    def _calculate_population_vulnerability(self, features: Dict[str, Any]) -> float:
        total_population = max(1.0, float(features.get("total_population") or 1.0))
        elderly_percentage = float(features.get("elderly_percentage") or 0.0)
        child_percentage = float(features.get("child_percentage") or 0.0)
        disability_percentage = float(features.get("disability_percentage") or 0.0)
        density = float(features.get("population_density_per_sqkm") or 0.0)
        score = 0.0
        score += min(28.0, density / 45.0)
        score += elderly_percentage * 0.85
        score += child_percentage * 0.65
        score += disability_percentage * 1.35
        if total_population > 10000:
            score += 14.0
        elif total_population > 3000:
            score += 8.0
        econ = str(features.get("economic_status") or "MIXED").upper()
        if econ == "BPL":
            score += 14.0
        elif econ == "MIXED":
            score += 8.0
        return min(100.0, score)

    def _calculate_access_limitations(self, features: Dict[str, Any]) -> float:
        score = 0.0
        road_connectivity = str(features.get("road_connectivity") or "PAVED").upper()
        road_distance = float(features.get("road_distance_km") or 0.0)
        emergency_distance = float(features.get("nearest_emergency_km") or 0.0)
        communication = str(
            features.get("communication_availability") or "MOBILE"
        ).upper()
        evacuation_route = str(
            features.get("evacuation_route_status") or "CLEAR"
        ).upper()
        evacuation_time = float(features.get("evacuation_time_hours") or 0.0)
        if road_connectivity == "NONE":
            score += 36.0
        elif road_connectivity == "SEASONAL":
            score += 28.0
        elif road_connectivity == "UNPAVED":
            score += 18.0
        score += min(16.0, road_distance * 1.6)
        score += min(16.0, emergency_distance * 0.55)
        if communication == "NONE":
            score += 18.0
        elif communication == "LIMITED":
            score += 9.0
        if evacuation_route == "BLOCKED":
            score += 28.0
        elif evacuation_route == "DAMAGED":
            score += 18.0
        score += min(18.0, evacuation_time * 1.5)
        return min(100.0, score)

    def _calculate_disaster_history(self, features: Dict[str, Any]) -> float:
        score = min(40.0, float(features.get("disaster_frequency_score") or 0.0) * 0.5)
        hazard_history = features.get("hazard_history") or []
        current_year = datetime.now().year
        for item in hazard_history:
            year = int(item.get("year") or 0)
            score += 12.0 if year >= current_year - 5 else 4.0
        return min(100.0, score)

    def _classify_priority_category(
        self, priority_score: float, features: Dict[str, Any]
    ) -> str:
        red_zone_proximity = float(features.get("red_zone_proximity_km") or 100.0)
        current_risk_score = float(features.get("current_risk_score") or 0.0)
        if (
            features.get("current_red_zone_id")
            or red_zone_proximity < 1.0
            or current_risk_score >= 85
        ):
            return "IMMEDIATE"
        if priority_score >= 75:
            return "IMMEDIATE"
        if priority_score >= 50:
            return "SHORT_TERM"
        return "MEDIUM_TERM"

    def _derived_model_category(self, features: Dict[str, Any]) -> str:
        signal = (
            self._calculate_hazard_intensity(features) * 0.5
            + self._calculate_population_vulnerability(features) * 0.25
            + self._calculate_access_limitations(features) * 0.25
        )
        if signal >= 78:
            return "IMMEDIATE"
        if signal >= 52:
            return "SHORT_TERM"
        return "MEDIUM_TERM"

    def _combine_predictions(
        self, expert_category: str, ml_category: str, priority_score: float
    ) -> str:
        enabled = yaml_config.get("priority_scoring.ml_refinement.enabled", True)
        if not enabled or expert_category == ml_category:
            return expert_category
        if priority_score >= 88:
            return expert_category
        priority_order = {"IMMEDIATE": 3, "SHORT_TERM": 2, "MEDIUM_TERM": 1}
        return (
            expert_category
            if priority_order[expert_category] >= priority_order[ml_category]
            else ml_category
        )

    def _get_time_horizon_details(self, category: str) -> Dict[str, Any]:
        horizons = {
            "IMMEDIATE": self.time_horizons.get("immediate", {}),
            "SHORT_TERM": self.time_horizons.get("short_term", {}),
            "MEDIUM_TERM": self.time_horizons.get("medium_term", {}),
        }
        return horizons.get(category, {})

    def _get_calculation_breakdown(self, features: Dict[str, Any]) -> Dict[str, Any]:
        weights = get_priority_weights()
        hazard_intensity = self._calculate_hazard_intensity(features)
        population_vulnerability = self._calculate_population_vulnerability(features)
        access_limitations = self._calculate_access_limitations(features)
        disaster_history = self._calculate_disaster_history(features)
        return {
            "weights": weights,
            "component_scores": {
                "hazard_intensity": round(hazard_intensity, 2),
                "population_vulnerability": round(population_vulnerability, 2),
                "access_limitations": round(access_limitations, 2),
                "disaster_history": round(disaster_history, 2),
            },
            "weighted_contributions": {
                "hazard_intensity": round(
                    hazard_intensity * weights["hazard_intensity"], 2
                ),
                "population_vulnerability": round(
                    population_vulnerability * weights["population_vulnerability"], 2
                ),
                "access_limitations": round(
                    access_limitations * weights["access_limitations"], 2
                ),
                "disaster_history": round(
                    disaster_history * weights["disaster_history"], 2
                ),
            },
            "evacuation_time_hours": features.get("evacuation_time_hours"),
        }

    def predict_batch(
        self, habitations_list: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        results = []
        for habitation in habitations_list:
            try:
                results.append(self.predict(habitation))
            except Exception as exc:
                logger.error("Error predicting habitation: %s", exc)
                results.append(
                    {
                        "error": str(exc),
                        "priority_score": None,
                        "priority_category": "UNKNOWN",
                        "habitation_id": habitation.get("habitation_id", "unknown"),
                    }
                )
        return results

    def get_feature_importance(self) -> Dict[str, float]:
        return {
            "hazard_intensity": 35.0,
            "population_vulnerability": 30.0,
            "access_limitations": 20.0,
            "disaster_history": 15.0,
        }


priority_classifier = PriorityClassifier()
model_registry.register_model(
    priority_classifier,
    {
        "description": "Hybrid operational scorecard for habitation relocation priority",
        "model_type": "hybrid_scorecard",
        "supported_categories": ["IMMEDIATE", "SHORT_TERM", "MEDIUM_TERM"],
    },
)
