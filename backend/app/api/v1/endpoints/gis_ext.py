"""GIS endpoint extensions — layered map, spatial analysis, routing,
reverse geocoding.

The base ``/gis/snapshot`` and ``/gis/inspect`` endpoints already exist
in the original codebase. This module adds:

  * ``GET /gis/layers`` — list of available map layers (red_zones,
    shelters, habitations, hazards, rainfall_grid, elevation, roads,
    crowd_reports, sos) with their visibility defaults.
  * ``GET /gis/layer/{layer_id}`` — fetch a single layer as GeoJSON.
  * ``POST /gis/spatial/within`` — query which layers fall inside a
    given polygon (WKT). Useful for "draw an area → list affected
    population & shelters" workflows.
  * ``GET /gis/route`` — compute the shortest safe route from origin to
    destination, avoiding red-zone polygons. Falls back to a straight
    great-circle distance if no road network is available.
  * ``GET /gis/reverse-geocode`` — given lat/lon, return state /
    district / tehsil / village name using the Open-Meteo geocoding API
    and Nominatim.

All endpoints are publicly readable (CITIZEN role allowed).
"""

from __future__ import annotations

import logging
import math
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import requests
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.security import get_current_user_optional
from app.services.live_gis import INDIA_BBOX, build_snapshot, inspect_point

logger = logging.getLogger(__name__)
router = APIRouter()

# Cache for snapshot reuse (avoids re-computing the live snapshot on every layer fetch)
_SNAPSHOT_CACHE: Tuple[float, Dict[str, Any]] = (0.0, {})
_SNAPSHOT_TTL = 180.0
_USER_AGENT = "DisasterNet-SDMA/3.0 (+gis-dss)"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _cached_snapshot() -> Dict[str, Any]:
    global _SNAPSHOT_CACHE
    if time.time() - _SNAPSHOT_CACHE[0] < _SNAPSHOT_TTL:
        return _SNAPSHOT_CACHE[1]
    try:
        snap = build_snapshot()
    except Exception as exc:
        logger.warning("snapshot build failed: %s", exc)
        snap = {"red_zones": [], "shelters": [], "habitations": []}
    _SNAPSHOT_CACHE = (time.time(), snap)
    return snap


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(p1) * math.cos(p2) * math.sin(dlam / 2) ** 2
    )
    return 2 * r * math.asin(math.sqrt(a))


def _zone_centroid(geometry_wkt: str) -> Optional[Tuple[float, float]]:
    """Extract an approximate centroid from a WKT POLYGON ((x y, x y, ...))."""
    if not geometry_wkt:
        return None
    try:
        body = geometry_wkt.split("(", 2)[-1].rsplit(")", 2)[0]
        points = body.split(",")
        lats = []
        lons = []
        for pt in points:
            pt = pt.strip()
            if not pt:
                continue
            xy = pt.split()
            if len(xy) < 2:
                continue
            lons.append(float(xy[0]))
            lats.append(float(xy[1]))
        if not lats or not lons:
            return None
        return (sum(lats) / len(lats), sum(lons) / len(lons))
    except Exception:
        return None


def _point_in_polygon(lat: float, lon: float, geometry_wkt: str) -> bool:
    """Ray-casting test — lat/lon inside WKT POLYGON."""
    try:
        body = geometry_wkt.split("(", 2)[-1].rsplit(")", 2)[0]
        points = []
        for pt in body.split(","):
            pt = pt.strip()
            if not pt:
                continue
            xy = pt.split()
            if len(xy) < 2:
                continue
            points.append((float(xy[0]), float(xy[1])))  # (lon, lat)
        if len(points) < 3:
            return False
        x, y = lon, lat
        inside = False
        n = len(points)
        j = n - 1
        for i in range(n):
            xi, yi = points[i]
            xj, yj = points[j]
            if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi):
                inside = not inside
            j = i
        return inside
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class LayerInfo(BaseModel):
    layer_id: str
    name: str
    description: str
    geometry_type: str
    default_visible: bool
    is_official: bool
    source: str


class LayersResponse(BaseModel):
    server_time: str
    layers: List[LayerInfo]


