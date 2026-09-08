import 'dart:convert';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:flutter/foundation.dart';

/// Result of an SOS dispatch attempt.
class SosDispatchResult {
  /// True if the SOS was successfully received by any layer.
  final bool delivered;

  /// The layer that finally accepted the SOS.
  /// SERVER_DIRECT | MESH_RELAY | SMS_GATEWAY | LOCAL_ONLY
  final String deliveredLayer;

  /// True if the SOS was staged for mesh propagation (i.e. no path to server).
  final bool stagedForMesh;

  /// True if the SOS was queued for SMS gateway fallback.
  final bool stagedForSms;

  /// Human-readable status summary suitable for UI display.
  final String message;

  /// The SOS payload (canonical form, useful for re-relay).
  final Map<String, dynamic> payload;

  SosDispatchResult({
    required this.delivered,
    required this.deliveredLayer,
    required this.stagedForMesh,
    required this.stagedForSms,
    required this.message,
    required this.payload,
  });
}

/// A phone-to-phone mesh queue item — stored locally and broadcast to
/// nearby devices over Bluetooth LE / Wi-Fi Direct when available.
class MeshQueueItem {
  final String sosId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int hopCount;
  List<String> relayedThrough;
  String status; // 'pending' | 'relayed' | 'delivered' | 'expired'

  MeshQueueItem({
    required this.sosId,
    required this.payload,
    required this.createdAt,
    this.hopCount = 0,
    List<String>? relayedThrough,
    this.status = 'pending',
  }) : relayedThrough = relayedThrough ?? [];

  Map<String, dynamic> toJson() => {
        'sos_id': sosId,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'hop_count': hopCount,
        'relayed_through': relayedThrough,
        'status': status,
      };

  factory MeshQueueItem.fromJson(Map<String, dynamic> json) => MeshQueueItem(
        sosId: json['sos_id'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['created_at'] as String),
        hopCount: json['hop_count'] as int? ?? 0,
        relayedThrough:
            (json['relayed_through'] as List? ?? []).map((e) => e.toString()).toList(),
        status: json['status'] as String? ?? 'pending',
      );
}

/// Offline SOS service implementing the layered fallback chain:
///   1. Server direct (HTTPS POST)
///   2. Phone-to-phone mesh relay (Bluetooth LE / Wi-Fi Direct)
///   3. SMS gateway fallback
///
/// In a real deployment, the BLE/Wi-Fi Direct discovery & transmission
/// would use `flutter_nearby` or `nearby_connections` plugin. For this
/// prototype, we stub the actual BLE transport but implement the queue
/// management, dedup, hop count, and server-relay logic that any
/// transport would feed into.
class SosService extends ChangeNotifier {
  SosService._();
  static final SosService instance = SosService._();

  final Connectivity _connectivity = Connectivity();

  /// Local mesh queue — SOSes that need to be propagated to / relayed by
  /// other phones in the mesh.
  final List<MeshQueueItem> _meshQueue = [];

  /// SMS queue — SOSes that have exhausted all server/mesh options and
  /// are waiting for the SMS gateway fallback.
  final List<MeshQueueItem> _smsQueue = [];

  /// Recently delivered SOSes — kept for UI status display.
  final List<Map<String, dynamic>> _recentDispatches = [];

  List<MeshQueueItem> get meshQueue => List.unmodifiable(_meshQueue);
  List<MeshQueueItem> get smsQueue => List.unmodifiable(_smsQueue);
  List<Map<String, dynamic>> get recentDispatches => List.unmodifiable(_recentDispatches);

  String? _deviceId;
  String? _authToken;

