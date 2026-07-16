// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 0;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      category: fields[3] as String,
      timeOfDay: fields[4] as String,
      recurrenceType: fields[5] as String,
      customDays: (fields[6] as List).cast<int>(),
      hourlyInterval: fields[7] as int,
      isEnabled: fields[8] as bool,
      notificationId: fields[9] as int,
      createdAt: fields[10] as DateTime,
      completedDates: (fields[11] as List).cast<String>(),
      currentStreak: fields[12] as int,
      longestStreak: fields[13] as int,
      intervalSeconds: fields[14] as int,
      skippedDates: (fields[15] as List).cast<String>(),
      freezeDates: (fields[16] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.timeOfDay)
      ..writeByte(5)
      ..write(obj.recurrenceType)
      ..writeByte(6)
      ..write(obj.customDays)
      ..writeByte(7)
      ..write(obj.hourlyInterval)
      ..writeByte(8)
      ..write(obj.isEnabled)
      ..writeByte(9)
      ..write(obj.notificationId)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.completedDates)
      ..writeByte(12)
      ..write(obj.currentStreak)
      ..writeByte(13)
      ..write(obj.longestStreak)
      ..writeByte(14)
      ..write(obj.intervalSeconds)
      ..writeByte(15)
      ..write(obj.skippedDates)
      ..writeByte(16)
      ..write(obj.freezeDates);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