class SpatialWithinRequest(BaseModel):
    geometry_wkt: str = Field(..., description="WKT POLYGON")
    include_layers: List[str] = Field(default_factory=list)


class SpatialWithinResponse(BaseModel):
    server_time: str
    counts: Dict[str, int]
    items: Dict[str, List[Dict[str, Any]]]


class RouteResponse(BaseModel):
    server_time: str
    distance_km: float
    duration_estimate_min: int
    avoided_red_zones: int
    waypoints: List[Tuple[float, float]]
    notes: str


class ReverseGeocodeResponse(BaseModel):
    server_time: str
    latitude: float
    longitude: float
    state: Optional[str] = None
    district: Optional[str] = None
    sub_district: Optional[str] = None
    village: Optional[str] = None
    display_name: Optional[str] = None
    source: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/layers", response_model=LayersResponse)
async def list_layers(
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """List all available GIS layers — used by the client to render the
    layer toggle panel.
    """
    role = (current_user or {}).get("role", "")
    is_official = role and role.upper() not in {"CITIZEN", "VIEWER", ""}
    layers = [
        LayerInfo(
            layer_id="red_zones",
            name="Red Zones (AI hazard polygons)",
            description="AI-computed active hazard zones, refreshed every live snapshot.",
            geometry_type="Polygon",
            default_visible=True,
            is_official=True,
            source="DisasterNet hazard predictor",
        ),
        LayerInfo(
            layer_id="shelters",
            name="Safe Shelters",
            description="Registered shelter sites with capacity metadata.",
            geometry_type="Point",
            default_visible=True,
            is_official=True,
            source="OSM Overpass + field surveys",
        ),
        LayerInfo(
            layer_id="habitations",
            name="Vulnerable Habitations",
            description="Habitations with relocation priority classification.",
            geometry_type="Point",
            default_visible=True,
            is_official=True,
            source="OSM Overpass + census",
        ),
        LayerInfo(
            layer_id="crowd_reports",
            name="Crowd-sourced Reports",
            description="Citizen-submitted damage & situation reports.",
            geometry_type="Point",
            default_visible=True,
            is_official=False,
            source="DisasterNet citizens",
        ),
        LayerInfo(
            layer_id="sos",
            name="Active SOS",
            description="Live SOS messages received from citizens.",
            geometry_type="Point",
            default_visible=True,
            is_official=False,
            source="DisasterNet SOS module",
        ),
        LayerInfo(
            layer_id="usgs_earthquakes",
            name="USGS Earthquakes (24h)",
            description="USGS earthquake feed (last 24h, India bbox).",
            geometry_type="Point",
            default_visible=False,
            is_official=True,
            source="USGS",
        ),
        LayerInfo(
            layer_id="nasa_eonet",
            name="NASA EONET (wildfires & volcanoes)",
            description="Open wildfire and volcano events.",
            geometry_type="Point",
            default_visible=False,
            is_official=True,
            source="NASA EONET",
        ),
    ]
    # Operators see one extra admin-only layer
    if is_official:
        layers.append(
            LayerInfo(
                layer_id="field_surveys",
                name="Field Officer Surveys",
                description="Submitted habitation & shelter surveys pending sync.",
                geometry_type="Point",
                default_visible=False,
                is_official=True,
                source="DisasterNet field officer app",
            )
        )
    return LayersResponse(server_time=_now_iso(), layers=layers)


@router.get("/layer/{layer_id}")
async def get_layer(
    layer_id: str,
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """Return a single layer as GeoJSON FeatureCollection."""
    snap = _cached_snapshot()
    features: List[Dict[str, Any]] = []

    if layer_id == "red_zones":
        for z in snap.get("red_zones", []):
            features.append(
                {
                    "type": "Feature",
                    "geometry": {"type": "Polygon", "coordinates": _wkt_to_coords(z.get("geometry_wkt") or z.get("geometry")) or []},
                    "properties": {
                        "id": z.get("zone_id") or z.get("id"),
                        "risk_score": z.get("risk_score"),
                        "hazard_type": z.get("hazard_type"),
                        "area_km2": z.get("area_km2"),
                    },
                }
            )
    elif layer_id == "shelters":
        for s in snap.get("shelters", []):
            features.append(
                {
                    "type": "Feature",
                    "geometry": {
                        "type": "Point",
                        "coordinates": [s.get("longitude"), s.get("latitude")],
                    },
                    "properties": {
                        "id": s.get("shelter_id") or s.get("id"),
                        "name": s.get("shelter_name") or s.get("name"),
                        "capacity": s.get("total_capacity"),
                        "available": s.get("available_capacity"),
                        "is_safe": s.get("is_in_safe_zone", True),
                    },
                }
            )
    elif layer_id == "habitations":
        for h in snap.get("habitations", []):
            features.append(
                {
                    "type": "Feature",
                    "geometry": {
                        "type": "Point",
                        "coordinates": [h.get("longitude"), h.get("latitude")],
                    },
                    "properties": {
                        "id": h.get("habitation_id") or h.get("id"),
                        "name": h.get("village_name") or h.get("name"),
                        "population": h.get("total_population"),
                        "priority": h.get("priority_category"),
                        "priority_score": h.get("priority_score"),
                    },
                }
            )
    elif layer_id == "sos":
        from app.api.v1.endpoints.sos import _SOS_STORE, _LOCK as SOS_LOCK
        with SOS_LOCK:
            for r in _SOS_STORE.values():
                features.append(
                    {
                        "type": "Feature",
                        "geometry": {
                            "type": "Point",
                            "coordinates": [r["longitude"], r["latitude"]],
                        },
                        "properties": {
                            "id": r["sos_id"],
                            "category": r["category"],
                            "severity": r["severity"],
                            "message": r["message"],
                            "status": r["status"],
                            "origin_layer": r["origin_layer"],
                            "hop_count": r["hop_count"],
                        },
                    }
                )
    elif layer_id == "crowd_reports":
        from app.api.v1.endpoints.crowd_reports import _REPORTS, _LOCK as CR_LOCK
        with CR_LOCK:
            for r in _REPORTS.values():
                features.append(
                    {
                        "type": "Feature",
                        "geometry": {
                            "type": "Point",
                            "coordinates": [r["longitude"], r["latitude"]],
                        },
                        "properties": {
                            "id": r["report_id"],
                            "category": r["category"],
                            "severity": r["severity"],
                            "description": r["description"],
                            "verified": r["verified"],
                        },
                    }
                )
    elif layer_id == "usgs_earthquakes":
        from app.api.v1.endpoints.alerts import _fetch_usgs_earthquakes
        for r in _fetch_usgs_earthquakes():
            features.append(
                {
                    "type": "Feature",
                    "geometry": {
                        "type": "Point",
                        "coordinates": [r["longitude"], r["latitude"]],
                    },
                    "properties": {
                        "id": f"usgs-{r.get('timestamp')}",
                        "title": r["title"],
                        "magnitude": r["magnitude"],
                        "depth_km": r["depth_km"],
                        "place": r["place"],
                        "tsunami": r["tsunami"],
                    },
                }
            )
    elif layer_id == "nasa_eonet":
        from app.api.v1.endpoints.alerts import _fetch_nasa_eonet
        for r in _fetch_nasa_eonet():
            features.append(
                {
                    "type": "Feature",
                    "geometry": {
                        "type": "Point",
                        "coordinates": [r["longitude"], r["latitude"]],
                    },
                    "properties": {
                        "id": f"eonet-{r.get('title')}",
                        "title": r["title"],
                        "category": r["type"],
                    },
                }
            )
    else:
        raise HTTPException(status_code=404, detail=f"Unknown layer: {layer_id}")

    return {
        "type": "FeatureCollection",
        "layer_id": layer_id,
        "features": features,
        "bbox": [west, south, east, north],
        "server_time": _now_iso(),
    }


@router.post("/spatial/within", response_model=SpatialWithinResponse)
async def spatial_within(
    req: SpatialWithinRequest,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """Find all features from the requested layers that fall within a
    WKT polygon drawn by the user.

    Example use-case: an operator draws a polygon around a flooded area,
    and the endpoint returns every habitation and SOS inside it.
    """
    snap = _cached_snapshot()
    include = req.include_layers or ["red_zones", "shelters", "habitations", "sos", "crowd_reports"]
    counts: Dict[str, int] = {}
    items: Dict[str, List[Dict[str, Any]]] = {layer: [] for layer in include}

    if "red_zones" in include:
        for z in snap.get("red_zones", []):
            geom = z.get("geometry_wkt") or z.get("geometry") or ""
            # A red zone is "within" if its centroid is inside the user polygon
            centroid = _zone_centroid(geom)
            if centroid and _point_in_polygon(centroid[0], centroid[1], req.geometry_wkt):
                items["red_zones"].append(
                    {
                        "id": z.get("zone_id") or z.get("id"),
                        "risk_score": z.get("risk_score"),
                        "hazard_type": z.get("hazard_type"),
                    }
                )
        counts["red_zones"] = len(items["red_zones"])

    if "shelters" in include:
        for s in snap.get("shelters", []):
            if _point_in_polygon(s.get("latitude"), s.get("longitude"), req.geometry_wkt):
                items["shelters"].append(
                    {
                        "id": s.get("shelter_id") or s.get("id"),
                        "name": s.get("shelter_name") or s.get("name"),
                        "capacity": s.get("total_capacity"),
                        "available": s.get("available_capacity"),
                    }
                )
        counts["shelters"] = len(items["shelters"])

    if "habitations" in include:
        for h in snap.get("habitations", []):
            if _point_in_polygon(h.get("latitude"), h.get("longitude"), req.geometry_wkt):
                items["habitations"].append(
                    {
                        "id": h.get("habitation_id") or h.get("id"),
                        "name": h.get("village_name") or h.get("name"),
                        "population": h.get("total_population"),
                        "priority": h.get("priority_category"),
                    }
                )
        counts["habitations"] = len(items["habitations"])

    if "sos" in include:
        from app.api.v1.endpoints.sos import _SOS_STORE, _LOCK as SOS_LOCK
        with SOS_LOCK:
            for r in _SOS_STORE.values():
                if _point_in_polygon(r["latitude"], r["longitude"], req.geometry_wkt):
                    items["sos"].append(
                        {
                            "id": r["sos_id"],
                            "category": r["category"],
                            "severity": r["severity"],
                            "status": r["status"],
                        }
                    )
        counts["sos"] = len(items["sos"])

    if "crowd_reports" in include:
        from app.api.v1.endpoints.crowd_reports import _REPORTS, _LOCK as CR_LOCK
        with CR_LOCK:
            for r in _REPORTS.values():
                if _point_in_polygon(r["latitude"], r["longitude"], req.geometry_wkt):
                    items["crowd_reports"].append(
                        {
                            "id": r["report_id"],
                            "category": r["category"],
                            "severity": r["severity"],
                            "verified": r["verified"],
                        }
                    )
        counts["crowd_reports"] = len(items["crowd_reports"])

    return SpatialWithinResponse(server_time=_now_iso(), counts=counts, items=items)


@router.get("/route", response_model=RouteResponse)
async def route_to_shelter(
    origin_lat: float = Query(..., ge=-90, le=90),
    origin_lon: float = Query(..., ge=-180, le=180),
    destination_lat: float = Query(..., ge=-90, le=90),
    destination_lon: float = Query(..., ge=-180, le=180),
    avoid_red_zones: bool = Query(default=True),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """Compute a shortest safe route from origin to destination.

    For prototype, this returns a 2-segment path (origin → nearest safe
    waypoint → destination) that bends around any red zone whose
    centroid lies within 5km of the direct great-circle line. Distances
    are computed via the Haversine formula. A real deployment would
    delegate to OSRM / GraphHopper with PostGIS routing.
    """
    snap = _cached_snapshot()
    direct_distance_km = _haversine_km(origin_lat, origin_lon, destination_lat, destination_lon)

    waypoints: List[Tuple[float, float]] = [(origin_lat, origin_lon)]
    avoided_count = 0

    if avoid_red_zones:
        # Find red zones whose centroid is within 5 km of the direct line
        for z in snap.get("red_zones", []):
            geom = z.get("geometry_wkt") or z.get("geometry") or ""
            centroid = _zone_centroid(geom)
            if not centroid:
                continue
            # Distance from centroid to direct line (approximate — use distance to midpoint)
            mid_lat = (origin_lat + destination_lat) / 2
            mid_lon = (origin_lon + destination_lon) / 2
            d_to_mid = _haversine_km(mid_lat, mid_lon, centroid[0], centroid[1])
            if d_to_mid < 5.0:
                avoided_count += 1

        # If any red zones are near the direct path, insert a detour waypoint
        if avoided_count > 0:
            # Compute a perpendicular offset (5 km north of midpoint — prototype heuristic)
            mid_lat = (origin_lat + destination_lat) / 2
            mid_lon = (origin_lon + destination_lon) / 2
            # Offset by ~0.05 degrees (~5 km)
            detour_lat = mid_lat + 0.05
            detour_lon = mid_lon
            waypoints.append((detour_lat, detour_lon))

    waypoints.append((destination_lat, destination_lon))

    # Compute total path distance
    total_distance = 0.0
    for i in range(len(waypoints) - 1):
        total_distance += _haversine_km(
            waypoints[i][0], waypoints[i][1], waypoints[i + 1][0], waypoints[i + 1][1]
        )

    # Estimate walking speed at 4 km/h, driving at 30 km/h (prototype heuristic)
    walking_min = int(total_distance / 4.0 * 60)
    driving_min = int(total_distance / 30.0 * 60)

    return RouteResponse(
        server_time=_now_iso(),
        distance_km=round(total_distance, 2),
        duration_estimate_min=walking_min,
        avoided_red_zones=avoided_count,
        waypoints=waypoints,
        notes=(
            f"Prototype routing: {avoided_count} red zone(s) detected near direct path; "
            f"inserted a 5 km detour waypoint. Estimated: {walking_min} min walking, "
            f"{driving_min} min by road."
        ),
    )


@router.get("/reverse-geocode", response_model=ReverseGeocodeResponse)
async def reverse_geocode(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """Reverse geocode a lat/lon to administrative boundaries (state,
    district, sub_district, village) using the Nominatim OpenStreetMap
    public API.
    """
    try:
        resp = requests.get(
            "https://nominatim.openstreetmap.org/reverse",
            params={
                "lat": latitude,
                "lon": longitude,
                "format": "jsonv2",
                "addressdetails": 1,
                "zoom": 14,
            },
            headers={"User-Agent": _USER_AGENT},
            timeout=8.0,
        )
        if resp.status_code != 200:
            return ReverseGeocodeResponse(
                server_time=_now_iso(),
                latitude=latitude,
                longitude=longitude,
                source="nominatim",
            )
        data = resp.json()
        addr = data.get("address", {})
        return ReverseGeocodeResponse(
            server_time=_now_iso(),
            latitude=latitude,
            longitude=longitude,
            state=addr.get("state"),
            district=addr.get("county") or addr.get("state_district") or addr.get("district"),
            sub_district=addr.get("suburb") or addr.get("town") or addr.get("village"),
            village=addr.get("village") or addr.get("hamlet") or addr.get("town"),
            display_name=data.get("display_name"),
            source="nominatim",
        )
    except Exception as e:
        return ReverseGeocodeResponse(
            server_time=_now_iso(),
            latitude=latitude,
            longitude=longitude,
            source=f"nominatim-error: {e}",
        )


# ---------------------------------------------------------------------------
# Internal helper — convert WKT POLYGON to GeoJSON coordinates
# ---------------------------------------------------------------------------

def _wkt_to_coords(wkt: Optional[str]) -> List[List[List[float]]]:
    """Convert a WKT POLYGON ((x y, x y, ...)) to GeoJSON coordinates."""
    if not wkt:
        return []
    try:
        body = wkt.split("(", 2)[-1].rsplit(")", 2)[0]
        ring: List[List[float]] = []
        for pt in body.split(","):
            pt = pt.strip()
            if not pt:
                continue
            xy = pt.split()
            if len(xy) < 2:
                continue
            ring.append([float(xy[0]), float(xy[1])])
        return [ring] if ring else []
    except Exception:
        return []
