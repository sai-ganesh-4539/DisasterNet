// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habitation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitationAdapter extends TypeAdapter<Habitation> {
  @override
  final int typeId = 1;

  @override
  Habitation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habitation()
      ..habitationId = fields[0] as String
      ..stateCode = fields[1] as String
      ..districtName = fields[2] as String
      ..villageName = fields[3] as String
      ..latitude = fields[4] as double
      ..longitude = fields[5] as double
      ..totalPopulation = fields[6] as int
      ..malePopulation = fields[7] as int
      ..femalePopulation = fields[8] as int
      ..population0to6 = fields[9] as int
      ..population60Plus = fields[10] as int
      ..literacyRate = fields[11] as double
      ..priorityScore = fields[12] as double
      ..priorityCategory = fields[13] as String
      ..expertCategory = fields[14] as String
      ..mlCategory = fields[15] as String
      ..proximityToHazardKm = fields[16] as double
      ..elevation = fields[17] as double
      ..slopePercentage = fields[18] as double
      ..hasAccessRoad = fields[19] as bool
      ..pathStatus = fields[20] as String
      ..geometryWkt = fields[21] as String
      ..assessmentTimestamp = fields[22] as DateTime
      ..modelVersion = fields[23] as String
      ..isSynced = fields[24] as bool
      ..lastSyncedAt = fields[25] as DateTime?
      ..fieldSurveyNotes = fields[26] as String?
      ..lastFieldVisit = fields[27] as DateTime?
      ..surveyorId = fields[28] as String?;
  }

  @override
  void write(BinaryWriter writer, Habitation obj) {
    writer
      ..writeByte(29)
      ..writeByte(0)
      ..write(obj.habitationId)
      ..writeByte(1)
      ..write(obj.stateCode)
      ..writeByte(2)
      ..write(obj.districtName)
      ..writeByte(3)
      ..write(obj.villageName)
      ..writeByte(4)
      ..write(obj.latitude)
      ..writeByte(5)
      ..write(obj.longitude)
      ..writeByte(6)
      ..write(obj.totalPopulation)
      ..writeByte(7)
      ..write(obj.malePopulation)
      ..writeByte(8)
      ..write(obj.femalePopulation)
      ..writeByte(9)
      ..write(obj.population0to6)
      ..writeByte(10)
      ..write(obj.population60Plus)
      ..writeByte(11)
      ..write(obj.literacyRate)
      ..writeByte(12)
      ..write(obj.priorityScore)
      ..writeByte(13)
      ..write(obj.priorityCategory)
      ..writeByte(14)
      ..write(obj.expertCategory)
      ..writeByte(15)
      ..write(obj.mlCategory)
      ..writeByte(16)
      ..write(obj.proximityToHazardKm)
      ..writeByte(17)
      ..write(obj.elevation)
      ..writeByte(18)
      ..write(obj.slopePercentage)
      ..writeByte(19)
      ..write(obj.hasAccessRoad)
      ..writeByte(20)
      ..write(obj.pathStatus)
      ..writeByte(21)
      ..write(obj.geometryWkt)
      ..writeByte(22)
      ..write(obj.assessmentTimestamp)
      ..writeByte(23)
      ..write(obj.modelVersion)
      ..writeByte(24)
      ..write(obj.isSynced)
      ..writeByte(25)
      ..write(obj.lastSyncedAt)
      ..writeByte(26)
      ..write(obj.fieldSurveyNotes)
      ..writeByte(27)
      ..write(obj.lastFieldVisit)
      ..writeByte(28)
      ..write(obj.surveyorId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
