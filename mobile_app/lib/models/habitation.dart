import 'package:field_app/core/json_coercion.dart';
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
    habitationId = asString(json['habitation_id']);
    stateCode = asString(json['state_code'], 'IN');
    districtName = asString(json['district_name']);
    villageName = asString(json['village_name'], 'Unnamed settlement');
    latitude = asDouble(json['latitude']);
    longitude = asDouble(json['longitude']);
    totalPopulation = asInt(json['total_population']);
    malePopulation = asInt(json['male_population'], totalPopulation ~/ 2);
    femalePopulation = asInt(json['female_population'], totalPopulation - malePopulation);
    population0to6 = asInt(json['population_0_6']);
    population60Plus = asInt(json['population_60_plus']);
    literacyRate = asDouble(json['literacy_rate']);
    priorityScore = asDouble(json['priority_score']);
    priorityCategory = asString(json['priority_category'], 'MEDIUM_TERM');
    expertCategory = asString(json['expert_category'], priorityCategory);
    mlCategory = asString(json['ml_category'], priorityCategory);
    proximityToHazardKm = asDouble(json['proximity_to_hazard_km']);
    elevation = asDouble(json['elevation']);
    slopePercentage = asDouble(json['slope_percentage']);
    hasAccessRoad = asBool(json['has_access_road'], true);
    pathStatus = asString(json['path_status'], 'CLEAR');
    geometryWkt = asString(json['geometry_wkt']);
    assessmentTimestamp = asDateTime(json['assessment_timestamp']);
    modelVersion = asString(json['model_version'], '3.0.0');
    isSynced = asBool(json['is_synced'], true);
    lastSyncedAt = json['last_synced_at'] != null ? asDateTime(json['last_synced_at']) : DateTime.now().toUtc();
    fieldSurveyNotes = json['field_survey_notes']?.toString();
    lastFieldVisit = json['last_field_visit'] != null ? asDateTime(json['last_field_visit']) : null;
    surveyorId = json['surveyor_id']?.toString();
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
