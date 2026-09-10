"""Live official-data endpoints.

Pulls real, current data from authoritative sources and exposes them
through a single unified `/alerts/live` endpoint.
"""

from __future__ import annotations

import logging
import os
import threading
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
from xml.etree import ElementTree as ET

import requests
from bs4 import BeautifulSoup
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.config import settings
from app.core.security import get_current_user, get_current_user_optional

logger = logging.getLogger(__name__)
router = APIRouter()

_CACHE: Dict[str, Tuple[float, Dict[str, Any]]] = {}
_CACHE_LOCK = threading.RLock()
_CACHE_TTL = 300.0
_USER_AGENT = "DisasterNet-SDMA/3.0 (+official-data-ingest; contact: sdma@disasternet.in)"
_INDIA_BBOX = (6.5, 68.0, 37.1, 97.4)


def _cache_get(key):
    with _CACHE_LOCK:
        hit = _CACHE.get(key)
        if not hit:
            return None
        ts, payload = hit
        if time.time() - ts > _CACHE_TTL:
            _CACHE.pop(key, None)
            return None
        return payload


def _cache_set(key, payload):
    with _CACHE_LOCK:
        _CACHE[key] = (time.time(), payload)


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _http_get(url, *, timeout=10.0, params=None, headers=None):
    try:
        resp = requests.get(
            url,
            params=params,
            headers={
                "User-Agent": _USER_AGENT,
                "Accept": "application/json, application/atom+xml, application/xml, text/xml, text/html, */*",
                **(headers or {}),
            },
            timeout=timeout,
        )
        if resp.status_code != 200:
            return None
        return resp
    except Exception as exc:
        logger.warning("Official-data fetch failed for %s: %s", url, exc)
        return None


def _in_india(lat, lon):
    s, w, n, e = _INDIA_BBOX
    return s <= lat <= n and w <= lon <= e


def _fetch_usgs_earthquakes():
    resp = _http_get("https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson", timeout=10.0)
    items = []
    if not resp:
        return items
    try:
        payload = resp.json()
    except Exception:
        return items
    for feat in payload.get("features", []):
        try:
            coords = feat.get("geometry", {}).get("coordinates") or [0, 0, 0]
            lon, lat, depth = coords[0], coords[1], coords[2] if len(coords) > 2 else 0
            if not _in_india(lat, lon):
                continue
            props = feat.get("properties", {})
            items.append({
                "source": "USGS",
                "type": "EARTHQUAKE",
                "title": props.get("title") or "Earthquake",
                "magnitude": props.get("mag"),
                "depth_km": depth,
                "latitude": lat,
                "longitude": lon,
                "place": props.get("place"),
                "timestamp": datetime.fromtimestamp(props["time"] / 1000, tz=timezone.utc).isoformat() if props.get("time") else None,
                "url": props.get("url"),
                "tsunami": bool(props.get("tsunami")),
            })
        except Exception:
            continue
    items.sort(key=lambda i: i.get("magnitude") or 0, reverse=True)
    return items


def _fetch_emsc_earthquakes():
    resp = _http_get("https://www.seismicportal.eu/fdsnws/event/1/query",
                     params={"format": "json", "limit": 50, "orderby": "time"}, timeout=12.0)
    items = []
    if not resp:
        return items
    try:
        payload = resp.json()
    except Exception:
        return items
    for feat in payload.get("features", []):
        try:
            coords = feat.get("geometry", {}).get("coordinates") or [0, 0, 0]
            lon, lat, depth = coords[0], coords[1], coords[2] if len(coords) > 2 else 0
            if not (-10 <= lat <= 50 and 60 <= lon <= 105):
                continue
            props = feat.get("properties", {})
            items.append({
                "source": "EMSC",
                "type": "EARTHQUAKE",
                "title": f"M {props.get('mag', '?')} - {props.get('place', 'unknown')}",
                "magnitude": props.get("mag"),
                "depth_km": depth,
                "latitude": lat,
                "longitude": lon,
                "place": props.get("place"),
                "timestamp": props.get("time"),
                "url": f"https://www.emsc-csem.org/Earthquake/earthquake.php?id={feat.get('id')}",
                "in_india": _in_india(lat, lon),
            })
        except Exception:
            continue
    items.sort(key=lambda i: i.get("magnitude") or 0, reverse=True)
    return items


