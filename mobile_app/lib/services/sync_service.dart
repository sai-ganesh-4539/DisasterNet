import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:field_app/core/config.dart';
import 'package:field_app/core/database.dart';
import 'package:field_app/models/hazard_zone.dart';
import 'package:field_app/models/habitation.dart';
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

  // Device identification
  late String _deviceId;
  String? _authToken;

  // Sync state
  bool _isSyncing = false;
  bool _isMonitoring = false;

  bool get isSyncing => _isSyncing;
  bool get isMonitoring => _isMonitoring;

  Future<void> initialize(String deviceId, {String? authToken}) async {
    _deviceId = deviceId;
    _authToken = authToken;
    try {
      await _db.initialize();
    } catch (e) {
      _logger.w('Database initialization failed: $e');
    }
    _logger.i('SyncService initialized for device: $_deviceId');
  }

  // ============================================
  // OFFLINE QUEUE MANAGEMENT
  // ============================================

  /// Queue data for sync when offline
  Future<void> queueForUpload({
    required String dataType,
    required Map<String, dynamic> data,
  }) async {
    final syncId = _generateSyncId();
    final payload = jsonEncode(data);
    final signature = _generateSignature(payload);

    final syncItem = SyncQueueItem(
      id: syncId,
      operationType: 'UPLOAD',
      status: 'pending',
      payload: payload,
      createdAt: DateTime.now(),
      retryCount: 0,
    );

    await _db.enqueueSyncItem(syncItem);
    _logger.i('Queued $dataType for upload: $syncId');

    // Try to sync immediately if connected
    if (await _isConnected()) {
      await processQueue();
    }
  }

  /// Process pending sync queue items
  Future<void> processQueue() async {
    if (_isSyncing) {
      _logger.w('Sync already in progress, skipping');
      return;
    }

    if (!await _isConnected()) {
      _logger.w('No network connection, queue will be processed when connected');
      return;
    }

    _isSyncing = true;
    _logger.i('Starting sync queue processing');

    try {
      final pendingItems = await _db.getPendingSyncItems();

      for (final item in pendingItems) {
        await _processSyncItem(item);
      }

      // Clean up completed items
      await _db.clearCompletedSyncItems();
      _logger.i('Sync queue processing completed');
    } catch (e) {
      _logger.e('Error processing sync queue: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processSyncItem(SyncQueueItem item) async {
    try {
      await _db.updateSyncItemStatus(item.id, 'in_progress');

      if (item.operationType == 'UPLOAD') {
        await _uploadSyncItem(item);
      } else if (item.operationType == 'DOWNLOAD') {
        await _downloadSyncItem(item);
      }

      await _db.updateSyncItemStatus(item.id, 'completed');
      _logger.i('Successfully processed sync item: ${item.id}');
    } catch (e) {
      _logger.e('Failed to process sync item ${item.id}: $e');
      await _db.updateSyncItemStatus(
        item.id,
        'failed',
        errorMessage: e.toString(),
      );
    }
  }

  // ============================================
  // UPLOAD SYNC
  // ============================================

  Future<void> _uploadSyncItem(SyncQueueItem item) async {
    final compressedPayload = _compressData(item.payload);
    final signature = _generateSignature(compressedPayload);

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppConfig.syncUpload}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': _authToken ?? '',
        'X-Device-ID': _deviceId,
        'X-Signature': signature,
        'Content-Encoding': 'gzip',
      },
      body: compressedPayload,
    );

    if (response.statusCode == 200) {
      _logger.i('Upload successful for ${item.id}');
    } else {
      throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Upload habitation field survey data
  Future<void> uploadHabitationSurvey(Habitation habitation) async {
    await queueForUpload(
      dataType: 'HABITATION',
      data: habitation.toJson(),
    );
  }

  /// Upload shelter resource data
  Future<void> uploadShelterSurvey(SafeShelter shelter) async {
    await queueForUpload(
      dataType: 'SHELTER',
      data: shelter.toJson(),
    );
  }

  // ============================================
  // DOWNLOAD SYNC
  // ============================================

  Future<void> downloadSpatialData() async {
    if (!await _isConnected()) {
      throw Exception('No network connection available');
    }

    final syncId = _generateSyncId();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}${AppConfig.syncDownload}?device_id=$_deviceId'),
      headers: {
        'Authorization': _authToken ?? '',
        'X-Device-ID': _deviceId,
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      await _processDownloadedData(responseData);
      _logger.i('Spatial data download successful');
    } else {
      throw Exception('Download failed: ${response.statusCode}');
    }
  }

  Future<void> _downloadSyncItem(SyncQueueItem item) async {
    await downloadSpatialData();
  }

  Future<void> _processDownloadedData(Map<String, dynamic> data) async {
    // Process hazard zones
    if (data['hazard_zones'] != null) {
      final zones = (data['hazard_zones'] as List)
          .map((json) => HazardZone.fromJson(json as Map<String, dynamic>))
          .toList();
      await _db.saveHazardZones(zones);
    }

    // Process habitations
    if (data['habitations'] != null) {
      final habitations = (data['habitations'] as List)
          .map((json) => Habitation.fromJson(json as Map<String, dynamic>))
          .toList();
      await _db.saveHabitations(habitations);
    }

    // Process shelters
    if (data['shelters'] != null) {
      final shelters = (data['shelters'] as List)
          .map((json) => SafeShelter.fromJson(json as Map<String, dynamic>))
          .toList();
      await _db.saveSafeShelters(shelters);
    }
  }

  // ============================================
  // NETWORK CONNECTIVITY MONITORING
  // ============================================

  Future<bool> _isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Public method to check connectivity (used by forms)
  Future<bool> checkConnectivity() async {
    return await _isConnected();
  }

  void startConnectivityMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _connectivity.onConnectivityChanged.listen((result) async {
      _logger.i('Connectivity changed: $result');

      if (result != ConnectivityResult.none) {
        // Network connected, process queue
        await processQueue();
      }
    });

    _logger.i('Connectivity monitoring started');
  }

  void stopConnectivityMonitoring() {
    _isMonitoring = false;
    _logger.i('Connectivity monitoring stopped');
  }

  // ============================================
  // QUEUE PROCESSING (NEW ARCHITECTURE)
  // ============================================

  /// Process sync queue items from Hive database
  Future<void> processSyncQueue() async {
    if (_isSyncing) {
      _logger.w('Sync already in progress, skipping');
      return;
    }

    if (!await _isConnected()) {
      _logger.w('No network connection, queue will be processed when connected');
      return;
    }

    _isSyncing = true;
    _logger.i('Starting sync queue processing');

    try {
      final pendingItems = await _db.getSyncQueueItemsByStatus('pending');

      for (final item in pendingItems) {
        await _processQueueItem(item);
      }

      _logger.i('Sync queue processing completed');
    } catch (e) {
      _logger.e('Error processing sync queue: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processQueueItem(SyncQueueItem item) async {
    try {
      // Update status to IN_PROGRESS
      item.status = 'in_progress';
      await _db.saveSyncQueueItem(item);

      // Process based on operation type
      if (item.operationType == 'UPDATE_HABITATION') {
        await _uploadHabitationData(item);
      } else if (item.operationType == 'UPDATE_SHELTER') {
        await _uploadShelterData(item);
      }

      // Update status to COMPLETED
      item.status = 'completed';
      await _db.saveSyncQueueItem(item);
      _logger.i('Successfully processed sync item: ${item.id}');
    } catch (e) {
      _logger.e('Failed to process sync item ${item.id}: $e');
      
      // Update status to FAILED and increment retry count
      item.status = 'failed';
      item.retryCount = (item.retryCount ?? 0) + 1;
      await _db.saveSyncQueueItem(item);
    }
  }

  Future<void> _uploadHabitationData(SyncQueueItem item) async {
    final compressedPayload = _compressData(item.payload);
    final signature = _generateSignature(compressedPayload);

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppConfig.syncUpload}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': _authToken ?? '',
        'X-Device-ID': _deviceId,
        'X-Signature': signature,
        'Content-Encoding': 'gzip',
      },
      body: compressedPayload,
    );

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> _uploadShelterData(SyncQueueItem item) async {
    final compressedPayload = _compressData(item.payload);
    final signature = _generateSignature(compressedPayload);

    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}${AppConfig.syncUpload}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': _authToken ?? '',
        'X-Device-ID': _deviceId,
        'X-Signature': signature,
        'Content-Encoding': 'gzip',
      },
      body: compressedPayload,
    );

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
    }
  }

  // ============================================
  // COMPRESSION & SIGNATURE
  // ============================================

  String _compressData(String data) {
    final bytes = utf8.encode(data);
    final compressed = GZipEncoder().encode(bytes);
    return base64Encode(compressed!);
  }

  String _decompressData(String compressedData) {
    final bytes = base64Decode(compressedData);
    final decompressed = GZipDecoder().decodeBytes(bytes);
    return utf8.decode(decompressed);
  }

  String _generateSignature(String data) {
    final key = utf8.encode(_deviceId + (_authToken ?? ''));
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  // ============================================
  // UTILITIES
  // ============================================

  String _generateSyncId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'SYNC_${timestamp}_${_deviceId}';
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.syncStatus}'),
        headers: {
          'Authorization': _authToken ?? '',
          'X-Device-ID': _deviceId,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      _logger.e('Error fetching sync status: $e');
    }

    return {
      'local_pending': (await _db.getPendingSyncItems()).length,
      'is_connected': await _isConnected(),
    };
  }

  Future<void> clearLocalData() async {
    await _db.clearAllData();
    _logger.i('Local data cleared');
  }
}
