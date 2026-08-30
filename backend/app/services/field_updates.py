"""In-memory field updates overlay for offline survey sync.

This keeps operator-submitted habitation / shelter updates available to the
live snapshot endpoints even before a persistent database layer is wired in.
"""

from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
from threading import Lock
from typing import Any, Dict, List


class FieldUpdateStore:
    def __init__(self) -> None:
        self._lock = Lock()
        self._habitations: Dict[str, Dict[str, Any]] = {}
        self._shelters: Dict[str, Dict[str, Any]] = {}
        self._candidate_sites: Dict[str, Dict[str, Any]] = {}
        self._events: List[Dict[str, Any]] = []

    def upsert_habitation(self, payload: Dict[str, Any]) -> None:
        hid = str(payload.get("habitation_id") or "").strip()
        if not hid:
            return
        with self._lock:
            self._habitations[hid] = deepcopy(payload)
            self._events.append(
                {
                    "type": "habitation_update",
                    "id": hid,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                }
            )

    def upsert_shelter(self, payload: Dict[str, Any]) -> None:
        sid = str(payload.get("shelter_id") or "").strip()
        if not sid:
            return
        with self._lock:
            self._shelters[sid] = deepcopy(payload)
            self._events.append(
                {
                    "type": "shelter_update",
                    "id": sid,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                }
            )

    def register_candidate_site(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        sid = str(
            payload.get("shelter_id") or payload.get("candidate_site_id") or ""
        ).strip()
        if not sid:
            sid = f"CAND_{int(datetime.now(timezone.utc).timestamp())}"
            payload = {**payload, "shelter_id": sid}
        with self._lock:
            self._candidate_sites[sid] = deepcopy(payload)
            self._events.append(
                {
                    "type": "candidate_site",
                    "id": sid,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                }
            )
        return deepcopy(self._candidate_sites[sid])

    def apply_snapshot_overrides(self, snapshot: Dict[str, Any]) -> Dict[str, Any]:
        patched = deepcopy(snapshot)
        with self._lock:
            hab_updates = deepcopy(self._habitations)
            shelter_updates = deepcopy(self._shelters)
            candidate_sites = list(deepcopy(self._candidate_sites).values())

        for row in patched.get("habitations", []):
            override = hab_updates.get(str(row.get("habitation_id")))
            if override:
                row.update(
                    {
                        "path_status": override.get(
                            "path_status", row.get("path_status")
                        ),
                        "field_survey_notes": override.get(
                            "field_survey_notes", row.get("field_survey_notes")
                        ),
                        "last_field_visit": override.get(
                            "last_field_visit", row.get("last_field_visit")
                        ),
                        "surveyor_id": override.get(
                            "surveyor_id", row.get("surveyor_id")
                        ),
                        "is_synced": True,
                        "last_synced_at": datetime.now(timezone.utc).isoformat(),
                    }
                )

        for row in patched.get("shelters", []):
            override = shelter_updates.get(str(row.get("shelter_id")))
            if override:
                row.update(
                    {
                        "capacity_status": override.get(
                            "capacity_status", row.get("capacity_status")
                        ),
                        "water_available_liters": override.get(
                            "water_available_liters", row.get("water_available_liters")
                        ),
                        "food_available_kg": override.get(
                            "food_available_kg", row.get("food_available_kg")
                        ),
                        "medical_kits_available": override.get(
                            "medical_kits_available", row.get("medical_kits_available")
                        ),
                        "generator_fuel_liters": override.get(
                            "generator_fuel_liters", row.get("generator_fuel_liters")
                        ),
                        "access_road_status": override.get(
                            "access_road_status", row.get("access_road_status")
                        ),
                        "field_survey_notes": override.get(
                            "field_survey_notes", row.get("field_survey_notes")
                        ),
                        "last_field_visit": override.get(
                            "last_field_visit", row.get("last_field_visit")
                        ),
                        "surveyor_id": override.get(
                            "surveyor_id", row.get("surveyor_id")
                        ),
                        "is_synced": True,
                        "last_synced_at": datetime.now(timezone.utc).isoformat(),
                    }
                )

        if candidate_sites:
            patched.setdefault("shelters", []).extend(candidate_sites)
            patched.setdefault("summary", {})["shelter_count"] = len(
                patched.get("shelters", [])
            )
            patched.setdefault("summary", {})["safe_shelter_count"] = len(
                [s for s in patched.get("shelters", []) if s.get("is_in_safe_zone")]
            )
            patched.setdefault("summary", {})["available_beds"] = sum(
                int(s.get("available_capacity") or 0)
                for s in patched.get("shelters", [])
                if s.get("is_in_safe_zone")
            )
        return patched

    def recent_events(self, limit: int = 20) -> List[Dict[str, Any]]:
        with self._lock:
            return deepcopy(self._events[-limit:])

    def counts(self) -> Dict[str, int]:
        with self._lock:
            return {
                "habitation_updates": len(self._habitations),
                "shelter_updates": len(self._shelters),
                "candidate_sites": len(self._candidate_sites),
                "events": len(self._events),
            }


field_update_store = FieldUpdateStore()
