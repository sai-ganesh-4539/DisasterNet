"""SOS messaging endpoints with layered offline fallback.

Fallback chain (highest priority first):
  1. **Server direct** — if device is online, POST the SOS directly to the
     central FastAPI server.
  2. **Phone-to-phone mesh relay** — if no cellular/data, the SOS is
     encrypted and broadcast to nearby devices over Bluetooth LE / Wi-Fi
     Direct. Each receiving phone stores it in a local queue and either:
       a) re-broadcasts it to other phones (mesh propagation, bounded by
          ``settings.sos_mesh_max_hops``), AND
       b) uploads it to the server the moment any phone gets connectivity.
  3. **SMS gateway fallback** — if no phones in the mesh ever get
     connectivity, the phone that originally captured the SOS (or any relay
     node that has cellular SMS-only coverage) sends a compact structured
     payload as SMS to ``settings.sos_sms_gateway_number``.

This module exposes the server side: ingest SOS, accept mesh-relayed
copies (dedup by ``sos_id``), accept SMS-gateway copies, and let clients
download SOSes that need to be relayed.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import math
import secrets
import threading
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.core.config import settings
from app.core.security import get_current_user, get_current_user_optional

logger = logging.getLogger(__name__)
router = APIRouter()


# ---------------------------------------------------------------------------
# In-memory SOS store (prototype — production: persist in PostGIS-backed table)
# ---------------------------------------------------------------------------
_LOCK = threading.RLock()
_SOS_STORE: Dict[str, Dict[str, Any]] = {}  # sos_id -> sos_record
_RELAY_LOG: List[Dict[str, Any]] = []  # last 500 relay events
_SOS_RADIUS_KM_DEFAULT = 25.0


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Compute the great-circle distance in km between two points."""
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


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class SosPayload(BaseModel):
    """Payload submitted by a citizen's device.

    The ``origin_layer`` field records which fallback layer actually
    captured the SOS at the originating device, while ``relayed_through``
    accumulates the list of mesh hops (device hashes) the message has
    traversed.
    """

    sos_id: str = Field(..., description="Client-generated UUID — used for dedup")
    device_id: str = Field(..., description="Originating device hash")
    user_id: Optional[str] = None
    role: Optional[str] = None
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    accuracy_m: Optional[float] = None
    category: str = Field(
        default="MEDICAL",
        description="MEDICAL | STRANDED | FOOD_WATER | SHELTER | VIOLENCE | FIRE | OTHER",
    )
    severity: str = Field(
        default="HIGH", description="LOW | MEDIUM | HIGH | CRITICAL"
    )
    message: str = Field(default="", max_length=1000)
    people_count: Optional[int] = Field(default=None, ge=1, le=10000)
    contact_phone: Optional[str] = None
    timestamp: str = Field(default_factory=_now_iso)

    # Layered fallback metadata
    origin_layer: str = Field(
        default="SERVER_DIRECT",
        description="SERVER_DIRECT | MESH_RELAY | SMS_GATEWAY",
    )
    relayed_through: List[str] = Field(default_factory=list)
    hop_count: int = Field(default=0)
    sms_gateway: Optional[str] = None
    signature: Optional[str] = Field(
        default=None,
        description="HMAC-SHA256 of canonical payload (prototype: optional)",
    )


class SosAck(BaseModel):
    sos_id: str
    accepted: bool
    duplicate: bool
    layer: str
    hop_count: int
    message: str
    server_timestamp: str


class SosRecord(BaseModel):
    sos_id: str
    device_id: str
    latitude: float
    longitude: float
    category: str
    severity: str
    message: str
    people_count: Optional[int]
    contact_phone: Optional[str]
    timestamp: str
    origin_layer: str
    hop_count: int
    relayed_through: List[str]
    status: str
    acknowledged_at: Optional[str]
    acknowledged_by: Optional[str]


class SosListResponse(BaseModel):
    count: int
    items: List[SosRecord]
    server_time: str


