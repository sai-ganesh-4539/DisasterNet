import 'package:hive/hive.dart';

part 'habitation.g.dart';

@HiveType(typeId: 1)
class Habitation extends HiveObject {
  @HiveField(0)
  late String habitationId;

  @HiveField(1)
  late String stateCode;

  @HiveField(2)
  late String districtName;

  @HiveField(3)
  late String villageName;

  @HiveField(4)
  late double latitude;

  @HiveField(5)
  late double longitude;

  // Population data
  @HiveField(6)
  late int totalPopulation;

  @HiveField(7)
  late int malePopulation;

  @HiveField(8)
  late int femalePopulation;

  @HiveField(9)
  late int population0to6;

  @HiveField(10)
  late int population60Plus;

  @HiveField(11)
  late double literacyRate;

  // Priority assessment
  @HiveField(12)
  late double priorityScore;

  @HiveField(13)
  late String priorityCategory; // IMMEDIATE, SHORT_TERM, MEDIUM_TERM

  @HiveField(14)
  late String expertCategory;

  @HiveField(15)
  late String mlCategory;

  // Vulnerability factors
  @HiveField(16)
  late double proximityToHazardKm;

  @HiveField(17)
  late double elevation;

  @HiveField(18)
  late double slopePercentage;

  @HiveField(19)
  late bool hasAccessRoad;

  @HiveField(20)
  late String pathStatus; // CLEAR, BLOCKED, DAMAGED

  // WKT geometry for point representation
  @HiveField(21)
  late String geometryWkt;

  @HiveField(22)
  late DateTime assessmentTimestamp;

  @HiveField(23)
  late String modelVersion;

  // Offline sync fields
  @HiveField(24)
  bool isSynced = true;

  @HiveField(25)
  DateTime? lastSyncedAt;

  // Field survey data
  @HiveField(26)
  String? fieldSurveyNotes;

  @HiveField(27)
  DateTime? lastFieldVisit;

  @HiveField(28)
  String? surveyorId;

  Habitation();

  Habitation.fromJson(Map<String, dynamic> json) {
    habitationId = json['habitation_id'] ?? '';
    stateCode = json['state_code'] ?? '';
    districtName = json['district_name'] ?? '';
    villageName = json['village_name'] ?? '';
    latitude = (json['latitude'] as num).toDouble();
    longitude = (json['longitude'] as num).toDouble();
    totalPopulation = json['total_population'] as int;
    malePopulation = json['male_population'] as int;
    femalePopulation = json['female_population'] as int;
    population0to6 = json['population_0_6'] as int;
    population60Plus = json['population_60_plus'] as int;
    literacyRate = (json['literacy_rate'] as num).toDouble();
    priorityScore = (json['priority_score'] as num).toDouble();
    priorityCategory = json['priority_category'] ?? 'UNKNOWN';
    expertCategory = json['expert_category'] ?? 'UNKNOWN';
    mlCategory = json['ml_category'] ?? 'UNKNOWN';
    proximityToHazardKm = (json['proximity_to_hazard_km'] as num?)?.toDouble() ?? 0.0;
    elevation = (json['elevation'] as num?)?.toDouble() ?? 0.0;
    slopePercentage = (json['slope_percentage'] as num?)?.toDouble() ?? 0.0;
    hasAccessRoad = json['has_access_road'] as bool? ?? true;
    pathStatus = json['path_status'] ?? 'CLEAR';
    geometryWkt = json['geometry_wkt'] ?? '';
    assessmentTimestamp = DateTime.parse(json['assessment_timestamp']);
    modelVersion = json['model_version'] ?? '1.0.0';
    isSynced = json['is_synced'] ?? true;
    lastSyncedAt = json['last_synced_at'] != null
        ? DateTime.parse(json['last_synced_at'])
        : null;
    fieldSurveyNotes = json['field_survey_notes'];
    lastFieldVisit = json['last_field_visit'] != null
        ? DateTime.parse(json['last_field_visit'])
        : null;
    surveyorId = json['surveyor_id'];
  }

  Map<String, dynamic> toJson() {
    return {
      'habitation_id': habitationId,
      'state_code': stateCode,
      'district_name': districtName,
      'village_name': villageName,
      'latitude': latitude,
      'longitude': longitude,
      'total_population': totalPopulation,
      'male_population': malePopulation,
      'female_population': femalePopulation,
      'population_0_6': population0to6,
      'population_60_plus': population60Plus,
      'literacy_rate': literacyRate,
      'priority_score': priorityScore,
      'priority_category': priorityCategory,
      'expert_category': expertCategory,
      'ml_category': mlCategory,
      'proximity_to_hazard_km': proximityToHazardKm,
      'elevation': elevation,
      'slope_percentage': slopePercentage,
      'has_access_road': hasAccessRoad,
      'path_status': pathStatus,
      'geometry_wkt': geometryWkt,
      'assessment_timestamp': assessmentTimestamp.toIso8601String(),
      'model_version': modelVersion,
      'is_synced': isSynced,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'field_survey_notes': fieldSurveyNotes,
      'last_field_visit': lastFieldVisit?.toIso8601String(),
      'surveyor_id': surveyorId,
    };
  }
}
