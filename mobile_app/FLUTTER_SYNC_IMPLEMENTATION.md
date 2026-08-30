# Flutter Mobile Field App - Offline Caching & Sync Layer Implementation

## Overview
This document describes the implementation of the offline caching and synchronization layer for the Flutter mobile field application, built to integrate with the FastAPI backend.

## Architecture

### 1. Project Structure
```
mobile_app/
├── lib/
│   ├── core/
│   │   ├── config.dart          # Centralized API configuration
│   │   └── database.dart        # Isar database service
│   ├── models/
│   │   ├── hazard_zone.dart     # Hazard zone data model
│   │   ├── habitation.dart      # Habitation data model
│   │   ├── safe_shelter.dart    # Safe shelter data model
│   │   └── sync_queue_item.dart # Sync queue item model
│   └── services/
│       └── sync_service.dart    # Main sync service
└── pubspec.yaml                 # Dependencies
```

### 2. Dependencies
- **flutter_map**: Map rendering
- **latlong2**: Geospatial coordinates
- **turf**: Geospatial calculations
- **isar**: Offline NoSQL database
- **isar_flutter_libs**: Isar Flutter bindings
- **path_provider**: File system access
- **http**: HTTP client
- **connectivity_plus**: Network monitoring
- **archive**: GZIP compression
- **flutter_riverpod**: State management
- **crypto**: Cryptographic signatures
- **logger**: Logging

### 3. Database Models

#### HazardZone
- Stores hazard prediction data
- Includes geometry (WKT format), risk scores, time horizons
- Indexed by zoneId, gridId, timeHorizon
- Sync status tracking

#### Habitation
- Stores village/population data
- Priority assessment information
- Field survey data (path status, notes)
- Indexed by habitationId, stateCode, priorityCategory

#### SafeShelter
- Stores shelter capacity and resource data
- Infrastructure details (generator, medical, etc.)
- Field survey data
- Indexed by shelterId, stateCode

#### SyncQueueItem
- Queued sync operations
- Status tracking (PENDING, IN_PROGRESS, COMPLETED, FAILED)
- Compressed payload storage
- Retry count and error handling

### 4. Database Service (`database.dart`)

The `DatabaseService` provides CRUD operations for all models:

```dart
class DatabaseService {
  // Initialize Isar database
  Future<void> initialize()

  // Hazard Zones
  Future<void> saveHazardZone(HazardZone zone)
  Future<void> saveHazardZones(List<HazardZone> zones)
  Future<List<HazardZone>> getAllHazardZones()
  Future<List<HazardZone>> getRedZones()
  Future<List<HazardZone>> getHazardZonesByTimeHorizon(String timeHorizon)

  // Habitations
  Future<void> saveHabitation(Habitation habitation)
  Future<void> saveHabitations(List<Habitation> habitations)
  Future<List<Habitation>> getAllHabitations()
  Future<List<Habitation>> getHabitationsByPriority(String priorityCategory)
  Future<List<Habitation>> getUnsyncedHabitations()

  // Safe Shelters
  Future<void> saveSafeShelter(SafeShelter shelter)
  Future<void> saveSafeShelters(List<SafeShelter> shelters)
  Future<List<SafeShelter>> getAllSafeShelters()
  Future<List<SafeShelter>> getAvailableShelters()
  Future<List<SafeShelter>> getUnsyncedShelters()

  // Sync Queue
  Future<void> enqueueSyncItem(SyncQueueItem item)
  Future<List<SyncQueueItem>> getPendingSyncItems()
  Future<void> updateSyncItemStatus(String syncId, String status)
  Future<void> clearCompletedSyncItems()
}
```

### 5. Sync Service (`sync_service.dart`)

The `SyncService` handles offline-first synchronization:

#### Key Features

1. **Offline Queue Management**
   - Queue data for upload when offline
   - Automatic retry on reconnection
   - Priority-based processing

2. **Network Connectivity Monitoring**
   - Background monitoring using `connectivity_plus`
   - Automatic sync trigger on connection
   - Manual sync capability

3. **GZIP Compression**
   - Compress payloads before upload
   - Decompress downloaded data
   - Base64 encoding for transport

4. **Cryptographic Signatures**
   - HMAC-SHA256 signing
   - Device ID + Auth token based
   - Server verification support

5. **Backend Integration**
   - Upload to `/api/v1/sync/upload`
   - Download from `/api/v1/sync/download`
   - Status check via `/api/v1/sync/status`

#### Usage Example

```dart
// Initialize
final syncService = SyncService();
await syncService.initialize(
  'DEVICE_TEST_001',
  authToken: 'Bearer <jwt_token>',
);

// Start connectivity monitoring
syncService.startConnectivityMonitoring();

// Queue habitation survey for upload
await syncService.uploadHabitationSurvey(habitation);

// Queue shelter survey for upload
await syncService.uploadShelterSurvey(shelter);

// Download spatial data from server
await syncService.downloadSpatialData();

// Process pending queue (automatic on connection)
await syncService.processQueue();

// Get sync status
final status = await syncService.getSyncStatus();
```

### 6. Configuration (`config.dart`)

Centralized configuration for:
- API endpoints
- Time horizon categories
- Priority categories
- Path status values
- Capacity status values
- Hazard types
- Risk levels
- Shelter types

## Integration with Backend

### Upload Flow
1. Field team collects data offline
2. Data is queued locally with signature
3. On network connection, payload is compressed
4. GZIP-compressed data sent to `/api/v1/sync/upload`
5. Server validates signature and processes data
6. Response stored locally with timestamp

### Download Flow
1. App requests data from `/api/v1/sync/download`
2. Server sends latest hazard zones, habitations, shelters
3. Data is decompressed and stored in Isar
4. Local cache updated for offline use

### Sync Status
- Check local pending items
- Check server sync status
- Monitor network connectivity
- Provide unified status view

## Security Features

1. **Authentication**: JWT token in Authorization header
2. **Device Identification**: X-Device-ID header
3. **Data Integrity**: HMAC-SHA256 signatures
4. **Compression**: GZIP for reduced bandwidth
5. **Encryption**: Ready for HTTPS/TLS

## Offline Capabilities

1. **Local Storage**: All data stored in Isar database
2. **Queue Management**: Operations queued when offline
3. **Automatic Sync**: Triggers on network reconnection
4. **Spatial Fallback**: turf.dart for local calculations
5. **Conflict Resolution**: Timestamp-based (ready for implementation)

## Next Steps

To complete the mobile application:

1. **Map HUD Component** (Directive 1)
   - flutter_map integration
   - Time-horizon color coding
   - GPS coordinate tracking
   - Hazard zone visualization

2. **Field Survey Forms**
   - Input validation
   - Schema matching with backend
   - Offline form storage

3. **UI Layer**
   - Riverpod state management
   - Material Design 3
   - Responsive layouts

4. **Testing**
   - Unit tests for sync service
   - Integration tests with backend
   - Offline scenario testing

## Backend Compatibility

The sync service is designed to work with the existing FastAPI backend:
- `/api/v1/sync/upload` - Accepts compressed JSON payload
- `/api/v1/sync/download` - Returns spatial data
- `/api/v1/sync/status` - Provides sync statistics

Backend models match Flutter models:
- HazardZone ↔ backend hazard_zones table
- Habitation ↔ backend habitations table
- SafeShelter ↔ backend safe_shelters table