class SosQuery(BaseModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius_km: float = Field(default=_SOS_RADIUS_KM_DEFAULT, ge=1, le=500)
    category: Optional[str] = None
    severity: Optional[str] = None
    limit: int = Field(default=50, ge=1, le=500)


class SosAckRequest(BaseModel):
    """Field officer acknowledges an SOS — marks it as 'acknowledged'."""

    note: Optional[str] = None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _canonicalize(value: Any) -> str:
    if isinstance(value, dict):
        items = sorted(value.items(), key=lambda kv: str(kv[0]))
        return "{" + ",".join(f'"{k}":{_canonicalize(v)}' for k, v in items) + "}"
    if isinstance(value, (list, tuple)):
        return "[" + ",".join(_canonicalize(v) for v in value) + "]"
    return str(value)


def _verify_signature(payload: SosPayload) -> bool:
    """Prototype signature verification — always passes if signature absent."""
    if not payload.signature:
        return True
    body = {k: v for k, v in payload.model_dump().items() if k != "signature"}
    canonical = _canonicalize(body)
    secret = settings.citizen_otp_secret.encode("utf-8")
    expected = hmac.new(secret, canonical.encode("utf-8"), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, payload.signature or "")


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/submit", response_model=SosAck)
async def submit_sos(
    payload: SosPayload,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """Ingest an SOS via any fallback layer.

    Behaviour:
    * Deduplicates by ``sos_id``. A duplicate submission (e.g. from a mesh
      node and later from the originating phone) is acknowledged as a
      duplicate, not an error.
    * Records the highest-severity source layer (SERVER_DIRECT > MESH_RELAY
      > SMS_GATEWAY) so the operator UI can show how the SOS arrived.
    * Stamps the user_id and role from the JWT if the citizen is
      authenticated, otherwise stamps as ANONYMOUS.
    """
    if not _verify_signature(payload):
        raise HTTPException(status_code=401, detail="Invalid SOS signature.")

    with _LOCK:
        existing = _SOS_STORE.get(payload.sos_id)
        if existing is not None:
            # Merge metadata: keep the highest-priority layer & longest relay path.
            layer_rank = {"SERVER_DIRECT": 3, "MESH_RELAY": 2, "SMS_GATEWAY": 1}
            best_layer = max(
                [existing["origin_layer"], payload.origin_layer],
                key=lambda l: layer_rank.get(l, 0),
            )
            merged_relayers = list(
                dict.fromkeys(existing["relayed_through"] + payload.relayed_through)
            )
            existing["origin_layer"] = best_layer
            existing["relayed_through"] = merged_relayers
            existing["hop_count"] = max(existing["hop_count"], payload.hop_count)
            existing["last_seen"] = _now_iso()
            _RELAY_LOG.append(
                {
                    "sos_id": payload.sos_id,
                    "event": "duplicate_relay",
                    "layer": payload.origin_layer,
                    "ts": _now_iso(),
                }
            )
            _trim_relay_log()
            return SosAck(
                sos_id=payload.sos_id,
                accepted=True,
                duplicate=True,
                layer=best_layer,
                hop_count=existing["hop_count"],
                message="Duplicate SOS — metadata merged.",
                server_timestamp=_now_iso(),
            )

        # New SOS
        uid = current_user.get("user_id") if current_user else None
        role = current_user.get("role") if current_user else None
        record = {
            **payload.model_dump(),
            "user_id": payload.user_id or uid,
            "role": payload.role or role,
            "status": "OPEN",
            "acknowledged_at": None,
            "acknowledged_by": None,
            "first_seen": _now_iso(),
            "last_seen": _now_iso(),
        }
        _SOS_STORE[payload.sos_id] = record
        _RELAY_LOG.append(
            {
                "sos_id": payload.sos_id,
                "event": "ingested",
                "layer": payload.origin_layer,
                "ts": _now_iso(),
            }
        )
        _trim_relay_log()

    return SosAck(
        sos_id=payload.sos_id,
        accepted=True,
        duplicate=False,
        layer=payload.origin_layer,
        hop_count=payload.hop_count,
        message="SOS received by central server.",
        server_timestamp=_now_iso(),
    )


@router.post("/relay", response_model=SosAck)
async def relay_sos(
    payload: SosPayload,
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """A mesh relay node forwards an SOS it received from another phone.

    Semantically identical to /submit, but stamped with origin_layer =
    MESH_RELAY if the originating phone set it to SERVER_DIRECT (i.e. this
    is a relay of an SOS that the relay phone picked up off a peer).
    """
    if payload.origin_layer == "SERVER_DIRECT":
        payload = payload.model_copy(update={"origin_layer": "MESH_RELAY"})
    payload.relayed_through = list(
        dict.fromkeys(payload.relayed_through + [current_user.get("user_id")] if current_user else payload.relayed_through)
    )
    payload.hop_count += 1
    if payload.hop_count > settings.sos_mesh_max_hops:
        # Drop propagation beyond max hops to prevent mesh storms.
        return SosAck(
            sos_id=payload.sos_id,
            accepted=False,
            duplicate=False,
            layer="MESH_RELAY",
            hop_count=payload.hop_count,
            message=f"Max hops ({settings.sos_mesh_max_hops}) exceeded — dropping relay.",
            server_timestamp=_now_iso(),
        )
    return await submit_sos(payload, current_user)


@router.post("/sms-gateway", response_model=SosAck)
async def sms_gateway_sos(payload: SosPayload):
    """Receive SOS from an SMS gateway.

    Production deployments will register this endpoint URL with an SMS
    inbound gateway (e.g. MSG91, Twilio). For prototype, the same
    SosPayload schema is used, with ``origin_layer = SMS_GATEWAY`` and
    ``sms_gateway`` set.
    """
    payload = payload.model_copy(update={"origin_layer": "SMS_GATEWAY"})
    return await submit_sos(payload, None)


@router.get("/", response_model=SosListResponse)
async def list_sos(
    latitude: Optional[float] = Query(default=None, ge=-90, le=90),
    longitude: Optional[float] = Query(default=None, ge=-180, le=180),
    radius_km: float = Query(default=_SOS_RADIUS_KM_DEFAULT, ge=1, le=500),
    category: Optional[str] = Query(default=None),
    severity: Optional[str] = Query(default=None),
    limit: int = Query(default=50, ge=1, le=500),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
):
    """List SOSes — optionally filtered by location/radius and metadata.

    Citizens see only SOSes within their queried radius (community
    awareness). Field officers and admins see all SOSes by default.
    """
    items: List[SosRecord] = []
    role = (current_user or {}).get("role") or ""
    is_citizen = role.upper() == "CITIZEN" or current_user is None

    with _LOCK:
        for record in _SOS_STORE.values():
            if category and record["category"] != category:
                continue
            if severity and record["severity"] != severity:
                continue
            if latitude is not None and longitude is not None:
                d = _haversine_km(
                    latitude, longitude, record["latitude"], record["longitude"]
                )
                if d > radius_km:
                    continue
            items.append(_to_record(record))

    # Citizen queries are capped to nearby SOSes — even without explicit
    # lat/lon we sort by most recent first and limit.
    items.sort(key=lambda r: r.timestamp, reverse=True)
    if is_citizen and (latitude is None or longitude is None):
        items = items[: min(limit, 25)]
    else:
        items = items[:limit]

    return SosListResponse(count=len(items), items=items, server_time=_now_iso())


@router.get("/{sos_id}", response_model=SosRecord)
async def get_sos(sos_id: str, current_user: Dict[str, Any] = Depends(get_current_user)):
    with _LOCK:
        record = _SOS_STORE.get(sos_id)
    if record is None:
        raise HTTPException(status_code=404, detail="SOS not found.")
    return _to_record(record)


@router.post("/{sos_id}/acknowledge", response_model=SosRecord)
async def acknowledge_sos(
    sos_id: str,
    body: SosAckRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """A field officer (or admin) acknowledges an SOS — marks it ACKNOWLEDGED."""
    role = (current_user.get("role") or "").upper()
    if role in {"CITIZEN", "VIEWER"}:
        raise HTTPException(status_code=403, detail="Only field officers or admins can acknowledge SOSes.")

    with _LOCK:
        record = _SOS_STORE.get(sos_id)
        if record is None:
            raise HTTPException(status_code=404, detail="SOS not found.")
        record["status"] = "ACKNOWLEDGED"
        record["acknowledged_at"] = _now_iso()
        record["acknowledged_by"] = current_user.get("user_id")
        if body.note:
            record["ack_note"] = body.note
        return _to_record(record)


@router.get("/relay/log")
async def relay_log(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Return the last 100 relay events — useful for demo / audit visualization."""
    role = (current_user.get("role") or "").upper()
    if role in {"CITIZEN", "VIEWER"}:
        raise HTTPException(status_code=403, detail="Operators only.")
    with _LOCK:
        return {"events": list(_RELAY_LOG[-100:]), "count": len(_RELAY_LOG)}


@router.get("/status/summary")
async def sos_status_summary(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Aggregate stats for the SOS dashboard."""
    role = (current_user.get("role") or "").upper()
    is_citizen = role == "CITIZEN"
    with _LOCK:
        records = list(_SOS_STORE.values())
        if is_citizen and current_user.get("state_code"):
            records = [r for r in records if r.get("role") == "CITIZEN"]
        total = len(records)
        by_status: Dict[str, int] = {}
        by_category: Dict[str, int] = {}
        by_layer: Dict[str, int] = {}
        for r in records:
            by_status[r["status"]] = by_status.get(r["status"], 0) + 1
            by_category[r["category"]] = by_category.get(r["category"], 0) + 1
            by_layer[r["origin_layer"]] = by_layer.get(r["origin_layer"], 0) + 1
        return {
            "total": total,
            "by_status": by_status,
            "by_category": by_category,
            "by_origin_layer": by_layer,
            "max_hops_configured": settings.sos_mesh_max_hops,
            "sms_gateway_configured": bool(settings.sos_sms_gateway_number),
            "server_time": _now_iso(),
        }


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

def _to_record(record: Dict[str, Any]) -> SosRecord:
    return SosRecord(
        sos_id=record["sos_id"],
        device_id=record["device_id"],
        latitude=record["latitude"],
        longitude=record["longitude"],
        category=record["category"],
        severity=record["severity"],
        message=record["message"],
        people_count=record.get("people_count"),
        contact_phone=record.get("contact_phone"),
        timestamp=record["timestamp"],
        origin_layer=record["origin_layer"],
        hop_count=record["hop_count"],
        relayed_through=record["relayed_through"],
        status=record["status"],
        acknowledged_at=record.get("acknowledged_at"),
        acknowledged_by=record.get("acknowledged_by"),
    )


def _trim_relay_log() -> None:
    if len(_RELAY_LOG) > 500:
        del _RELAY_LOG[: len(_RELAY_LOG) - 500]
