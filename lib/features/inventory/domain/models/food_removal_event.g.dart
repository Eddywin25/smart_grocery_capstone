// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_removal_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FoodRemovalEventAdapter extends TypeAdapter<FoodRemovalEvent> {
  @override
  final int typeId = 10;

  @override
  FoodRemovalEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodRemovalEvent(
      itemName: fields[0] as String,
      outcome: fields[1] as FoodItemOutcome,
      eventDate: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FoodRemovalEvent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.itemName)
      ..writeByte(1)
      ..write(obj.outcome)
      ..writeByte(2)
      ..write(obj.eventDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodRemovalEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
