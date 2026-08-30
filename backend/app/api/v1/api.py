"""
API v1 Router
"""

from fastapi import APIRouter

from app.api.v1.endpoints import (
    auth,
    config,
    data,
    demo,
    gis,
    habitations,
    hazards,
    operations,
    priorities,
    red_zones,
    shelters,
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
api_router.include_router(operations.router, prefix="/operations", tags=["Operations"])