def _fetch_nasa_eonet():
    resp = _http_get("https://eonet.gsfc.nasa.gov/api/v3/events", timeout=10.0, params={"status": "open", "limit": 50})
    items = []
    if not resp:
        return items
    try:
        payload = resp.json()
    except Exception:
        return items
    for ev in payload.get("events", []):
        try:
            geometries = ev.get("geometry") or []
            if not geometries:
                continue
            first = geometries[0]
            coords = first.get("coordinates") or []
            if not coords:
                continue
            if first.get("type") == "Point":
                lon, lat = coords[0], coords[1]
                if not _in_india(lat, lon):
                    continue
                cats = ev.get("categories") or [{}]
                items.append({
                    "source": "NASA_EONET",
                    "type": cats[0].get("id", "EVENT").upper(),
                    "title": ev.get("title"),
                    "latitude": lat,
                    "longitude": lon,
                    "timestamp": first.get("date"),
                    "url": ev.get("link"),
                })
        except Exception:
            continue
    return items


def _fetch_reliefweb_india():
    items = []
    try:
        payload = {
            "filter": {"field": "country", "value": ["India"]},
            "sort": ["date:desc"],
            "limit": 15,
            "fields": {"include": ["title", "url", "date.created", "country.name", "source.name"]},
        }
        resp = requests.post(
            "https://api.reliefweb.int/v2/reports?appname=disasternet-sih",
            json=payload,
            headers={"User-Agent": _USER_AGENT, "Accept": "application/json"},
            timeout=15.0,
        )
        if resp.status_code != 200:
            return items
        data = resp.json()
        for entry in data.get("data", []):
            fields = entry.get("fields", {})
            try:
                created = fields.get("date", {}).get("created") if isinstance(fields.get("date"), dict) else None
                countries = fields.get("country", [])
                country_name = countries[0].get("name") if countries else None
                sources = fields.get("source", [])
                source_name = sources[0].get("name") if sources else None
                items.append({
                    "source": "RELIFWEB",
                    "type": "DISASTER_REPORT",
                    "title": fields.get("title") or "Untitled report",
                    "summary": f"ReliefWeb report - published by {source_name or 'unknown'} on {created or 'unknown date'}.",
                    "url": fields.get("url"),
                    "country": country_name,
                    "publisher": source_name,
                    "timestamp": created,
                })
            except Exception:
                continue
    except Exception as exc:
        logger.warning("ReliefWeb fetch failed: %s", exc)
    return items


def _fetch_gdacs_rss():
    items = []
    resp = _http_get("https://www.gdacs.org/xml/rss.xml", timeout=15.0)
    if not resp:
        return items
    try:
        root = ET.fromstring(resp.content)
    except Exception as exc:
        logger.warning("GDACS RSS parse failed: %s", exc)
        return items
    ns = {
        "geo": "http://www.w3.org/2003/01/geo/wgs84_pos#",
        "georss": "http://www.georss.org/georss",
        "gdacs": "http://www.gdacs.org",
    }
    for item in root.findall(".//item")[:40]:
        try:
            title = (item.findtext("title") or "").strip()
            link = (item.findtext("link") or "").strip()
            desc = (item.findtext("description") or "").strip()
            pub_date = (item.findtext("pubDate") or "").strip()
            georss_point = item.findtext("georss:point", namespaces=ns)
            lat = None
            lon = None
            if georss_point:
                parts = georss_point.split()
                if len(parts) == 2:
                    try:
                        lat = float(parts[0])
                        lon = float(parts[1])
                    except ValueError:
                        pass
            if lat is None or lon is None:
                geo_point = item.find("geo:Point", namespaces=ns)
                if geo_point is not None:
                    lat_str = geo_point.findtext("geo:lat", namespaces=ns)
                    lon_str = geo_point.findtext("geo:long", namespaces=ns)
                    if lat_str and lon_str:
                        try:
                            lat = float(lat_str)
                            lon = float(lon_str)
                        except ValueError:
                            pass
            alert_level = item.findtext("gdacs:alertlevel", namespaces=ns) or ""
            event_type = item.findtext("gdacs:eventtype", namespaces=ns) or "DISASTER"
            in_india = lat is not None and lon is not None and _in_india(lat, lon)
            items.append({
                "source": "GDACS",
                "type": event_type.upper() if event_type else "DISASTER_ALERT",
                "title": title,
                "summary": desc[:300] if desc else "",
                "url": link,
                "latitude": lat,
                "longitude": lon,
                "alert_level": alert_level or "UNKNOWN",
                "timestamp": pub_date,
                "in_india": in_india,
            })
        except Exception:
            continue
    items.sort(key=lambda i: (not (i.get("in_india") or False), i.get("timestamp") or ""), reverse=False)
    return items



