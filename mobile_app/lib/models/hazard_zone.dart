import 'package:hive/hive.dart';

part 'hazard_zone.g.dart';

@HiveType(typeId: 0)
class HazardZone extends HiveObject {
  @HiveField(0)
  late String zoneId;

  @HiveField(1)
  late String gridId;

  @HiveField(2)
  late double latitude;

  @HiveField(3)
  late double longitude;

  @HiveField(4)
  late double riskScore;

  @HiveField(5)
  late bool isRedZone;

  @HiveField(6)
  late String riskLevel;

  @HiveField(7)
  late String hazardType;

  // WKT geometry for polygon representation
  @HiveField(8)
  late String geometryWkt;

  @HiveField(9)
  late DateTime predictionTimestamp;

  @HiveField(10)
  late String modelVersion;

  // Offline sync fields
  @HiveField(11)
  bool isSynced = true;

  @HiveField(12)
  DateTime? lastSyncedAt;

  // Time horizon category
  @HiveField(13)
  String? timeHorizon; // IMMEDIATE, SHORT_TERM, MEDIUM_TERM

  HazardZone();

  HazardZone.fromJson(Map<String, dynamic> json) {
    zoneId = json['zone_id'] ?? '';
    gridId = json['grid_id'] ?? '';
    latitude = (json['latitude'] as num).toDouble();
    longitude = (json['longitude'] as num).toDouble();
    riskScore = (json['risk_score'] as num).toDouble();
    isRedZone = json['is_red_zone'] as bool;
    riskLevel = json['risk_level'] ?? 'UNKNOWN';
    hazardType = json['hazard_type'] ?? 'UNKNOWN';
    geometryWkt = json['geometry_wkt'] ?? '';
    predictionTimestamp = DateTime.parse(json['prediction_timestamp']);
    modelVersion = json['model_version'] ?? '1.0.0';
    isSynced = json['is_synced'] ?? true;
    lastSyncedAt = json['last_synced_at'] != null
        ? DateTime.parse(json['last_synced_at'])
        : null;
    timeHorizon = json['time_horizon'];
  }

  Map<String, dynamic> toJson() {
    return {
      'zone_id': zoneId,
      'grid_id': gridId,
      'latitude': latitude,
      'longitude': longitude,
      'risk_score': riskScore,
      'is_red_zone': isRedZone,
      'risk_level': riskLevel,
      'hazard_type': hazardType,
      'geometry_wkt': geometryWkt,
      'prediction_timestamp': predictionTimestamp.toIso8601String(),
      'model_version': modelVersion,
      'is_synced': isSynced,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'time_horizon': timeHorizon,
    };
  }
}
