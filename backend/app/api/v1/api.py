"""
API v1 Router
"""

from fastapi import APIRouter

from app.api.v1.endpoints import (
    alerts,
    auth,
    config,
    crowd_reports,
    data,
    demo,
    gis,
    gis_ext,
    habitations,
    hazards,
    operations,
    priorities,
    red_zones,
    shelters,
    sos,
    sync,
)

api_router = APIRouter()

# Include endpoint routers
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(hazards.router, prefix="/hazards", tags=["Hazards"])
api_router.include_router(red_zones.router, prefix="/red-zones", tags=["Red Zones"])
api_router.include_router(
    habitations.router, prefix="/habitations", tags=["Habitations"]
)
api_router.include_router(shelters.router, prefix="/shelters", tags=["Shelters"])
api_router.include_router(priorities.router, prefix="/priorities", tags=["Priorities"])
api_router.include_router(data.router, prefix="/data", tags=["Data Ingestion"])
api_router.include_router(demo.router, prefix="/demo", tags=["Demo Scenarios"])
api_router.include_router(sync.router, prefix="/sync", tags=["Sync"])
api_router.include_router(config.router, prefix="/config", tags=["Configuration"])
api_router.include_router(gis.router, prefix="/gis", tags=["Live GIS"])
api_router.include_router(gis_ext.router, prefix="/gis", tags=["GIS Extensions"])
api_router.include_router(operations.router, prefix="/operations", tags=["Operations"])
api_router.include_router(sos.router, prefix="/sos", tags=["SOS (offline mesh)"])
api_router.include_router(alerts.router, prefix="/alerts", tags=["Live Official Alerts"])
api_router.include_router(crowd_reports.router, prefix="/crowd-reports", tags=["Crowd Reports"])