def _fetch_ndma_advisories():
    items = []
    try:
        resp = requests.get("https://ndma.gov.in/en/press-releases.html",
                            headers={"User-Agent": _USER_AGENT, "Accept": "text/html"}, timeout=12.0)
        if resp.status_code != 200:
            items.append({"source": "NDMA", "type": "ADVISORY", "title": "NDMA press releases (live link)",
                          "url": "https://ndma.gov.in/en/press-releases.html",
                          "summary": "Fetched NDMA press releases page link - visit URL for live advisories."})
            return items
        soup = BeautifulSoup(resp.text, "lxml")
        titles_seen = set()
        for link in soup.find_all("a", href=True):
            text = link.get_text(strip=True)
            if not text or len(text) < 15 or len(text) > 250:
                continue
            if any(skip in text.lower() for skip in ["home", "about", "contact", "login", "sitemap", "faq"]):
                continue
            href = link["href"]
            if href.startswith("/"):
                href = "https://ndma.gov.in" + href
            if text in titles_seen:
                continue
            titles_seen.add(text)
            items.append({"source": "NDMA", "type": "ADVISORY", "title": text, "url": href,
                          "summary": "NDMA press release - see URL for full text."})
            if len(items) >= 15:
                break
        if not items:
            items.append({"source": "NDMA", "type": "ADVISORY", "title": "NDMA press releases (live link)",
                          "url": "https://ndma.gov.in/en/press-releases.html",
                          "summary": "NDMA site was reached but no press releases could be parsed."})
    except Exception as exc:
        logger.warning("NDMA fetch failed: %s", exc)
        items.append({"source": "NDMA", "type": "ADVISORY", "title": "NDMA press releases (live link)",
                      "url": "https://ndma.gov.in/en/press-releases.html",
                      "summary": f"NDMA fetch failed ({exc.__class__.__name__}). Visit URL for live advisories."})
    return items


def _fetch_imd_alerts():
    items = []
    try:
        resp = requests.get("https://mausam.imd.gov.in/responsive/warning.php",
                            headers={"User-Agent": _USER_AGENT, "Accept": "text/html"}, timeout=12.0)
        if resp.status_code != 200:
            items.append({"source": "IMD", "type": "WEATHER_WARNING", "title": "IMD public weather bulletins",
                          "summary": "Refer to https://mausam.imd.gov.in/responsive/warning.php for the latest official IMD bulletins (issued daily at 0830 and 1730 IST).",
                          "url": "https://mausam.imd.gov.in/responsive/warning.php"})
            return items
        soup = BeautifulSoup(resp.text, "lxml")
        titles_seen = set()
        for tag in soup.find_all(["h1", "h2", "h3", "h4", "b", "strong"]):
            text = tag.get_text(strip=True)
            if not text or len(text) < 10 or len(text) > 200:
                continue
            if any(skip in text.lower() for skip in ["menu", "navigation", "footer", "header", "search", "login"]):
                continue
            if text in titles_seen:
                continue
            titles_seen.add(text)
            items.append({"source": "IMD", "type": "WEATHER_WARNING", "title": text,
                          "summary": f"IMD warning excerpt: {text}",
                          "url": "https://mausam.imd.gov.in/responsive/warning.php"})
            if len(items) >= 10:
                break
        if not items:
            items.append({"source": "IMD", "type": "WEATHER_WARNING", "title": "IMD public weather bulletins",
                          "summary": "Refer to https://mausam.imd.gov.in/responsive/warning.php for the latest official IMD bulletins (issued daily at 0830 and 1730 IST).",
                          "url": "https://mausam.imd.gov.in/responsive/warning.php"})
    except Exception as exc:
        logger.warning("IMD fetch failed: %s", exc)
        items.append({"source": "IMD", "type": "WEATHER_WARNING", "title": "IMD public weather bulletins",
                      "summary": f"IMD fetch failed ({exc.__class__.__name__}). Visit URL for live bulletins.",
                      "url": "https://mausam.imd.gov.in/responsive/warning.php"})
    return items


