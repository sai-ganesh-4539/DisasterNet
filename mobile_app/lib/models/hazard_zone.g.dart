// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hazard_zone.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HazardZoneAdapter extends TypeAdapter<HazardZone> {
  @override
  final int typeId = 0;

  @override
  HazardZone read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HazardZone()
      ..zoneId = fields[0] as String
      ..gridId = fields[1] as String
      ..latitude = fields[2] as double
      ..longitude = fields[3] as double
      ..riskScore = fields[4] as double
      ..isRedZone = fields[5] as bool
      ..riskLevel = fields[6] as String
      ..hazardType = fields[7] as String
      ..geometryWkt = fields[8] as String
      ..predictionTimestamp = fields[9] as DateTime
      ..modelVersion = fields[10] as String
      ..isSynced = fields[11] as bool
      ..lastSyncedAt = fields[12] as DateTime?
      ..timeHorizon = fields[13] as String?;
  }

  @override
  void write(BinaryWriter writer, HazardZone obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.zoneId)
      ..writeByte(1)
      ..write(obj.gridId)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.riskScore)
      ..writeByte(5)
      ..write(obj.isRedZone)
      ..writeByte(6)
      ..write(obj.riskLevel)
      ..writeByte(7)
      ..write(obj.hazardType)
      ..writeByte(8)
      ..write(obj.geometryWkt)
      ..writeByte(9)
      ..write(obj.predictionTimestamp)
      ..writeByte(10)
      ..write(obj.modelVersion)
      ..writeByte(11)
      ..write(obj.isSynced)
      ..writeByte(12)
      ..write(obj.lastSyncedAt)
      ..writeByte(13)
      ..write(obj.timeHorizon);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HazardZoneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
