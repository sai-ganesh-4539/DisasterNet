import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:field_app/models/hazard_zone.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/models/sync_queue_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _hazardZonesBox = 'hazard_zones';
  static const String _habitationsBox = 'habitations';
  static const String _sheltersBox = 'shelters';
  static const String _syncQueueBox = 'sync_queue';

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(dir.path);
    } catch (e) {
      await Hive.initFlutter();
    }

    // Register adapters
    Hive.registerAdapter(HazardZoneAdapter());
    Hive.registerAdapter(HabitationAdapter());
    Hive.registerAdapter(SafeShelterAdapter());
    Hive.registerAdapter(SyncQueueItemAdapter());

    // Open boxes
    await Hive.openBox<HazardZone>(_hazardZonesBox);
    await Hive.openBox<Habitation>(_habitationsBox);
    await Hive.openBox<SafeShelter>(_sheltersBox);
    await Hive.openBox<SyncQueueItem>(_syncQueueBox);

    _isInitialized = true;
    await seedNationalDisasterDataIfEmpty();
  }

  Future<void> seedNationalDisasterDataIfEmpty() async {
    final habitationsBox = Hive.box<Habitation>(_habitationsBox);
    final hazardZonesBox = Hive.box<HazardZone>(_hazardZonesBox);
    final sheltersBox = Hive.box<SafeShelter>(_sheltersBox);

    // Clear previous dummy boxes to ensure national IMD alignment
    if (habitationsBox.isNotEmpty && habitationsBox.values.any((h) => h.districtName == 'Wayanad')) {
      await habitationsBox.clear();
      await hazardZonesBox.clear();
      await sheltersBox.clear();
    }

    if (habitationsBox.isEmpty) {
      // 1. Seed Multi-Hazard Habitations across Active Indian Disaster Corridors
      final sampleHabitations = [
        Habitation()
          ..habitationId = 'HAB_OD_01'
          ..stateCode = 'OD'
          ..districtName = 'Puri'
          ..villageName = 'Astaranga Coastal Hamlet'
          ..latitude = 19.9820
          ..longitude = 86.2730
          ..totalPopulation = 680
          ..malePopulation = 330
          ..femalePopulation = 350
          ..population0to6 = 72
          ..population60Plus = 145
          ..literacyRate = 78.0
          ..priorityScore = 94.0
          ..priorityCategory = 'IMMEDIATE'
          ..expertCategory = 'IMMEDIATE'
          ..mlCategory = 'IMMEDIATE'
          ..proximityToHazardKm = 0.4
          ..elevation = 6.0
          ..slopePercentage = 1.2
          ..hasAccessRoad = false
          ..pathStatus = 'DAMAGED'
          ..geometryWkt = 'POINT(86.2730 19.9820)'
          ..assessmentTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Coastal storm surge ingress with breached earthen embankment.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(hours: 2))
          ..surveyorId = 'OD_OFFICER_07',
        Habitation()
          ..habitationId = 'HAB_OD_02'
          ..stateCode = 'OD'
          ..districtName = 'Jagatsinghpur'
          ..villageName = 'Ersama Lowland Settlement'
          ..latitude = 20.1450
          ..longitude = 86.6120
          ..totalPopulation = 520
          ..malePopulation = 260
          ..femalePopulation = 260
          ..population0to6 = 58
          ..population60Plus = 98
          ..literacyRate = 74.0
          ..priorityScore = 91.5
          ..priorityCategory = 'IMMEDIATE'
          ..expertCategory = 'IMMEDIATE'
          ..mlCategory = 'IMMEDIATE'
          ..proximityToHazardKm = 0.8
          ..elevation = 4.5
          ..slopePercentage = 0.8
          ..hasAccessRoad = false
          ..pathStatus = 'BLOCKED'
          ..geometryWkt = 'POINT(86.6120 20.1450)'
          ..assessmentTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Mahanadi distributary overflow has submerged access bridge.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(hours: 4))
          ..surveyorId = 'OD_OFFICER_03',
        Habitation()
          ..habitationId = 'HAB_WB_01'
          ..stateCode = 'WB'
          ..districtName = 'South 24 Parganas'
          ..villageName = 'Gosaba Island Delta Hamlet'
          ..latitude = 22.1650
          ..longitude = 88.8050
          ..totalPopulation = 840
          ..malePopulation = 410
          ..femalePopulation = 430
          ..population0to6 = 95
          ..population60Plus = 130
          ..literacyRate = 71.0
          ..priorityScore = 88.0
          ..priorityCategory = 'IMMEDIATE'
          ..expertCategory = 'IMMEDIATE'
          ..mlCategory = 'IMMEDIATE'
          ..proximityToHazardKm = 0.5
          ..elevation = 3.0
          ..slopePercentage = 0.5
          ..hasAccessRoad = false
          ..pathStatus = 'DAMAGED'
          ..geometryWkt = 'POINT(88.8050 22.1650)'
          ..assessmentTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Tidal breach risk under squally wind alert.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(hours: 5))
          ..surveyorId = 'WB_OFFICER_02',
        Habitation()
          ..habitationId = 'HAB_CG_01'
          ..stateCode = 'CG'
          ..districtName = 'Gariaband'
          ..villageName = 'Rajim Riverine Settlement'
          ..latitude = 20.9650
          ..longitude = 81.8820
          ..totalPopulation = 910
          ..malePopulation = 450
          ..femalePopulation = 460
          ..population0to6 = 85
          ..population60Plus = 110
          ..literacyRate = 82.0
          ..priorityScore = 69.0
          ..priorityCategory = 'SHORT_TERM'
          ..expertCategory = 'SHORT_TERM'
          ..mlCategory = 'SHORT_TERM'
          ..proximityToHazardKm = 1.9
          ..elevation = 280.0
          ..slopePercentage = 4.2
          ..hasAccessRoad = true
          ..pathStatus = 'CLEAR'
          ..geometryWkt = 'POINT(81.8820 20.9650)'
          ..assessmentTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Mahanadi river level approaching warning mark.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(days: 1))
          ..surveyorId = 'CG_OFFICER_05',
        Habitation()
          ..habitationId = 'HAB_AP_01'
          ..stateCode = 'AP'
          ..districtName = 'Srikakulam'
          ..villageName = 'Bhavanapadu Coastal Habitation'
          ..latitude = 18.5720
          ..longitude = 84.3410
          ..totalPopulation = 640
          ..malePopulation = 310
          ..femalePopulation = 330
          ..population0to6 = 60
          ..population60Plus = 85
          ..literacyRate = 76.0
          ..priorityScore = 65.0
          ..priorityCategory = 'SHORT_TERM'
          ..expertCategory = 'SHORT_TERM'
          ..mlCategory = 'SHORT_TERM'
          ..proximityToHazardKm = 2.1
          ..elevation = 8.0
          ..slopePercentage = 1.5
          ..hasAccessRoad = true
          ..pathStatus = 'CLEAR'
          ..geometryWkt = 'POINT(84.3410 18.5720)'
          ..assessmentTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Coastal squall with 50 kmph winds. Fishermen warned against venturing.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(days: 1))
          ..surveyorId = 'AP_OFFICER_01',
        Habitation()
          ..habitationId = 'HAB_UK_01'
          ..stateCode = 'UK'
          ..districtName = 'Chamoli'
          ..villageName = 'Helang Slope Hamlet'
          ..latitude = 30.5280
          ..longitude = 79.5120
          ..totalPopulation = 340
          ..malePopulation = 170
          ..femalePopulation = 170
          ..population0to6 = 32
          ..population60Plus = 54
          ..literacyRate = 88.0
          ..priorityScore = 42.0
          ..priorityCategory = 'MEDIUM_TERM'
          ..expertCategory = 'MEDIUM_TERM'
          ..mlCategory = 'MEDIUM_TERM'
          ..proximityToHazardKm = 4.8
          ..elevation = 1520.0
          ..slopePercentage = 34.0
          ..hasAccessRoad = true
          ..pathStatus = 'CLEAR'
          ..geometryWkt = 'POINT(79.5120 30.5280)'
          ..assessmentTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Seasonal slope monitoring on Alaknanda upper gorge.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(days: 3))
          ..surveyorId = 'UK_OFFICER_04',
      ];
      for (final h in sampleHabitations) {
        await habitationsBox.put(h.habitationId, h);
      }
    }

    if (hazardZonesBox.isEmpty) {
      // 2. Seed Real-time IMD Hazard-based Red Zones across Active Meteorological Warning Zones
      final sampleZones = [
        HazardZone()
          ..zoneId = 'ZONE_OD_COAST'
          ..gridId = 'GRID_OD_MAHANADI_DELTA'
          ..latitude = 20.0500
          ..longitude = 86.4500
          ..riskScore = 93.0
          ..isRedZone = true
          ..riskLevel = 'CRITICAL'
          ..hazardType = 'EXTREME_RAINFALL_FLOOD'
          ..geometryWkt = 'POLYGON((86.10 19.80, 86.85 19.80, 86.85 20.35, 86.10 20.35, 86.10 19.80))'
          ..predictionTimestamp = DateTime.now()
          ..modelVersion = 'IMD-GFS-2.4'
          ..isSynced = true
          ..timeHorizon = 'IMMEDIATE',
        HazardZone()
          ..zoneId = 'ZONE_CG_BASIN'
          ..gridId = 'GRID_CG_SHIVNATH_BASIN'
          ..latitude = 21.1500
          ..longitude = 81.7500
          ..riskScore = 87.5
          ..isRedZone = true
          ..riskLevel = 'HIGH'
          ..hazardType = 'RIVERINE_INUNDATION'
          ..geometryWkt = 'POLYGON((81.40 20.80, 82.10 20.80, 82.10 21.50, 81.40 21.50, 81.40 20.80))'
          ..predictionTimestamp = DateTime.now()
          ..modelVersion = 'IMD-WRF-2.4'
          ..isSynced = true
          ..timeHorizon = 'IMMEDIATE',
        HazardZone()
          ..zoneId = 'ZONE_WB_SUNDARBAN'
          ..gridId = 'GRID_WB_GANGETIC_DELTA'
          ..latitude = 22.1000
          ..longitude = 88.7500
          ..riskScore = 89.0
          ..isRedZone = true
          ..riskLevel = 'CRITICAL'
          ..hazardType = 'SQUALL_SURGE_FLOOD'
          ..geometryWkt = 'POLYGON((88.35 21.80, 89.15 21.80, 89.15 22.45, 88.35 22.45, 88.35 21.80))'
          ..predictionTimestamp = DateTime.now()
          ..modelVersion = 'IMD-COASTAL-2.4'
          ..isSynced = true
          ..timeHorizon = 'IMMEDIATE',
        HazardZone()
          ..zoneId = 'ZONE_AP_COAST'
          ..gridId = 'GRID_AP_SRIKAKULAM'
          ..latitude = 18.6000
          ..longitude = 84.3000
          ..riskScore = 76.0
          ..isRedZone = true
          ..riskLevel = 'HIGH'
          ..hazardType = 'SQUALLY_COASTAL_SURGE'
          ..geometryWkt = 'POLYGON((83.95 18.30, 84.65 18.30, 84.65 18.90, 83.95 18.90, 83.95 18.30))'
          ..predictionTimestamp = DateTime.now()
          ..modelVersion = 'IMD-AP-2.4'
          ..isSynced = true
          ..timeHorizon = 'SHORT_TERM',
        HazardZone()
          ..zoneId = 'ZONE_UK_CHAMOLI'
          ..gridId = 'GRID_UK_ALAKNANDA'
          ..latitude = 30.5500
          ..longitude = 79.5500
          ..riskScore = 72.0
          ..isRedZone = true
          ..riskLevel = 'HIGH'
          ..hazardType = 'LANDSLIDE_DEBRIS_FLOW'
          ..geometryWkt = 'POLYGON((79.40 30.40, 79.70 30.40, 79.70 30.70, 79.40 30.70, 79.40 30.40))'
          ..predictionTimestamp = DateTime.now()
          ..modelVersion = 'GSI-UK-2.4'
          ..isSynced = true
          ..timeHorizon = 'SHORT_TERM',
      ];
      for (final z in sampleZones) {
        await hazardZonesBox.put(z.zoneId, z);
      }
    }

    if (sheltersBox.isEmpty) {
      // 3. Seed Verified Safe Shelters outside Red Zones
      final sampleShelters = [
        SafeShelter()
          ..shelterId = 'SHELTER_OD_01'
          ..stateCode = 'OD'
          ..districtName = 'Puri'
          ..shelterName = 'Astaranga Multi-Purpose Cyclone Shelter'
          ..shelterType = 'GOVT_BUILDING'
          ..latitude = 20.0250
          ..longitude = 86.2150
          ..totalCapacity = 850
          ..effectiveCapacity = 800
          ..availableCapacity = 520
          ..utilizationPercentage = 35.0
          ..currentPopulation = 280
          ..waterAvailableLiters = 24000
          ..foodAvailableKg = 8500
          ..medicalKitsAvailable = 110
          ..generatorFuelLiters = 800
          ..capacityConstraint = 'SPACE'
          ..capacityStatus = 'HIGH'
          ..isInSafeZone = true
          ..safetyBufferKm = 5.8
          ..hasGenerator = true
          ..hasMedicalFacility = true
          ..hasKitchen = true
          ..hasToilets = true
          ..accessRoadStatus = 'CLEAR'
          ..geometryWkt = 'POINT(86.2150 20.0250)'
          ..evaluationTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Raised plinth level 4.5m above high tide. Solar power backup active.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(hours: 3))
          ..surveyorId = 'OD_OFFICER_07',
        SafeShelter()
          ..shelterId = 'SHELTER_OD_02'
          ..stateCode = 'OD'
          ..districtName = 'Jagatsinghpur'
          ..shelterName = 'Kujang Higher Secondary Relief Hub'
          ..shelterType = 'SCHOOL'
          ..latitude = 20.2150
          ..longitude = 86.5350
          ..totalCapacity = 600
          ..effectiveCapacity = 550
          ..availableCapacity = 390
          ..utilizationPercentage = 29.0
          ..currentPopulation = 160
          ..waterAvailableLiters = 16000
          ..foodAvailableKg = 4200
          ..medicalKitsAvailable = 45
          ..generatorFuelLiters = 400
          ..capacityConstraint = 'NONE'
          ..capacityStatus = 'HIGH'
          ..isInSafeZone = true
          ..safetyBufferKm = 6.2
          ..hasGenerator = true
          ..hasMedicalFacility = true
          ..hasKitchen = true
          ..hasToilets = true
          ..accessRoadStatus = 'CLEAR'
          ..geometryWkt = 'POINT(86.5350 20.2150)'
          ..evaluationTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Stocked with 14 days emergency ration packets.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(hours: 6))
          ..surveyorId = 'OD_OFFICER_03',
        SafeShelter()
          ..shelterId = 'SHELTER_WB_01'
          ..stateCode = 'WB'
          ..districtName = 'South 24 Parganas'
          ..shelterName = 'Canning Regional Flood and Cyclone Shelter'
          ..shelterType = 'GOVT_BUILDING'
          ..latitude = 22.3120
          ..longitude = 88.6580
          ..totalCapacity = 1100
          ..effectiveCapacity = 1000
          ..availableCapacity = 750
          ..utilizationPercentage = 25.0
          ..currentPopulation = 250
          ..waterAvailableLiters = 35000
          ..foodAvailableKg = 14000
          ..medicalKitsAvailable = 160
          ..generatorFuelLiters = 1500
          ..capacityConstraint = 'NONE'
          ..capacityStatus = 'HIGH'
          ..isInSafeZone = true
          ..safetyBufferKm = 8.5
          ..hasGenerator = true
          ..hasMedicalFacility = true
          ..hasKitchen = true
          ..hasToilets = true
          ..accessRoadStatus = 'CLEAR'
          ..geometryWkt = 'POINT(88.6580 22.3120)'
          ..evaluationTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Designated state staging hub with helipad facility on high ground.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(days: 1))
          ..surveyorId = 'WB_OFFICER_02',
        SafeShelter()
          ..shelterId = 'SHELTER_CG_01'
          ..stateCode = 'CG'
          ..districtName = 'Raipur'
          ..shelterName = 'Abhanpur Community Evacuation Center'
          ..shelterType = 'COMMUNITY_CENTER'
          ..latitude = 21.0520
          ..longitude = 81.7450
          ..totalCapacity = 450
          ..effectiveCapacity = 400
          ..availableCapacity = 280
          ..utilizationPercentage = 30.0
          ..currentPopulation = 120
          ..waterAvailableLiters = 12000
          ..foodAvailableKg = 3500
          ..medicalKitsAvailable = 35
          ..generatorFuelLiters = 250
          ..capacityConstraint = 'FOOD'
          ..capacityStatus = 'MEDIUM'
          ..isInSafeZone = true
          ..safetyBufferKm = 7.0
          ..hasGenerator = true
          ..hasMedicalFacility = false
          ..hasKitchen = true
          ..hasToilets = true
          ..accessRoadStatus = 'CLEAR'
          ..geometryWkt = 'POINT(81.7450 21.0520)'
          ..evaluationTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Food stock sufficient for 10 days. Requisition submitted for restock.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(hours: 8))
          ..surveyorId = 'CG_OFFICER_05',
        SafeShelter()
          ..shelterId = 'SHELTER_AP_01'
          ..stateCode = 'AP'
          ..districtName = 'Srikakulam'
          ..shelterName = 'Tekkali Model School Cyclone Shelter'
          ..shelterType = 'SCHOOL'
          ..latitude = 18.6180
          ..longitude = 84.2350
          ..totalCapacity = 500
          ..effectiveCapacity = 450
          ..availableCapacity = 320
          ..utilizationPercentage = 28.8
          ..currentPopulation = 130
          ..waterAvailableLiters = 14000
          ..foodAvailableKg = 4000
          ..medicalKitsAvailable = 50
          ..generatorFuelLiters = 300
          ..capacityConstraint = 'SPACE'
          ..capacityStatus = 'HIGH'
          ..isInSafeZone = true
          ..safetyBufferKm = 5.2
          ..hasGenerator = true
          ..hasMedicalFacility = true
          ..hasKitchen = true
          ..hasToilets = true
          ..accessRoadStatus = 'CLEAR'
          ..geometryWkt = 'POINT(84.2350 18.6180)'
          ..evaluationTimestamp = DateTime.now()
          ..modelVersion = '2.4.0'
          ..isSynced = true
          ..fieldSurveyNotes = 'Elevated 3-storey RCC structure equipped with solar water pumps.'
          ..lastFieldVisit = DateTime.now().subtract(const Duration(days: 1))
          ..surveyorId = 'AP_OFFICER_01',
      ];
      for (final s in sampleShelters) {
        await sheltersBox.put(s.shelterId, s);
      }
    }
  }

  // Hazard Zone operations
  Future<void> saveHazardZone(HazardZone zone) async {
    final box = Hive.box<HazardZone>(_hazardZonesBox);
    await box.put(zone.zoneId, zone);
  }

  Future<void> saveHazardZones(List<HazardZone> zones) async {
    final box = Hive.box<HazardZone>(_hazardZonesBox);
    for (final zone in zones) {
      await box.put(zone.zoneId, zone);
    }
  }

  Future<List<HazardZone>> getAllHazardZones() async {
    final box = Hive.box<HazardZone>(_hazardZonesBox);
    return box.values.toList();
  }

  Future<List<HazardZone>> getRedZones() async {
    final box = Hive.box<HazardZone>(_hazardZonesBox);
    return box.values.where((zone) => zone.isRedZone).toList();
  }

  // Habitation operations
  Future<void> saveHabitation(Habitation habitation) async {
    final box = Hive.box<Habitation>(_habitationsBox);
    await box.put(habitation.habitationId, habitation);
  }

  Future<void> saveHabitations(List<Habitation> habitations) async {
    final box = Hive.box<Habitation>(_habitationsBox);
    for (final habitation in habitations) {
      await box.put(habitation.habitationId, habitation);
    }
  }

  Future<List<Habitation>> getAllHabitations() async {
    final box = Hive.box<Habitation>(_habitationsBox);
    return box.values.toList();
  }

  Future<List<Habitation>> getHabitationsByPriority(String priorityCategory) async {
    final box = Hive.box<Habitation>(_habitationsBox);
    return box.values
        .where((h) => h.priorityCategory.toUpperCase() == priorityCategory.toUpperCase())
        .toList();
  }

  // Safe Shelter operations
  Future<void> saveSafeShelter(SafeShelter shelter) async {
    final box = Hive.box<SafeShelter>(_sheltersBox);
    await box.put(shelter.shelterId, shelter);
  }

  Future<void> saveSafeShelters(List<SafeShelter> shelters) async {
    final box = Hive.box<SafeShelter>(_sheltersBox);
    for (final shelter in shelters) {
      await box.put(shelter.shelterId, shelter);
    }
  }

  Future<List<SafeShelter>> getAllSafeShelters() async {
    final box = Hive.box<SafeShelter>(_sheltersBox);
    return box.values.toList();
  }

  // Sync Queue operations
  Future<void> addToSyncQueue(SyncQueueItem item) async {
    final box = Hive.box<SyncQueueItem>(_syncQueueBox);
    await box.put(item.id, item);
  }

  Future<List<SyncQueueItem>> getPendingSyncItems() async {
    final box = Hive.box<SyncQueueItem>(_syncQueueBox);
    return box.values.where((item) => item.status == 'pending').toList();
  }

  Future<void> updateSyncItemStatus(String queueId, String status, {String? error}) async {
    final box = Hive.box<SyncQueueItem>(_syncQueueBox);
    final item = box.get(queueId);
    if (item != null) {
      item.status = status;
      if (error != null) item.errorMessage = error;
      item.retryCount += 1;
      await item.save();
    }
  }

  Future<void> removeSyncItem(String queueId) async {
    final box = Hive.box<SyncQueueItem>(_syncQueueBox);
    await box.delete(queueId);
  }

  Future<void> clearAll() async {
    await Hive.box<HazardZone>(_hazardZonesBox).clear();
    await Hive.box<Habitation>(_habitationsBox).clear();
    await Hive.box<SafeShelter>(_sheltersBox).clear();
    await Hive.box<SyncQueueItem>(_syncQueueBox).clear();
  }
}
