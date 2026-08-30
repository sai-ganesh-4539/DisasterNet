// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'safe_shelter.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SafeShelterAdapter extends TypeAdapter<SafeShelter> {
  @override
  final int typeId = 2;

  @override
  SafeShelter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SafeShelter()
      ..shelterId = fields[0] as String
      ..stateCode = fields[1] as String
      ..districtName = fields[2] as String
      ..shelterName = fields[3] as String
      ..shelterType = fields[4] as String
      ..latitude = fields[5] as double
      ..longitude = fields[6] as double
      ..totalCapacity = fields[7] as int
      ..effectiveCapacity = fields[8] as int
      ..availableCapacity = fields[9] as int
      ..utilizationPercentage = fields[10] as double
      ..currentPopulation = fields[11] as int
      ..waterAvailableLiters = fields[12] as int
      ..foodAvailableKg = fields[13] as int
      ..medicalKitsAvailable = fields[14] as int
      ..generatorFuelLiters = fields[15] as int
      ..capacityConstraint = fields[16] as String
      ..capacityStatus = fields[17] as String
      ..isInSafeZone = fields[18] as bool
      ..safetyBufferKm = fields[19] as double
      ..hasGenerator = fields[20] as bool
      ..hasMedicalFacility = fields[21] as bool
      ..hasKitchen = fields[22] as bool
      ..hasToilets = fields[23] as bool
      ..accessRoadStatus = fields[24] as String
      ..geometryWkt = fields[25] as String
      ..evaluationTimestamp = fields[26] as DateTime
      ..modelVersion = fields[27] as String
      ..isSynced = fields[28] as bool
      ..lastSyncedAt = fields[29] as DateTime?
      ..fieldSurveyNotes = fields[30] as String?
      ..lastFieldVisit = fields[31] as DateTime?
      ..surveyorId = fields[32] as String?;
  }

  @override
  void write(BinaryWriter writer, SafeShelter obj) {
    writer
      ..writeByte(33)
      ..writeByte(0)
      ..write(obj.shelterId)
      ..writeByte(1)
      ..write(obj.stateCode)
      ..writeByte(2)
      ..write(obj.districtName)
      ..writeByte(3)
      ..write(obj.shelterName)
      ..writeByte(4)
      ..write(obj.shelterType)
      ..writeByte(5)
      ..write(obj.latitude)
      ..writeByte(6)
      ..write(obj.longitude)
      ..writeByte(7)
      ..write(obj.totalCapacity)
      ..writeByte(8)
      ..write(obj.effectiveCapacity)
      ..writeByte(9)
      ..write(obj.availableCapacity)
      ..writeByte(10)
      ..write(obj.utilizationPercentage)
      ..writeByte(11)
      ..write(obj.currentPopulation)
      ..writeByte(12)
      ..write(obj.waterAvailableLiters)
      ..writeByte(13)
      ..write(obj.foodAvailableKg)
      ..writeByte(14)
      ..write(obj.medicalKitsAvailable)
      ..writeByte(15)
      ..write(obj.generatorFuelLiters)
      ..writeByte(16)
      ..write(obj.capacityConstraint)
      ..writeByte(17)
      ..write(obj.capacityStatus)
      ..writeByte(18)
      ..write(obj.isInSafeZone)
      ..writeByte(19)
      ..write(obj.safetyBufferKm)
      ..writeByte(20)
      ..write(obj.hasGenerator)
      ..writeByte(21)
      ..write(obj.hasMedicalFacility)
      ..writeByte(22)
      ..write(obj.hasKitchen)
      ..writeByte(23)
      ..write(obj.hasToilets)
      ..writeByte(24)
      ..write(obj.accessRoadStatus)
      ..writeByte(25)
      ..write(obj.geometryWkt)
      ..writeByte(26)
      ..write(obj.evaluationTimestamp)
      ..writeByte(27)
      ..write(obj.modelVersion)
      ..writeByte(28)
      ..write(obj.isSynced)
      ..writeByte(29)
      ..write(obj.lastSyncedAt)
      ..writeByte(30)
      ..write(obj.fieldSurveyNotes)
      ..writeByte(31)
      ..write(obj.lastFieldVisit)
      ..writeByte(32)
      ..write(obj.surveyorId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafeShelterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