def _fetch_openweather_alerts(lat, lon):
    api_key = os.environ.get("OPENWEATHER_API_KEY") or getattr(settings, "openweather_api_key", None)
    if not api_key:
        return []
    base_lat = lat if lat is not None else 22.0
    base_lon = lon if lon is not None else 80.0
    resp = _http_get("https://api.openweathermap.org/data/2.5/onecall",
                     params={"lat": base_lat, "lon": base_lon, "exclude": "minutely,hourly,daily", "appid": api_key},
                     timeout=8.0)
    if not resp:
        return []
    try:
        payload = resp.json()
    except Exception:
        return []
    items = []
    for a in payload.get("alerts", []):
        items.append({
            "source": "OPENWEATHER", "type": a.get("event", "WEATHER_ALERT").upper(),
            "title": a.get("event"), "summary": a.get("description"),
            "latitude": base_lat, "longitude": base_lon, "sender": a.get("sender_name"),
            "timestamp": a.get("start"), "ends_at": a.get("end"), "tags": a.get("tags") or [],
        })
    return items


class LiveAlertsResponse(BaseModel):
    server_time: str
    from_cache: bool
    sources_attempted: List[str]
    counts_by_source: Dict[str, int]
    items: List[Dict[str, Any]]
    errors: List[Dict[str, str]] = Field(default_factory=list)


class RainfallResponse(BaseModel):
    server_time: str
    from_cache: bool
    items: List[Dict[str, Any]]


class SourceHealthResponse(BaseModel):
    server_time: str
    sources: Dict[str, Dict[str, Any]]


@router.get("/live", response_model=LiveAlertsResponse)
async def live_alerts(
    latitude: Optional[float] = Query(default=None, ge=-90, le=90),
    longitude: Optional[float] = Query(default=None, ge=-180, le=180),
    source_filter: Optional[str] = Query(default=None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    cache_key = f"live_alerts:{latitude or ''}:{longitude or ''}:{source_filter or ''}"
    cached = _cache_get(cache_key)
    if cached is not None:
        cached["from_cache"] = True
        return LiveAlertsResponse(**cached)

    sources_attempted = []
    items = []
    errors = []
    counts = {}
    requested = {s.strip().upper() for s in source_filter.split(",") if s.strip()} if source_filter else None

    def _include(src):
        return requested is None or src.upper() in requested

    fetchers = [
        ("USGS", _fetch_usgs_earthquakes),
        ("EMSC", _fetch_emsc_earthquakes),
        ("NASA_EONET", _fetch_nasa_eonet),
        ("RELIFWEB", _fetch_reliefweb_india),
        ("GDACS", _fetch_gdacs_rss),
        ("NDMA", _fetch_ndma_advisories),
        ("IMD", _fetch_imd_alerts),
        ("OPENWEATHER", lambda: _fetch_openweather_alerts(latitude, longitude)),
    ]

    for name, fetcher in fetchers:
        if not _include(name):
            continue
        sources_attempted.append(name)
        try:
            rows = fetcher()
            items.extend(rows)
            counts[name] = len(rows)
        except Exception as e:
            errors.append({"source": name, "error": str(e)})
            counts[name] = 0

    items.sort(key=lambda i: (not (i.get("in_india") or False), i.get("timestamp") or ""), reverse=False)

    response = {
        "server_time": _now_iso(), "from_cache": False,
        "sources_attempted": sources_attempted, "counts_by_source": counts,
        "items": items, "errors": errors,
    }
    _cache_set(cache_key, response)
    return LiveAlertsResponse(**response)


@router.get("/health", response_model=SourceHealthResponse)
async def sources_health(current_user: Dict[str, Any] = Depends(get_current_user)):
    sources = {}
    for name, fetcher in [
        ("USGS", _fetch_usgs_earthquakes),
        ("EMSC", _fetch_emsc_earthquakes),
        ("NASA_EONET", _fetch_nasa_eonet),
        ("RELIFWEB", _fetch_reliefweb_india),
        ("GDACS", _fetch_gdacs_rss),
        ("NDMA", _fetch_ndma_advisories),
        ("IMD", _fetch_imd_alerts),
    ]:
        start = time.time()
        try:
            rows = fetcher()
            sources[name] = {"ok": True, "latency_ms": int((time.time() - start) * 1000), "rows": len(rows)}
        except Exception as e:
            sources[name] = {"ok": False, "latency_ms": int((time.time() - start) * 1000), "error": str(e)}
    return SourceHealthResponse(server_time=_now_iso(), sources=sources)