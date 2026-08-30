"""
Live GIS decision engine.

Pulls current meteorology (Open-Meteo), terrain (grid elevation differences),
and OSM habitations/shelters (Overpass). Scores cells with the hazard model,
clusters Red Zones, ranks habitations, and bottleneck-evaluates candidate sites.
"""

from __future__ import annotations

import hashlib
import logging
import math
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import requests

from app.core.config import settings
from app.ml.capacity_evaluator import capacity_evaluator
from app.ml.hazard_predictor import hazard_predictor
from app.ml.priority_classifier import priority_classifier
from app.services.demo_scenarios import build_demo_snapshot, inspect_demo_point
from app.services.field_updates import field_update_store

logger = logging.getLogger(__name__)

INDIA_BBOX = (6.5, 68.0, 37.1, 97.4)  # south, west, north, east
OPEN_METEO = "https://api.open-meteo.com/v1/forecast"
FLOOD_API = "https://flood-api.open-meteo.com/v1/flood"
OVERPASS_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
USER_AGENT = "DisasterNet-SDMA/3.0 (gis-dss; educational)"

_CACHE: Dict[str, Tuple[float, Dict[str, Any]]] = {}
_CACHE_TTL = 180.0


def _cache_get(key: str) -> Optional[Dict[str, Any]]:
    hit = _CACHE.get(key)
    if not hit:
        return None
    ts, payload = hit
    if time.time() - ts > _CACHE_TTL:
        _CACHE.pop(key, None)
        return None
    return payload


def _cache_set(key: str, payload: Dict[str, Any]) -> None:
    _CACHE[key] = (time.time(), payload)


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def clip_bbox_to_india(
    south: float, west: float, north: float, east: float
) -> Tuple[float, float, float, float]:
    s, w, n, e = INDIA_BBOX
    south = max(s, min(south, n))
    north = max(s, min(north, n))
    west = max(w, min(west, e))
    east = max(w, min(east, e))
    if north - south < 0.15:
        north = min(n, south + 0.15)
    if east - west < 0.15:
        east = min(e, west + 0.15)
    return south, west, north, east


def _grid_points(
    south: float, west: float, north: float, east: float, nx: int, ny: int
) -> List[Tuple[float, float]]:
    lats = np.linspace(south, north, ny)
    lons = np.linspace(west, east, nx)
    return [(float(lat), float(lon)) for lat in lats for lon in lons]


def _sum_precip(hourly: Dict[str, Any], hours: int) -> float:
    series = hourly.get("precipitation") or []
    if not series:
        return 0.0
    window = series[-hours:] if len(series) >= hours else series
    total = 0.0
    for v in window:
        if v is not None:
            total += float(v)
    return total


def _mean_soil(hourly: Dict[str, Any]) -> float:
    series = hourly.get("soil_moisture_0_to_7cm") or []
    vals = [float(v) for v in series[-24:] if v is not None]
    if not vals:
        return 0.35
    return max(0.0, min(1.0, sum(vals) / len(vals)))


def fetch_meteo_batch(points: List[Tuple[float, float]]) -> List[Dict[str, Any]]:
    if not points:
        return []
    lats = ",".join(f"{p[0]:.4f}" for p in points)
    lons = ",".join(f"{p[1]:.4f}" for p in points)
    params = {
        "latitude": lats,
        "longitude": lons,
        "current": "precipitation,rain,relative_humidity_2m,wind_speed_10m,weather_code,temperature_2m",
        "hourly": "precipitation,soil_moisture_0_to_7cm",
        "past_days": 3,
        "forecast_days": 1,
        "timezone": "auto",
    }
    resp = requests.get(
        OPEN_METEO, params=params, timeout=25, headers={"User-Agent": USER_AGENT}
    )
    if resp.status_code >= 400:
        params["hourly"] = "precipitation"
        resp = requests.get(
            OPEN_METEO, params=params, timeout=25, headers={"User-Agent": USER_AGENT}
        )
    resp.raise_for_status()
    data = resp.json()
    blocks = data if isinstance(data, list) else [data]
    out: List[Dict[str, Any]] = []
    for i, block in enumerate(blocks):
        lat, lon = (
            points[i]
            if i < len(points)
            else (block.get("latitude"), block.get("longitude"))
        )
        hourly = block.get("hourly") or {}
        current = block.get("current") or {}
        precip_24 = _sum_precip(hourly, 24)
        precip_72 = _sum_precip(hourly, 72)
        out.append(
            {
                "latitude": float(lat),
                "longitude": float(lon),
                "elevation": float(block.get("elevation") or 0.0),
                "precipitation_24h_mm": precip_24,
                "precipitation_72h_mm": precip_72,
                "precipitation_current_mm": float(
                    current.get("precipitation") or current.get("rain") or 0.0
                ),
                "humidity": float(current.get("relative_humidity_2m") or 60.0),
                "wind_speed_kmh": float(current.get("wind_speed_10m") or 0.0),
                "temperature_celsius": float(current.get("temperature_2m") or 0.0),
                "weather_code": int(current.get("weather_code") or 0),
                "soil_moisture_index": _mean_soil(hourly),
            }
        )
    return out


