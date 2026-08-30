import 'package:hive/hive.dart';

part 'safe_shelter.g.dart';

@HiveType(typeId: 2)
class SafeShelter extends HiveObject {
  @HiveField(0)
  late String shelterId;

  @HiveField(1)
  late String stateCode;

  @HiveField(2)
  late String districtName;

  @HiveField(3)
  late String shelterName;

  @HiveField(4)
  late String shelterType; // SCHOOL, COMMUNITY_CENTER, TEMPLE, GOVT_BUILDING

  @HiveField(5)
  late double latitude;

  @HiveField(6)
  late double longitude;

  // Capacity data
  @HiveField(7)
  late int totalCapacity;

  @HiveField(8)
  late int effectiveCapacity;

  @HiveField(9)
  late int availableCapacity;

  @HiveField(10)
  late double utilizationPercentage;

  // Resources
  @HiveField(11)
  late int currentPopulation;

  @HiveField(12)
  late int waterAvailableLiters;

  @HiveField(13)
  late int foodAvailableKg;

  @HiveField(14)
  late int medicalKitsAvailable;

  @HiveField(15)
  late int generatorFuelLiters;

  // Safety assessment
  @HiveField(16)
  late String capacityConstraint; // WATER, FOOD, SPACE, NONE

  @HiveField(17)
  late String capacityStatus; // LOW, MEDIUM, HIGH, CRITICAL

  @HiveField(18)
  late bool isInSafeZone;

  @HiveField(19)
  late double safetyBufferKm;

  // Infrastructure
  @HiveField(20)
  late bool hasGenerator;

  @HiveField(21)
  late bool hasMedicalFacility;

  @HiveField(22)
  late bool hasKitchen;

  @HiveField(23)
  late bool hasToilets;

  @HiveField(24)
  late String accessRoadStatus; // CLEAR, BLOCKED, DAMAGED

  // WKT geometry for point representation
  @HiveField(25)
  late String geometryWkt;

  @HiveField(26)
  late DateTime evaluationTimestamp;

  @HiveField(27)
  late String modelVersion;

  // Offline sync fields
  @HiveField(28)
  bool isSynced = true;

  @HiveField(29)
  DateTime? lastSyncedAt;

  // Field survey data
  @HiveField(30)
  String? fieldSurveyNotes;

  @HiveField(31)
  DateTime? lastFieldVisit;

  @HiveField(32)
  String? surveyorId;

  SafeShelter();

  SafeShelter.fromJson(Map<String, dynamic> json) {
    shelterId = json['shelter_id'] ?? '';
    stateCode = json['state_code'] ?? '';
    districtName = json['district_name'] ?? '';
    shelterName = json['shelter_name'] ?? '';
    shelterType = json['shelter_type'] ?? 'UNKNOWN';
    latitude = (json['latitude'] as num).toDouble();
    longitude = (json['longitude'] as num).toDouble();
    totalCapacity = json['total_capacity'] as int;
    effectiveCapacity = json['effective_capacity'] as int;
    availableCapacity = json['available_capacity'] as int;
    utilizationPercentage = (json['utilization_percentage'] as num).toDouble();
    currentPopulation = json['current_population'] as int;
    waterAvailableLiters = json['water_available_liters'] as int;
    foodAvailableKg = json['food_available_kg'] as int;
    medicalKitsAvailable = json['medical_kits_available'] as int;
    generatorFuelLiters = json['generator_fuel_liters'] as int;
    capacityConstraint = json['capacity_constraint'] ?? 'NONE';
    capacityStatus = json['capacity_status'] ?? 'UNKNOWN';
    isInSafeZone = json['is_in_safe_zone'] as bool? ?? true;
    safetyBufferKm = (json['safety_buffer_km'] as num?)?.toDouble() ?? 0.0;
    hasGenerator = json['has_generator'] as bool? ?? false;
    hasMedicalFacility = json['has_medical_facility'] as bool? ?? false;
    hasKitchen = json['has_kitchen'] as bool? ?? false;
    hasToilets = json['has_toilets'] as bool? ?? false;
    accessRoadStatus = json['access_road_status'] ?? 'CLEAR';
    geometryWkt = json['geometry_wkt'] ?? '';
    evaluationTimestamp = DateTime.parse(json['evaluation_timestamp']);
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
      'shelter_id': shelterId,
      'state_code': stateCode,
      'district_name': districtName,
      'shelter_name': shelterName,
      'shelter_type': shelterType,
      'latitude': latitude,
      'longitude': longitude,
      'total_capacity': totalCapacity,
      'effective_capacity': effectiveCapacity,
      'available_capacity': availableCapacity,
      'utilization_percentage': utilizationPercentage,
      'current_population': currentPopulation,
      'water_available_liters': waterAvailableLiters,
      'food_available_kg': foodAvailableKg,
      'medical_kits_available': medicalKitsAvailable,
      'generator_fuel_liters': generatorFuelLiters,
      'capacity_constraint': capacityConstraint,
      'capacity_status': capacityStatus,
      'is_in_safe_zone': isInSafeZone,
      'safety_buffer_km': safetyBufferKm,
      'has_generator': hasGenerator,
      'has_medical_facility': hasMedicalFacility,
      'has_kitchen': hasKitchen,
      'has_toilets': hasToilets,
      'access_road_status': accessRoadStatus,
      'geometry_wkt': geometryWkt,
      'evaluation_timestamp': evaluationTimestamp.toIso8601String(),
      'model_version': modelVersion,
      'is_synced': isSynced,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'field_survey_notes': fieldSurveyNotes,
      'last_field_visit': lastFieldVisit?.toIso8601String(),
      'surveyor_id': surveyorId,
    };
  }
}
