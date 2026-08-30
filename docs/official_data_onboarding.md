# Official Data Onboarding Guide

This project can run today with live public fallback sources, but full nationwide SDMA-grade decision support needs official baseline and live feeds.

## 1. Accounts and portals to register

### IMD
- Portal: `https://api.imd.gov.in/public/index.php`
- API reference: `https://api.imd.gov.in/public/api_reference.html`
- Ask for access to:
  - district-wise rainfall
  - district-wise warnings
  - district-wise nowcast
  - AWS / ARG observations
  - river basin rainfall / QPF
  - cyclone / coastal bulletins

### LGD
- Portal: `https://lgdirectory.gov.in/downloadDirectory.do`
- Download these first:
  - All States of India
  - All Districts of India
  - All Sub-Districts of India
  - All Villages of India
  - modification-only updates for refresh jobs

### Bhuvan / NRSC
- Portal: `https://bhuvan.nrsc.gov.in/`
- API landing: `https://bhuvan-app1.nrsc.gov.in/api/`
- WMS/WMTS docs: `https://bhuvan.nrsc.gov.in/wiki/index.php/How_to_use_WMS_services`
- Prioritize access to:
  - land use / land cover
  - erosion / flood hazard layers
  - village geocoding
  - thematic OGC services usable in GIS overlays

### CWC / NWDP
- Portal: `https://nwdp.nwic.gov.in/`
- Important datasets:
  - river water level telemetry hourly
  - river discharge manual / telemetry
  - rainfall telemetry
  - reservoirs
  - river polygons / floodplain layers

### INCOIS
- Portal: `https://incois.gov.in/`
- Useful services:
  - storm surge warnings
  - coastal inundation advisories
  - ocean state / marine warning products for coastal districts

### Health / education facilities
- Health centres directory: `https://data.gov.in/catalog/all-india-health-centres-directory`
- UDISE+: `https://udiseplus.gov.in/`
- UDISE GIS: `https://gis.udiseplus.gov.in/`

## 2. What to collect first for a credible nationwide rollout

### Mandatory baseline layers
1. state boundaries
2. district boundaries
3. subdistrict boundaries
4. village / habitation master list
5. population joins
6. school / college / govt-building candidates for shelters
7. health facilities
8. rivers / reservoirs / floodplain / drainage layers
9. terrain and land-use layers

### Mandatory live feeds
1. IMD rainfall and warnings
2. CWC water level / discharge
3. INCOIS coastal hazard products for coastal districts

## 3. How the platform should use each source

### Source of truth hierarchy
1. official live API or official downloadable dataset
2. official periodic CSV / shapefile import
3. state department uploads
4. public fallback sources only when official data is unavailable

### Current fallback state
Today the app/backend can operate with:
- Open-Meteo
- OpenStreetMap Overpass
- on-device field overlays

These are useful for a live prototype, but they are not enough to claim fully official nationwide operational coverage.

## 4. Local development configuration

Create `backend/.env` from `backend/.env.example` and set at least:
- `SECRET_KEY`
- bootstrap operator credentials
- later: `IMD_API_KEY`, `ISRO_API_KEY`, and any future official-source credentials

## 5. Recommended next engineering step

To meet the expected solution nationwide, build this next in order:
1. PostGIS persistence
2. official baseline importers for LGD / districts / villages / facilities
3. IMD + CWC + INCOIS ingestion adapters
4. district/state scoped RBAC and audit logging
5. scheduled refresh jobs and provenance dashboards

## 6. What to send back to the coding agent

Once you obtain access, send any of the following:
- API keys
- downloaded CSVs / shapefiles / GeoJSON
- portal export screenshots if formats are unclear
- target operational states for first validation
- any government-issued schema or field dictionary

Then the ingestion layer can be wired against the real data instead of fallbacks.