def fetch_river_discharge(
    points: List[Tuple[float, float]],
) -> Dict[Tuple[float, float], float]:
    """Best-effort flood signal; ignore failures."""
    result: Dict[Tuple[float, float], float] = {}
    try:
        sample = points[:: max(1, len(points) // 12)][:12]
        lats = ",".join(f"{p[0]:.4f}" for p in sample)
        lons = ",".join(f"{p[1]:.4f}" for p in sample)
        resp = requests.get(
            FLOOD_API,
            params={
                "latitude": lats,
                "longitude": lons,
                "daily": "river_discharge",
                "forecast_days": 3,
            },
            timeout=20,
            headers={"User-Agent": USER_AGENT},
        )
        if resp.status_code != 200:
            return result
        data = resp.json()
        blocks = data if isinstance(data, list) else [data]
        for i, block in enumerate(blocks):
            daily = (block.get("daily") or {}).get("river_discharge") or []
            vals = [float(v) for v in daily if v is not None]
            key = sample[i]
            result[key] = max(vals) if vals else 0.0
    except Exception as exc:
        logger.warning("Flood API unavailable: %s", exc)
    return result


def _slope_from_neighbors(
    cells: List[Dict[str, Any]], idx: int, nx: int, ny: int
) -> float:
    """Percent slope from neighboring DEM samples (rise/run)."""
    row, col = divmod(idx, nx) if False else (idx // nx, idx % nx)
    # grid is lat-major: index = lat_i * nx + lon_j
    lat_i = idx // nx
    lon_j = idx % nx
    center = cells[idx]
    neighbors = []
    for di, dj in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        ni, nj = lat_i + di, lon_j + dj
        if 0 <= ni < ny and 0 <= nj < nx:
            neighbors.append(cells[ni * nx + nj])
    if not neighbors:
        return 2.0
    rises = []
    for nb in neighbors:
        dist_m = (
            _haversine_km(
                center["latitude"], center["longitude"], nb["latitude"], nb["longitude"]
            )
            * 1000.0
        )
        if dist_m < 1:
            continue
        rises.append(abs(center["elevation"] - nb["elevation"]) / dist_m * 100.0)
    if not rises:
        return 2.0
    return float(min(55.0, max(rises)))


def classify_hazard(
    elev: float, slope: float, precip_24: float, lon: float, discharge: float
) -> str:
    coastal = elev < 25 and (lon <= 73.5 or lon >= 80.0)
    if precip_24 >= 100 and slope >= 12:
        return "CLOUDBURST"
    if slope >= 18 and (precip_24 >= 25 or elev >= 600):
        return "LANDSLIDE"
    if coastal and (precip_24 >= 20 or elev < 12):
        return "COASTAL_EROSION"
    if elev < 120 and (precip_24 >= 20 or discharge > 200):
        return "FLOOD"
    if precip_24 >= 40:
        return "FLOOD"
    if slope >= 12:
        return "LANDSLIDE"
    return "FLOOD"


def _vegetation_from_elev_slope(elev: float, slope: float) -> float:
    # Rough NDVI proxy: denser cover in mid-elevation moderate slopes.
    if elev < 50:
        return 0.35
    if elev > 2500:
        return 0.2
    return float(max(0.15, min(0.85, 0.55 - slope / 120.0)))


def score_grid_cells(
    cells: List[Dict[str, Any]],
    nx: int,
    ny: int,
    discharge_map: Dict[Tuple[float, float], float],
) -> List[Dict[str, Any]]:
    if not hazard_predictor.is_loaded:
        hazard_predictor.load_model()

    scored = []
    for idx, cell in enumerate(cells):
        slope = _slope_from_neighbors(cells, idx, nx, ny)
        key = (
            min(
                discharge_map.keys(),
                key=lambda k: _haversine_km(
                    cell["latitude"], cell["longitude"], k[0], k[1]
                ),
                default=None,
            )
            if discharge_map
            else None
        )
        discharge = discharge_map.get(key, 0.0) if key else 0.0
        hazard_type = classify_hazard(
            cell["elevation"],
            slope,
            cell["precipitation_24h_mm"],
            cell["longitude"],
            discharge,
        )
        lithology = (
            "SHALE"
            if slope > 20
            else ("BASALT" if cell["elevation"] < 80 else "GRANITE")
        )
        features = {
            "precipitation_24h_mm": cell["precipitation_24h_mm"],
            "precipitation_72h_mm": cell["precipitation_72h_mm"],
            "slope_percentage": slope,
            "elevation": cell["elevation"],
            "lithology": lithology,
            "soil_moisture_index": cell["soil_moisture_index"],
            "vegetation_index": _vegetation_from_elev_slope(cell["elevation"], slope),
            "hazard_type": hazard_type.lower(),
        }
        pred = hazard_predictor.predict(features)
        # Blend model with physical drivers so live rain actually moves the map.
        physical = min(
            100.0,
            cell["precipitation_24h_mm"] * 0.55
            + cell["precipitation_72h_mm"] * 0.12
            + slope * 0.9
            + (25.0 if cell["elevation"] < 40 else 0.0)
            + min(20.0, discharge / 40.0),
        )
        risk = min(100.0, 0.45 * float(pred["risk_score"]) + 0.55 * physical)
        pred["risk_score"] = round(risk, 2)
        pred["is_red_zone"] = risk >= 55.0
        pred["risk_level"] = (
            "CRITICAL"
            if risk >= 85
            else "HIGH"
            if risk >= 70
            else "MEDIUM"
            if risk >= 50
            else "LOW"
        )
        scored.append(
            {
                **cell,
                **pred,
                "slope_percentage": round(slope, 2),
                "hazard_type": hazard_type,
                "river_discharge": discharge,
            }
        )
    return scored


def _cell_polygon(lat: float, lon: float, dlat: float, dlon: float) -> str:
    hs, hw = dlat / 2.0, dlon / 2.0
    ring = [
        (lon - hw, lat - hs),
        (lon + hw, lat - hs),
        (lon + hw, lat + hs),
        (lon - hw, lat + hs),
        (lon - hw, lat - hs),
    ]
    return "POLYGON((" + ", ".join(f"{x:.5f} {y:.5f}" for x, y in ring) + "))"


def build_red_zones(
    scored: List[Dict[str, Any]], dlat: float, dlon: float
) -> List[Dict[str, Any]]:
    high = [c for c in scored if c.get("is_red_zone")]
    if not high:
        return []
    try:
        from sklearn.cluster import DBSCAN

        coords = np.array([[c["latitude"], c["longitude"]] for c in high])
        eps = max(dlat, dlon) * 1.35
        clustering = DBSCAN(eps=max(eps, 0.08), min_samples=1).fit(coords)
        clusters: Dict[int, List[Dict[str, Any]]] = {}
        for i, label in enumerate(clustering.labels_):
            clusters.setdefault(int(label), []).append(high[i])
    except Exception:
        clusters = {i: [c] for i, c in enumerate(high)}

    zones = []
    for cid, members in clusters.items():
        if cid == -1:
            continue
        avg_risk = sum(m["risk_score"] for m in members) / len(members)
        lat = sum(m["latitude"] for m in members) / len(members)
        lon = sum(m["longitude"] for m in members) / len(members)
        hazard = max(members, key=lambda m: m["risk_score"])["hazard_type"]
        try:
            from shapely.geometry import MultiPoint

            hull = MultiPoint(
                [(m["longitude"], m["latitude"]) for m in members]
            ).convex_hull
            if hull.geom_type == "Point":
                wkt = _cell_polygon(lat, lon, dlat, dlon)
            else:
                wkt = hull.buffer(max(dlat, dlon) * 0.45).wkt
        except Exception:
            wkt = _cell_polygon(
                lat, lon, dlat * len(members) ** 0.5, dlon * len(members) ** 0.5
            )

        level = "CRITICAL" if avg_risk >= 85 else "HIGH" if avg_risk >= 70 else "MEDIUM"
        zones.append(
            {
                "zone_id": f"RZ_{cid}_{int(lat * 100)}_{int(lon * 100)}",
                "grid_id": f"GRID_{cid}",
                "latitude": lat,
                "longitude": lon,
                "risk_score": round(avg_risk, 2),
                "is_red_zone": True,
                "risk_level": level,
                "hazard_type": hazard,
                "geometry_wkt": wkt,
                "prediction_timestamp": datetime.now(timezone.utc).isoformat(),
                "model_version": hazard_predictor.model_version or "3.0.0",
                "time_horizon": "IMMEDIATE" if avg_risk >= 70 else "SHORT_TERM",
                "grid_count": len(members),
                "area_sq_km": round(
                    max(dlat, 0.05) * 111 * max(dlon, 0.05) * 111 * len(members), 2
                ),
            }
        )
    return zones


def _overpass_query(query: str) -> Dict[str, Any]:
    last_err = None
    for url in OVERPASS_ENDPOINTS:
        try:
            resp = requests.post(
                url,
                data={"data": query},
                timeout=40,
                headers={"User-Agent": USER_AGENT},
            )
            if resp.status_code == 200:
                return resp.json()
            last_err = f"{url} HTTP {resp.status_code}"
        except Exception as exc:
            last_err = str(exc)
    logger.warning("Overpass failed: %s", last_err)
    return {"elements": []}


def _element_coord(el: Dict[str, Any]) -> Optional[Tuple[float, float]]:
    if "lat" in el and "lon" in el:
        return float(el["lat"]), float(el["lon"])
    center = el.get("center")
    if center:
        return float(center["lat"]), float(center["lon"])
    return None


def fetch_habitations(
    bboxes: List[Tuple[float, float, float, float]],
) -> List[Dict[str, Any]]:
    elements = []
    for south, west, north, east in bboxes:
        q = f"""
        [out:json][timeout:25];
        (
          node["place"~"city|town|village|hamlet"]({south},{west},{north},{east});
        );
        out body 40;
        """
        data = _overpass_query(q)
        elements.extend(data.get("elements") or [])
    seen = set()
    places = []
    for el in elements:
        coord = _element_coord(el)
        if not coord:
            continue
        lat, lon = coord
        key = (round(lat, 4), round(lon, 4))
        if key in seen:
            continue
        seen.add(key)
        tags = el.get("tags") or {}
        name = tags.get("name") or tags.get("name:en") or f"Settlement {el.get('id')}"
        place = tags.get("place") or "village"
        pop = tags.get("population")
        try:
            population = int(str(pop).replace(",", "")) if pop else None
        except ValueError:
            population = None
        if population is None:
            population = {
                "city": 80000,
                "town": 18000,
                "village": 2200,
                "hamlet": 450,
            }.get(place, 1500)
        state = tags.get("is_in:state") or tags.get("addr:state") or ""
        district = (
            tags.get("addr:district")
            or tags.get("is_in:district")
            or tags.get("name")
            or ""
        )
        places.append(
            {
                "osm_id": el.get("id"),
                "village_name": name,
                "place": place,
                "latitude": lat,
                "longitude": lon,
                "total_population": int(population),
                "state_code": (state[:2] or "IN").upper(),
                "district_name": district or state or "India",
            }
        )
    return places[:80]


def fetch_candidate_sites(
    bboxes: List[Tuple[float, float, float, float]],
) -> List[Dict[str, Any]]:
    elements = []
    for south, west, north, east in bboxes:
        q = f"""
        [out:json][timeout:25];
        (
          nwr["amenity"="hospital"]({south},{west},{north},{east});
          nwr["amenity"="school"]({south},{west},{north},{east});
          nwr["amenity"="college"]({south},{west},{north},{east});
          nwr["amenity"="community_centre"]({south},{west},{north},{east});
          nwr["amenity"="community_center"]({south},{west},{north},{east});
          nwr["emergency"="assembly_point"]({south},{west},{north},{east});
          nwr["amenity"="shelter"]({south},{west},{north},{east});
        );
        out center 50;
        """
        data = _overpass_query(q)
        elements.extend(data.get("elements") or [])
    seen = set()
    sites = []
    for el in elements:
        coord = _element_coord(el)
        if not coord:
            continue
        lat, lon = coord
        key = (round(lat, 4), round(lon, 4))
        if key in seen:
            continue
        seen.add(key)
        tags = el.get("tags") or {}
        amenity = (tags.get("amenity") or tags.get("emergency") or "school").lower()
        name = (
            tags.get("name")
            or tags.get("name:en")
            or f"{amenity.title()} {el.get('id')}"
        )
        if amenity in ("hospital", "clinic"):
            stype, beds, medical = "HOSPITAL", int(tags.get("beds") or 180), "FULL"
        elif amenity in ("school", "college", "university"):
            stype, beds, medical = "SCHOOL", 420, "BASIC"
        elif "community" in amenity:
            stype, beds, medical = "COMMUNITY_CENTER", 280, "LIMITED"
        else:
            stype, beds, medical = "GOVT_BUILDING", 200, "BASIC"
        sites.append(
            {
                "osm_id": el.get("id"),
                "shelter_name": name,
                "shelter_type": stype,
                "latitude": lat,
                "longitude": lon,
                "total_capacity": beds,
                "physical_beds": beds,
                "medical_facility_depth": medical,
                "district_name": tags.get("addr:district")
                or tags.get("addr:city")
                or "",
                "state_code": (tags.get("addr:state") or "IN")[:2].upper(),
                "has_toilets": True,
                "water_supply": amenity == "hospital",
            }
        )
    return sites[:60]


def _nearest_zone_km(lat: float, lon: float, zones: List[Dict[str, Any]]) -> float:
    if not zones:
        return 50.0
    return min(_haversine_km(lat, lon, z["latitude"], z["longitude"]) for z in zones)


def rank_habitations(
    places: List[Dict[str, Any]],
    zones: List[Dict[str, Any]],
    meteo_index: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    if not priority_classifier.is_loaded:
        priority_classifier.load_model()

    ranked = []
    for p in places:
        nearest_m = (
            min(
                meteo_index,
                key=lambda c: _haversine_km(
                    p["latitude"], p["longitude"], c["latitude"], c["longitude"]
                ),
            )
            if meteo_index
            else {}
        )
        prox = _nearest_zone_km(p["latitude"], p["longitude"], zones)
        pop = p["total_population"]
        features = {
            "habitation_id": f"OSM_{p.get('osm_id')}",
            "latitude": p["latitude"],
            "longitude": p["longitude"],
            "total_population": pop,
            "elderly_percentage": 9.0,
            "child_percentage": 14.0,
            "disability_percentage": 2.2,
            "population_density_per_sqkm": min(2000.0, pop / 2.5),
            "economic_status": "MIXED",
            "road_connectivity": "PAVED"
            if p.get("place") in ("city", "town")
            else "UNPAVED",
            "road_distance_km": 3.0 if p.get("place") == "hamlet" else 1.0,
            "nearest_emergency_km": max(2.0, prox),
            "communication_availability": "MOBILE",
            "evacuation_route_status": "DAMAGED" if prox < 2 else "CLEAR",
            "evacuation_time_hours": 2.0 + prox / 8.0,
            "red_zone_proximity_km": prox,
            "current_risk_score": float(nearest_m.get("risk_score") or 0),
            "current_red_zone_id": zones[0]["zone_id"]
            if prox < 1.5 and zones
            else None,
            "hazard_history": [],
            "disaster_frequency_score": min(
                80.0, float(nearest_m.get("precipitation_72h_mm") or 0)
            ),
        }
        assessment = priority_classifier.predict(features)
        child = int(pop * 0.14)
        elderly = int(pop * 0.09)
        ranked.append(
            {
                "habitation_id": features["habitation_id"],
                "village_name": p["village_name"],
                "state_code": p.get("state_code") or "IN",
                "district_name": p.get("district_name") or "",
                "latitude": p["latitude"],
                "longitude": p["longitude"],
                "total_population": pop,
                "male_population": pop // 2,
                "female_population": pop - pop // 2,
                "population_0_6": child,
                "population_60_plus": elderly,
                "literacy_rate": 72.0,
                "priority_score": assessment["priority_score"],
                "priority_category": assessment["priority_category"],
                "expert_category": assessment["expert_category"],
                "ml_category": assessment["ml_category"],
                "proximity_to_hazard_km": round(prox, 2),
                "elevation": float(nearest_m.get("elevation") or 0),
                "slope_percentage": float(nearest_m.get("slope_percentage") or 0),
                "has_access_road": p.get("place") != "hamlet",
                "path_status": features["evacuation_route_status"],
                "geometry_wkt": f"POINT({p['longitude']} {p['latitude']})",
                "assessment_timestamp": datetime.now(timezone.utc).isoformat(),
                "model_version": assessment.get("model_version", "3.0.0"),
                "calculation_breakdown": assessment.get("calculation_breakdown"),
            }
        )
    ranked.sort(key=lambda r: r["priority_score"], reverse=True)
    return ranked


def evaluate_sites(
    sites: List[Dict[str, Any]], zones: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    if not capacity_evaluator.is_loaded:
        capacity_evaluator.load_model()
    zone_wkts = [z["geometry_wkt"] for z in zones if z.get("geometry_wkt")]
    evaluated = []
    for s in sites:
        prox = _nearest_zone_km(s["latitude"], s["longitude"], zones)
        water_days = (
            14.0 if s.get("water_supply") or s["shelter_type"] == "HOSPITAL" else 8.0
        )
        food_days = 10.0 if s["shelter_type"] in ("SCHOOL", "HOSPITAL") else 7.0
        features = {
            "shelter_id": f"OSM_{s.get('osm_id')}",
            "total_capacity": s["total_capacity"],
            "current_occupancy": 0,
            "physical_beds": s["physical_beds"],
            "water_sufficiency_days": water_days,
            "food_ration_storage_days": food_days,
            "medical_facility_depth": s["medical_facility_depth"],
            "geometry": f"POINT({s['longitude']} {s['latitude']})",
            "road_accessibility": "GOOD",
            "nearest_red_zone_distance_km": prox,
            "electricity": True,
            "water_supply": bool(s.get("water_supply")),
            "sanitation_facilities": True,
        }
        suit = capacity_evaluator.evaluate_shelter_suitability(features, zone_wkts)
        cap = suit["capacity_evaluation"]
        safe = (
            suit["safety_evaluation"].get("safety_check_passed", True) and prox >= 1.0
        )
        evaluated.append(
            {
                "shelter_id": features["shelter_id"],
                "shelter_name": s["shelter_name"],
                "shelter_type": s["shelter_type"],
                "state_code": s.get("state_code") or "IN",
                "district_name": s.get("district_name") or "",
                "latitude": s["latitude"],
                "longitude": s["longitude"],
                "total_capacity": cap["total_capacity"],
                "effective_capacity": cap["effective_capacity"],
                "available_capacity": cap["available_capacity"],
                "utilization_percentage": cap["utilization_percentage"],
                "current_population": 0,
                "water_available_liters": int(water_days * s["total_capacity"] * 15),
                "food_available_kg": int(food_days * s["total_capacity"] * 0.8),
                "medical_kits_available": 40
                if s["medical_facility_depth"] == "FULL"
                else 12,
                "generator_fuel_liters": 200 if s["shelter_type"] == "HOSPITAL" else 80,
                "capacity_constraint": cap["capacity_constraint"],
                "capacity_status": cap["capacity_status"],
                "is_in_safe_zone": safe,
                "safety_buffer_km": round(prox, 2),
                "overall_suitability": suit["overall_suitability"],
                "safety_score": suit["safety_score"],
                "has_generator": s["shelter_type"] == "HOSPITAL",
                "has_medical_facility": s["medical_facility_depth"]
                in ("FULL", "BASIC"),
                "has_kitchen": s["shelter_type"]
                in ("SCHOOL", "COMMUNITY_CENTER", "HOSPITAL"),
                "has_toilets": True,
                "access_road_status": "CLEAR",
                "geometry_wkt": features["geometry"],
                "evaluation_timestamp": datetime.now(timezone.utc).isoformat(),
                "model_version": "3.0.0",
            }
        )
    evaluated.sort(
        key=lambda r: (0 if r["is_in_safe_zone"] else 1, -r["available_capacity"])
    )
    return evaluated


def _focus_bboxes(
    zones: List[Dict[str, Any]],
    fallback: Tuple[float, float, float, float],
    limit: int = 3,
) -> List[Tuple[float, float, float, float]]:
    south, west, north, east = fallback
    span = (north - south) * (east - west)
    if span <= 2.5:
        return [fallback]
    boxes = []
    for z in sorted(zones, key=lambda x: x["risk_score"], reverse=True)[:limit]:
        pad = 0.28
        boxes.append(
            clip_bbox_to_india(
                z["latitude"] - pad,
                z["longitude"] - pad,
                z["latitude"] + pad,
                z["longitude"] + pad,
            )
        )
    if not boxes:
        mid_lat = (south + north) / 2
        mid_lon = (west + east) / 2
        boxes.append(
            clip_bbox_to_india(
                mid_lat - 0.4, mid_lon - 0.4, mid_lat + 0.4, mid_lon + 0.4
            )
        )
    return boxes


def inspect_point(lat: float, lon: float) -> Dict[str, Any]:
    """Inspect an arbitrary Indian coordinate from either demo scenario data or live sources."""
    if settings.demo_mode:
        return inspect_demo_point(lat, lon)
    pad = 0.14
    south, west, north, east = clip_bbox_to_india(
        lat - pad, lon - pad, lat + pad, lon + pad
    )
    nx = ny = 3
    points = _grid_points(south, west, north, east, nx, ny)
    points[len(points) // 2] = (lat, lon)
    cells = fetch_meteo_batch(points)
    scored = score_grid_cells(cells, nx, ny, {})
    cell = min(
        scored, key=lambda c: _haversine_km(lat, lon, c["latitude"], c["longitude"])
    )
    dlat = (north - south) / max(ny - 1, 1)
    dlon = (east - west) / max(nx - 1, 1)
    zones = build_red_zones(scored, dlat, dlon)
    sites = evaluate_sites(fetch_candidate_sites([(south, west, north, east)]), zones)
    nearest = None
    dist = None
    if sites:
        nearest = min(
            sites, key=lambda s: _haversine_km(lat, lon, s["latitude"], s["longitude"])
        )
        dist = _haversine_km(lat, lon, nearest["latitude"], nearest["longitude"])
    return {
        "latitude": lat,
        "longitude": lon,
        "is_within_india": True,
        "risk_score": cell["risk_score"],
        "is_red_zone": cell["is_red_zone"],
        "risk_level": cell["risk_level"],
        "hazard_type": cell["hazard_type"],
        "urgency": "IMMEDIATE"
        if cell["risk_score"] >= 70
        else ("SHORT_TERM" if cell["is_red_zone"] else "MEDIUM_TERM"),
        "elevation": cell["elevation"],
        "slope_percentage": cell["slope_percentage"],
        "precipitation_24h_mm": cell["precipitation_24h_mm"],
        "precipitation_72h_mm": cell["precipitation_72h_mm"],
        "soil_moisture_index": cell["soil_moisture_index"],
        "temperature_celsius": cell.get("temperature_celsius"),
        "wind_speed_kmh": cell.get("wind_speed_kmh"),
        "humidity": cell.get("humidity"),
        "nearest_shelter": nearest,
        "nearest_shelter_km": round(dist, 2) if dist is not None else None,
        "red_zone_count_nearby": len(zones),
        "model_version": cell.get("model_version"),
        "inspected_at": datetime.now(timezone.utc).isoformat(),
        "data_sources": {
            "meteorology": "Open-Meteo",
            "terrain": "Open-Meteo DEM + neighbor slope",
            "sites": "OpenStreetMap Overpass",
        },
    }


def evaluate_candidate_site(
    *,
    latitude: float,
    longitude: float,
    site_name: str,
    district_name: str = "",
    state_code: str = "IN",
    hectares: float = 2.0,
    road_distance_km: float = 1.0,
    water_supply: bool = True,
    sanitation_facilities: bool = True,
    electricity: bool = True,
    medical_facility_depth: str = "BASIC",
) -> Dict[str, Any]:
    local = inspect_point(latitude, longitude)
    snapshot = build_snapshot(
        south=latitude - 0.32,
        west=longitude - 0.32,
        north=latitude + 0.32,
        east=longitude + 0.32,
    )
    zones = snapshot.get("red_zones", [])
    nearest_red_zone_distance_km = _nearest_zone_km(latitude, longitude, zones)

    terrain_score = 100.0
    slope = float(local.get("slope_percentage") or 0.0)
    elevation = float(local.get("elevation") or 0.0)
    risk_score = float(local.get("risk_score") or 0.0)
    if slope < 1.0:
        terrain_score -= 20.0
    elif slope > 15.0:
        terrain_score -= min(65.0, (slope - 15.0) * 3.0)
    if elevation < 20.0:
        terrain_score -= 18.0
    if road_distance_km > 1.0:
        terrain_score -= min(20.0, (road_distance_km - 1.0) * 4.0)
    safety_score = max(
        0.0,
        min(
            100.0,
            100.0 - risk_score * 0.55 + min(25.0, nearest_red_zone_distance_km * 4.0),
        ),
    )
    infra_bonus = (
        (6.0 if electricity else 0.0)
        + (6.0 if water_supply else 0.0)
        + (6.0 if sanitation_facilities else 0.0)
    )
    terrain_score = max(0.0, min(100.0, terrain_score + infra_bonus))

    population_capacity = max(50, int(hectares * 1250))
    water_days = 14.0 if water_supply else 5.0
    food_days = 10.0 if hectares >= 2.0 else 6.0
    physical_beds = max(50, int(population_capacity * 0.82))
    candidate_id = f"CAND_{int(latitude * 10000)}_{int(longitude * 10000)}"
    geometry = f"POINT({longitude} {latitude})"
    shelter_features = {
        "shelter_id": candidate_id,
        "total_capacity": population_capacity,
        "current_occupancy": 0,
        "physical_beds": physical_beds,
        "water_sufficiency_days": water_days,
        "food_ration_storage_days": food_days,
        "medical_facility_depth": medical_facility_depth,
        "geometry": geometry,
        "road_accessibility": "GOOD"
        if road_distance_km <= 1.0
        else ("FAIR" if road_distance_km <= 4.0 else "POOR"),
        "nearest_red_zone_distance_km": nearest_red_zone_distance_km,
        "electricity": electricity,
        "water_supply": water_supply,
        "sanitation_facilities": sanitation_facilities,
    }
    suitability = capacity_evaluator.evaluate_shelter_suitability(
        shelter_features,
        [z["geometry_wkt"] for z in zones if z.get("geometry_wkt")],
    )
    overall_score = max(
        0.0,
        min(
            100.0,
            0.45 * float(suitability.get("safety_score") or 0.0)
            + 0.30 * terrain_score
            + 0.25 * max(0.0, 100.0 - risk_score),
        ),
    )
    suitability_band = suitability.get("overall_suitability") or "MARGINAL"
    recommendation = (
        "DESIGNATE_FOR_RELOCATION"
        if suitability_band in {"HIGHLY_SUITABLE", "SUITABLE"} and overall_score >= 70
        else "REVIEW_WITH_MITIGATION"
        if overall_score >= 50
        else "REJECT_SITE"
    )

    return {
        "candidate_site_id": candidate_id,
        "site_name": site_name,
        "district_name": district_name,
        "state_code": state_code,
        "latitude": latitude,
        "longitude": longitude,
        "hectares": hectares,
        "road_distance_km": road_distance_km,
        "nearest_red_zone_distance_km": round(nearest_red_zone_distance_km, 2),
        "terrain": {
            "elevation_m": round(elevation, 1),
            "slope_percentage": round(slope, 2),
        },
        "hazard_context": {
            "risk_score": round(risk_score, 2),
            "risk_level": local.get("risk_level"),
            "hazard_type": local.get("hazard_type"),
            "precipitation_24h_mm": local.get("precipitation_24h_mm"),
            "precipitation_72h_mm": local.get("precipitation_72h_mm"),
            "soil_moisture_index": local.get("soil_moisture_index"),
        },
        "capacity": {
            "planned_population_capacity": population_capacity,
            "physical_beds": physical_beds,
            "water_available_liters": int(water_days * population_capacity * 15),
            "food_available_kg": int(food_days * population_capacity * 0.8),
        },
        "capacity_evaluation": suitability.get("capacity_evaluation"),
        "safety_evaluation": suitability.get("safety_evaluation"),
        "safety_score": suitability.get("safety_score"),
        "terrain_score": round(terrain_score, 2),
        "overall_score": round(overall_score, 2),
        "overall_suitability": suitability_band,
        "recommendation": recommendation,
        "geometry_wkt": geometry,
        "evaluated_at": datetime.now(timezone.utc).isoformat(),
        "data_sources": snapshot.get("data_sources", {}),
    }


def build_snapshot(
    south: float = INDIA_BBOX[0],
    west: float = INDIA_BBOX[1],
    north: float = INDIA_BBOX[2],
    east: float = INDIA_BBOX[3],
    nx: int = 7,
    ny: int = 7,
) -> Dict[str, Any]:
    south, west, north, east = clip_bbox_to_india(south, west, north, east)
    if settings.demo_mode:
        snapshot = build_demo_snapshot(south=south, west=west, north=north, east=east)
        snapshot = field_update_store.apply_snapshot_overrides(snapshot)
        return snapshot
    span = max(north - south, east - west)
    if span < 1.5:
        nx = ny = 6
    elif span < 8:
        nx = ny = 7
    else:
        nx = ny = 8

    cache_key = hashlib.md5(
        f"{south:.3f}:{west:.3f}:{north:.3f}:{east:.3f}:{nx}:{ny}".encode()
    ).hexdigest()
    cached = _cache_get(cache_key)
    if cached:
        cached = dict(cached)
        cached["cache_hit"] = True
        return cached

    points = _grid_points(south, west, north, east, nx, ny)
    cells = fetch_meteo_batch(points)
    discharge = fetch_river_discharge(points)
    scored = score_grid_cells(cells, nx, ny, discharge)
    dlat = (north - south) / max(ny - 1, 1)
    dlon = (east - west) / max(nx - 1, 1)
    zones = build_red_zones(scored, dlat, dlon)
    boxes = _focus_bboxes(zones, (south, west, north, east))
    places = fetch_habitations(boxes)
    sites = fetch_candidate_sites(boxes)
    habitations = rank_habitations(places, zones, scored)
    shelters = evaluate_sites(sites, zones)

    worst = max(scored, key=lambda c: c["risk_score"]) if scored else None
    immediate = [h for h in habitations if h["priority_category"] == "IMMEDIATE"]
    snapshot = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "bbox": {"south": south, "west": west, "north": north, "east": east},
        "grid": {"nx": nx, "ny": ny, "cell_count": len(scored)},
        "data_sources": {
            "meteorology": "Open-Meteo forecast + 72h precipitation + soil moisture",
            "flood": "Open-Meteo GloFAS river discharge",
            "terrain": "Open-Meteo DEM samples; slope from neighbor finite difference",
            "habitations_shelters": "OpenStreetMap Overpass (live)",
            "models": "RandomForest hazard + hybrid priority + bottleneck capacity",
        },
        "alert": {
            "active": bool(zones),
            "headline": (
                f"{worst['hazard_type'].replace('_', ' ').title()} risk {worst['risk_score']:.0f}/100 "
                f"at {worst['latitude']:.2f}N, {worst['longitude']:.2f}E"
                if worst
                else "No high-risk cells in view"
            ),
            "detail": (
                f"{len(zones)} live Red Zones from current rainfall, terrain and discharge. "
                f"{len(immediate)} habitations classified Immediate (0-24h)."
                if worst
                else "Grid scored below red-zone threshold for this viewport."
            ),
            "worst_lat": worst["latitude"] if worst else None,
            "worst_lon": worst["longitude"] if worst else None,
            "worst_risk": worst["risk_score"] if worst else 0,
        },
        "summary": {
            "red_zone_count": len(zones),
            "habitation_count": len(habitations),
            "immediate_count": len(immediate),
            "short_term_count": len(
                [h for h in habitations if h["priority_category"] == "SHORT_TERM"]
            ),
            "medium_term_count": len(
                [h for h in habitations if h["priority_category"] == "MEDIUM_TERM"]
            ),
            "shelter_count": len(shelters),
            "safe_shelter_count": len([s for s in shelters if s["is_in_safe_zone"]]),
            "available_beds": sum(
                s["available_capacity"] for s in shelters if s["is_in_safe_zone"]
            ),
            "population_immediate": sum(h["total_population"] for h in immediate),
        },
        "red_zones": zones,
        "grid_cells": [
            {
                "latitude": c["latitude"],
                "longitude": c["longitude"],
                "risk_score": c["risk_score"],
                "is_red_zone": c["is_red_zone"],
                "hazard_type": c["hazard_type"],
                "precipitation_24h_mm": c["precipitation_24h_mm"],
                "elevation": c["elevation"],
                "slope_percentage": c["slope_percentage"],
            }
            for c in scored
        ],
        "habitations": habitations,
        "shelters": shelters,
        "cache_hit": False,
    }
    snapshot = field_update_store.apply_snapshot_overrides(snapshot)
    _cache_set(cache_key, snapshot)
    return snapshot