  Future<void> initialize({required String deviceId, String? authToken}) async {
    _deviceId = deviceId;
    _authToken = authToken;
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Dispatch an SOS through the layered fallback chain.
  ///
  /// [latitude] and [longitude] are required. Other fields are
  /// optional. The function tries each fallback layer in order:
  ///   1. Direct HTTPS POST to /api/v1/sos/submit
  ///   2. Stage in mesh queue + simulate broadcast to nearby phones
  ///   3. Stage in SMS queue with a compact payload
  ///
  /// Returns a [SosDispatchResult] describing what happened.
  Future<SosDispatchResult> dispatchSos({
    required double latitude,
    required double longitude,
    String category = 'MEDICAL',
    String severity = 'HIGH',
    String message = '',
    int? peopleCount,
    String? contactPhone,
  }) async {
    final sosId = _genUuid();
    final payload = <String, dynamic>{
      'sos_id': sosId,
      'device_id': _deviceId ?? 'UNKNOWN-DEVICE',
      'user_id': null,
      'role': null,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'severity': severity,
      'message': message,
      if (peopleCount != null) 'people_count': peopleCount,
      if (contactPhone != null) 'contact_phone': contactPhone,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'origin_layer': 'SERVER_DIRECT',
      'relayed_through': [_deviceId ?? 'UNKNOWN-DEVICE'],
      'hop_count': 0,
    };

    // Layer 1 — try direct server
    final connectivity = await _connectivity.checkConnectivity();
    final isOnline = connectivity.any((c) => c != ConnectivityResult.none);

    if (isOnline) {
      final result = await LiveGisApi.sosSubmit(
        deviceId: _deviceId ?? 'UNKNOWN-DEVICE',
        latitude: latitude,
        longitude: longitude,
        category: category,
        severity: severity,
        message: message,
        peopleCount: peopleCount,
        contactPhone: contactPhone,
        originLayer: 'SERVER_DIRECT',
        token: _authToken,
      );
      if (result != null && result['accepted'] == true) {
        _recentDispatches.insert(0, {
          'sos_id': sosId,
          'layer': 'SERVER_DIRECT',
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Delivered to central server directly.',
        });
        notifyListeners();
        return SosDispatchResult(
          delivered: true,
          deliveredLayer: 'SERVER_DIRECT',
          stagedForMesh: false,
          stagedForSms: false,
          message: 'SOS delivered to the central disaster response server.',
          payload: payload,
        );
      }
    }

    // Layer 2 — stage in mesh queue + simulate broadcast
    final meshItem = MeshQueueItem(
      sosId: sosId,
      payload: Map<String, dynamic>.from(payload)
        ..['origin_layer'] = 'MESH_RELAY',
      createdAt: DateTime.now(),
      hopCount: 0,
      relayedThrough: [_deviceId ?? 'UNKNOWN-DEVICE'],
    );
    _meshQueue.add(meshItem);
    notifyListeners();

    // Simulate mesh propagation by attempting server relay (as if a
    // nearby phone had picked it up and relayed it).
    final meshRelayResult = await LiveGisApi.sosRelay(
      deviceId: _deviceId ?? 'UNKNOWN-DEVICE',
      sosPayload: meshItem.payload,
      token: _authToken,
    );

    if (meshRelayResult != null && meshRelayResult['accepted'] == true) {
      _meshQueue.removeWhere((i) => i.sosId == sosId);
      _recentDispatches.insert(0, {
        'sos_id': sosId,
        'layer': 'MESH_RELAY',
        'timestamp': DateTime.now().toIso8601String(),
        'message':
            'No cellular data on this device — SOS relayed through the phone-to-phone mesh to a node with connectivity.',
      });
      notifyListeners();
      return SosDispatchResult(
        delivered: true,
        deliveredLayer: 'MESH_RELAY',
        stagedForMesh: false,
        stagedForSms: false,
        message:
            'No cellular data on this device — SOS was relayed through the phone-to-phone mesh to a node with connectivity.',
        payload: meshItem.payload,
      );
    }

    // Layer 3 — stage in SMS queue and return
    payload['origin_layer'] = 'SMS_GATEWAY';
    final smsItem = MeshQueueItem(
      sosId: sosId,
      payload: payload,
      createdAt: DateTime.now(),
      hopCount: 0,
      relayedThrough: [_deviceId ?? 'UNKNOWN-DEVICE'],
    );
    _smsQueue.add(smsItem);
    notifyListeners();

    _recentDispatches.insert(0, {
      'sos_id': sosId,
      'layer': 'SMS_GATEWAY',
      'timestamp': DateTime.now().toIso8601String(),
      'message':
          'No data or mesh nodes available — SOS queued for SMS gateway fallback. It will be sent as a structured SMS to the gateway number when the device regains cellular voice coverage.',
    });
    notifyListeners();

    return SosDispatchResult(
      delivered: false,
      deliveredLayer: 'LOCAL_ONLY',
      stagedForMesh: true,
      stagedForSms: true,
      message:
          'No data or mesh nodes available — SOS queued for SMS gateway fallback. It will be sent as a structured SMS when cellular voice coverage returns.',
      payload: payload,
    );
  }

  /// Background retry — called whenever connectivity changes (see
  /// MainScreen's connectivity subscription).
  Future<int> retryQueued() async {
    var processed = 0;
    if (_meshQueue.isEmpty && _smsQueue.isEmpty) return 0;

    final connectivity = await _connectivity.checkConnectivity();
    final isOnline = connectivity.any((c) => c != ConnectivityResult.none);
    if (!isOnline) return 0;

    // Try mesh queue first
    final meshCopy = List<MeshQueueItem>.from(_meshQueue);
    for (final item in meshCopy) {
      final result = await LiveGisApi.sosSubmit(
        deviceId: _deviceId ?? 'UNKNOWN-DEVICE',
        latitude: (item.payload['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (item.payload['longitude'] as num?)?.toDouble() ?? 0.0,
        category: item.payload['category']?.toString() ?? 'MEDICAL',
        severity: item.payload['severity']?.toString() ?? 'HIGH',
        message: item.payload['message']?.toString() ?? '',
        peopleCount: item.payload['people_count'] as int?,
        contactPhone: item.payload['contact_phone']?.toString(),
        originLayer: 'MESH_RELAY',
        relayedThrough: item.relayedThrough,
        hopCount: item.hopCount,
        token: _authToken,
      );
      if (result != null && result['accepted'] == true) {
        _meshQueue.removeWhere((i) => i.sosId == item.sosId);
        _recentDispatches.insert(0, {
          'sos_id': item.sosId,
          'layer': 'MESH_RELAY',
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Queued SOS delivered via mesh relay (background retry).',
        });
        processed++;
      }
    }

    // Then SMS queue
    final smsCopy = List<MeshQueueItem>.from(_smsQueue);
    for (final item in smsCopy) {
      // In production: build an SMS payload and call the platform SMS API
      // (e.g. telephony plugin). For this prototype, we just attempt a
      // direct server POST with origin_layer = SMS_GATEWAY so the audit
      // trail reflects the path.
      final result = await LiveGisApi.sosSubmit(
        deviceId: _deviceId ?? 'UNKNOWN-DEVICE',
        latitude: (item.payload['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (item.payload['longitude'] as num?)?.toDouble() ?? 0.0,
        category: item.payload['category']?.toString() ?? 'MEDICAL',
        severity: item.payload['severity']?.toString() ?? 'HIGH',
        message: item.payload['message']?.toString() ?? '',
        peopleCount: item.payload['people_count'] as int?,
        contactPhone: item.payload['contact_phone']?.toString(),
        originLayer: 'SMS_GATEWAY',
        relayedThrough: item.relayedThrough,
        hopCount: item.hopCount,
        token: _authToken,
      );
      if (result != null && result['accepted'] == true) {
        _smsQueue.removeWhere((i) => i.sosId == item.sosId);
        _recentDispatches.insert(0, {
          'sos_id': item.sosId,
          'layer': 'SMS_GATEWAY',
          'timestamp': DateTime.now().toIso8601String(),
          'message': 'Queued SOS delivered via SMS gateway fallback (background retry).',
        });
        processed++;
      }
    }

    if (processed > 0) notifyListeners();
    return processed;
  }

  /// Build the compact SMS payload that would be sent to the SMS gateway.
  /// Format: DN|<sos_id>|<lat>|<lon>|<cat>|<sev>|<msg[:80]>
  String buildSmsPayload(Map<String, dynamic> payload) {
    final msg = (payload['message']?.toString() ?? '').replaceAll('\n', ' ');
    final msgTrimmed = msg.length > 80 ? msg.substring(0, 80) : msg;
    return 'DN|${payload['sos_id']}|${payload['latitude']}|${payload['longitude']}|${payload['category']}|${payload['severity']}|$msgTrimmed';
  }

  /// Receive an SOS from another device in the mesh (i.e. this device
  /// picked up a broadcast from a peer). Stage it in the mesh queue and
  /// attempt to relay to the server.
  Future<void> receiveMeshSos(Map<String, dynamic> sosPayload) async {
    final sosId = sosPayload['sos_id']?.toString();
    if (sosId == null) return;

    // Dedup: don't re-stage an SOS we already have.
    if (_meshQueue.any((i) => i.sosId == sosId)) return;

    final item = MeshQueueItem(
      sosId: sosId,
      payload: Map<String, dynamic>.from(sosPayload),
      createdAt: DateTime.now(),
      hopCount: (sosPayload['hop_count'] as int? ?? 0) + 1,
      relayedThrough: [
        ...((sosPayload['relayed_through'] as List? ?? []).map((e) => e.toString())),
        _deviceId ?? 'UNKNOWN-DEVICE',
      ],
    );
    _meshQueue.add(item);
    notifyListeners();

    // Try to relay to server immediately (we may have connectivity even
    // if the originating phone doesn't)
    final connectivity = await _connectivity.checkConnectivity();
    final isOnline = connectivity.any((c) => c != ConnectivityResult.none);
    if (isOnline) {
      final result = await LiveGisApi.sosRelay(
        deviceId: _deviceId ?? 'UNKNOWN-DEVICE',
        sosPayload: item.payload,
        token: _authToken,
      );
      if (result != null && result['accepted'] == true) {
        _meshQueue.removeWhere((i) => i.sosId == sosId);
        _recentDispatches.insert(0, {
          'sos_id': sosId,
          'layer': 'MESH_RELAY',
          'timestamp': DateTime.now().toIso8601String(),
          'message':
              'Relayed a peer SOS (from ${item.relayedThrough.first}) to the central server.',
        });
        notifyListeners();
      }
    }
  }

  String _genUuid() {
    final r = math.Random();
    final hex = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
