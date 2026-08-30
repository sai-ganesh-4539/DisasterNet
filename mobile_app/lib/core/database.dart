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
    await purgeLegacyStaticSeed();
  }

  Future<void> purgeLegacyStaticSeed() async {
    final habitationsBox = Hive.box<Habitation>(_habitationsBox);
    final hazardZonesBox = Hive.box<HazardZone>(_hazardZonesBox);
    final sheltersBox = Hive.box<SafeShelter>(_sheltersBox);
    final looksSeeded = habitationsBox.values.any((h) => h.habitationId.startsWith('HAB_OD_')) ||
        hazardZonesBox.values.any((z) => z.zoneId.startsWith('ZONE_OD_') || z.modelVersion.contains('IMD-GFS'));
    if (looksSeeded) {
      await habitationsBox.clear();
      await hazardZonesBox.clear();
      await sheltersBox.clear();
    }
  }

  Future<void> replaceLiveSnapshot({
    required List<HazardZone> zones,
    required List<Habitation> habitations,
    required List<SafeShelter> shelters,
  }) async {
    final habitationsBox = Hive.box<Habitation>(_habitationsBox);
    final hazardZonesBox = Hive.box<HazardZone>(_hazardZonesBox);
    final sheltersBox = Hive.box<SafeShelter>(_sheltersBox);
    await habitationsBox.clear();
    await hazardZonesBox.clear();
    await sheltersBox.clear();
    for (final zone in zones) {
      await hazardZonesBox.put(zone.zoneId, zone);
    }
    for (final habitation in habitations) {
      await habitationsBox.put(habitation.habitationId, habitation);
    }
    for (final shelter in shelters) {
      await sheltersBox.put(shelter.shelterId, shelter);
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
