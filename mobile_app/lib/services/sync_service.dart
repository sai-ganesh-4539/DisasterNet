import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:field_app/core/config.dart';
import 'package:field_app/core/database.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/hazard_zone.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/models/sync_queue_item.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _db = DatabaseService();
  final Logger _logger = Logger();
  final Connectivity _connectivity = Connectivity();

  String? _deviceId;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;
  bool get isInitialized => _deviceId != null && _deviceId!.isNotEmpty;

  Future<void> initialize(String deviceId) async {
    _deviceId = deviceId;
    await _db.initialize();
  }

  Future<bool> checkConnectivity() async {
    final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
    return result.any((entry) => entry != ConnectivityResult.none);
  }

  Future<int> syncPendingItems() async {
    if (!isInitialized) {
      _logger.w('SyncService not initialized; skipping queue sync');
      return 0;
    }
    final pending = await _db.getPendingSyncItems();
    if (pending.isEmpty) return 0;
    await processSyncQueue();
    return pending.length;
  }

  Future<void> processSyncQueue() async {
    if (_isSyncing || !isInitialized) return;
    if (!await checkConnectivity()) return;

    _isSyncing = true;
    try {
      final pendingItems = await _db.getSyncQueueItemsByStatus('pending');
      for (final item in pendingItems) {
        await _processQueueItem(item);
      }
      await _db.clearCompletedSyncItems();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processQueueItem(SyncQueueItem item) async {
    try {
      item.status = 'in_progress';
      await _db.saveSyncQueueItem(item);

      final payload = jsonDecode(item.payload) as Map<String, dynamic>;
      final dataType = item.operationType == 'UPDATE_HABITATION' ? 'field_survey' : 'shelter_update';
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final signature = _generateSignature(payload);

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.syncUpload}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': _deviceId,
          'data_type': dataType,
          'payload': payload,
          'timestamp': timestamp,
          'signature': signature,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }

      item.status = 'completed';
      await _db.saveSyncQueueItem(item);
    } catch (e) {
      _logger.e('Failed to process sync item ${item.id}: $e');
      item.status = 'failed';
      item.retryCount += 1;
      item.errorMessage = e.toString();
      await _db.saveSyncQueueItem(item);
    }
  }

  Future<void> downloadSpatialData() async {
    if (!isInitialized) throw Exception('SyncService is not initialized');
    if (!await checkConnectivity()) throw Exception('No network connection available');

    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppConfig.syncDownload}?device_id=$_deviceId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode} ${response.body}');
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final zones = (responseData['hazard_zones'] as List? ?? [])
        .map((json) => HazardZone.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
    final habitations = (responseData['habitations'] as List? ?? [])
        .map((json) => Habitation.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
    final shelters = (responseData['shelters'] as List? ?? [])
        .map((json) => SafeShelter.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();

    await _db.replaceLiveSnapshot(
      zones: zones,
      habitations: habitations,
      shelters: shelters,
    );
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    if (!isInitialized) {
      return {
        'local_pending': (await _db.getPendingSyncItems()).length,
        'is_connected': await checkConnectivity(),
        'initialized': false,
      };
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.syncStatus}?device_id=$_deviceId'),
      );
      if (response.statusCode == 200) {
        final remote = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          ...remote,
          'local_pending': (await _db.getPendingSyncItems()).length,
          'is_connected': await checkConnectivity(),
          'initialized': true,
        };
      }
    } catch (e) {
      _logger.w('Sync status fetch failed: $e');
    }

    return {
      'local_pending': (await _db.getPendingSyncItems()).length,
      'is_connected': await checkConnectivity(),
      'initialized': true,
    };
  }

  Future<void> clearLocalData() async {
    await _db.clearAllData();
  }

  String _generateSignature(Map<String, dynamic> payload) {
    final canonical = _canonicalize(payload);
    final bytes = utf8.encode('${_deviceId ?? ''}$canonical');
    return sha256.convert(bytes).toString();
  }

  String _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return '{${entries.map((e) => '"${e.key}":${_canonicalize(e.value)}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_canonicalize).join(',')}]';
    }
    return jsonEncode(value);
  }
}
