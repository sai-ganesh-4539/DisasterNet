"""Protected operational dashboard for SDMA / district planning users."""

from __future__ import annotations

from collections import Counter
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.security import get_current_user
from app.services.field_updates import field_update_store
from app.services.live_gis import INDIA_BBOX, build_snapshot

router = APIRouter()


def _filter_rows(
    rows: List[Dict[str, Any]],
    *,
    state_code: Optional[str],
    district_query: Optional[str],
) -> List[Dict[str, Any]]:
    filtered = list(rows)
    if state_code:
        filtered = [
            row
            for row in filtered
            if str(row.get("state_code", "")).upper() == state_code.upper()
        ]
    if district_query:
        query = district_query.upper()
        filtered = [
            row
            for row in filtered
            if query in str(row.get("district_name", "")).upper()
        ]
    return filtered


def _district_rollup(
    habitations: List[Dict[str, Any]], shelters: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    district_map: Dict[str, Dict[str, Any]] = {}
    for row in habitations:
        district = str(row.get("district_name") or "Unknown district")
        slot = district_map.setdefault(
            district,
            {
                "district_name": district,
                "state_code": row.get("state_code") or "IN",
                "habitation_count": 0,
                "immediate_count": 0,
                "short_term_count": 0,
                "medium_term_count": 0,
                "population_exposed": 0,
                "max_priority_score": 0.0,
            },
        )
        slot["habitation_count"] += 1
        slot["population_exposed"] += int(row.get("total_population") or 0)
        slot["max_priority_score"] = max(
            float(slot["max_priority_score"]), float(row.get("priority_score") or 0.0)
        )
        category = str(row.get("priority_category") or "MEDIUM_TERM").upper()
        if category == "IMMEDIATE":
            slot["immediate_count"] += 1
        elif category == "SHORT_TERM":
            slot["short_term_count"] += 1
        else:
            slot["medium_term_count"] += 1

    shelter_rollup: Dict[str, Dict[str, int]] = {}
    for row in shelters:
        district = str(row.get("district_name") or "Unknown district")
        slot = shelter_rollup.setdefault(
            district,
            {
                "shelter_count": 0,
                "available_capacity": 0,
                "unsafe_shelter_count": 0,
            },
        )
        slot["shelter_count"] += 1
        slot["available_capacity"] += int(row.get("available_capacity") or 0)
        if not row.get("is_in_safe_zone"):
            slot["unsafe_shelter_count"] += 1

    merged = []
    for district, base in district_map.items():
        shelter_info = shelter_rollup.get(
            district,
            {"shelter_count": 0, "available_capacity": 0, "unsafe_shelter_count": 0},
        )
        merged.append({**base, **shelter_info})
    merged.sort(
        key=lambda row: (
            int(row.get("immediate_count") or 0),
            float(row.get("max_priority_score") or 0.0),
            int(row.get("population_exposed") or 0),
        ),
        reverse=True,
    )
    return merged[:12]


@router.get("/dashboard")
async def operations_dashboard(
    south: float = Query(INDIA_BBOX[0]),
    west: float = Query(INDIA_BBOX[1]),
    north: float = Query(INDIA_BBOX[2]),
    east: float = Query(INDIA_BBOX[3]),
    state_code: Optional[str] = None,
    district_query: Optional[str] = None,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    try:
        snapshot = build_snapshot(south=south, west=west, north=north, east=east)
        habitations = _filter_rows(
            list(snapshot.get("habitations", [])),
            state_code=state_code,
            district_query=district_query,
        )
        shelters = _filter_rows(
            list(snapshot.get("shelters", [])),
            state_code=state_code,
            district_query=district_query,
        )
        red_zones = list(snapshot.get("red_zones", []))

        habitations.sort(
            key=lambda row: float(row.get("priority_score") or 0.0), reverse=True
        )
        red_zones.sort(
            key=lambda row: float(row.get("risk_score") or 0.0), reverse=True
        )
        shelters.sort(
            key=lambda row: (
                bool(row.get("is_in_safe_zone")),
                float(row.get("available_capacity") or 0.0),
            )
        )

        summary = {
            "red_zone_count": len(red_zones),
            "critical_zone_count": len(
                [z for z in red_zones if float(z.get("risk_score") or 0.0) >= 80]
            ),
            "habitation_count": len(habitations),
            "immediate_count": len(
                [h for h in habitations if h.get("priority_category") == "IMMEDIATE"]
            ),
            "short_term_count": len(
                [h for h in habitations if h.get("priority_category") == "SHORT_TERM"]
            ),
            "medium_term_count": len(
                [h for h in habitations if h.get("priority_category") == "MEDIUM_TERM"]
            ),
            "population_exposed": sum(
                int(h.get("total_population") or 0) for h in habitations
            ),
            "immediate_population": sum(
                int(h.get("total_population") or 0)
                for h in habitations
                if h.get("priority_category") == "IMMEDIATE"
            ),
            "shelter_count": len(shelters),
            "available_capacity": sum(
                int(s.get("available_capacity") or 0) for s in shelters
            ),
            "unsafe_shelter_count": len(
                [s for s in shelters if not s.get("is_in_safe_zone")]
            ),
            "constrained_shelter_count": len(
                [
                    s
                    for s in shelters
                    if str(s.get("capacity_constraint") or "NONE") != "NONE"
                ]
            ),
        }

        immediate_habitations = [
            h for h in habitations if h.get("priority_category") == "IMMEDIATE"
        ]
        priority_mix = Counter(
            str(h.get("priority_category") or "UNKNOWN") for h in habitations
        )
        hazard_mix = Counter(str(z.get("hazard_type") or "UNKNOWN") for z in red_zones)

        advisories = []
        if summary["critical_zone_count"] > 0:
            advisories.append(
                f"{summary['critical_zone_count']} critical red zone(s) require immediate SDMA review."
            )
        if summary["unsafe_shelter_count"] > 0:
            advisories.append(
                f"{summary['unsafe_shelter_count']} shelter(s) currently fail safe-zone checks."
            )
        if not advisories:
            advisories.append(
                "No critical red-zone or shelter safety exception is present in the latest snapshot."
            )

        return {
            "mode": snapshot.get("mode") or "LIVE",
            "scenario": snapshot.get("scenario"),
            "generated_at": snapshot.get("generated_at"),
            "cache_hit": snapshot.get("cache_hit", False),
            "bbox": snapshot.get("bbox"),
            "requested_filters": {
                "state_code": state_code,
                "district_query": district_query,
            },
            "auth_context": {
                "username": current_user.get("username"),
                "role": current_user.get("role"),
                "permissions": current_user.get("permissions") or [],
                "state_code": current_user.get("state_code"),
                "district_code": current_user.get("district_code"),
            },
            "summary": summary,
            "priority_mix": dict(priority_mix),
            "hazard_mix": dict(hazard_mix),
            "top_immediate_habitations": immediate_habitations[:8],
            "top_priority_habitations": habitations[:10],
            "critical_red_zones": red_zones[:8],
            "constrained_shelters": shelters[:10],
            "district_overview": _district_rollup(habitations, shelters),
            "data_sources": snapshot.get("data_sources", {}),
            "overlay_state": field_update_store.counts(),
            "advisories": advisories,
            "coverage_notes": [
                "Operational outputs are generated from the latest live GIS snapshot plus field-update overlays.",
                "Offline cache is retained on-device, but the backend snapshot remains the source of truth for planning views.",
            ],
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to build operations dashboard: {exc}",
        ) from exc
