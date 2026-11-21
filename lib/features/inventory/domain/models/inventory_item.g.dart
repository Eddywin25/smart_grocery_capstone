// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryItemAdapter extends TypeAdapter<InventoryItem> {
  @override
  final int typeId = 0;

  @override
  InventoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryItem(
      id: fields[0] as String,
      name: fields[1] as String,
      quantity: fields[2] as int,
      location: fields[3] as StorageLocation,
      purchaseDate: fields[4] as DateTime,
      expiryDate: fields[5] as DateTime,
      packageType: fields[6] as Package,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.location)
      ..writeByte(4)
      ..write(obj.purchaseDate)
      ..writeByte(5)
      ..write(obj.expiryDate)
      ..writeByte(6)
      ..write(obj.packageType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StorageLocationAdapter extends TypeAdapter<StorageLocation> {
  @override
  final int typeId = 1;

  @override
  StorageLocation read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StorageLocation.fridge;
      case 1:
        return StorageLocation.freezer;
      case 2:
        return StorageLocation.pantry;
      case 3:
        return StorageLocation.counter;
      default:
        return StorageLocation.fridge;
    }
  }

  @override
  void write(BinaryWriter writer, StorageLocation obj) {
    switch (obj) {
      case StorageLocation.fridge:
        writer.writeByte(0);
        break;
      case StorageLocation.freezer:
        writer.writeByte(1);
        break;
      case StorageLocation.pantry:
        writer.writeByte(2);
        break;
      case StorageLocation.counter:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageLocationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PackageAdapter extends TypeAdapter<Package> {
  @override
  final int typeId = 2;

  @override
  Package read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Package.box;
      case 1:
        return Package.cup;
      case 2:
        return Package.bag;
      case 3:
        return Package.package;
      case 4:
        return Package.pouch;
      case 5:
        return Package.bottle;
      case 6:
        return Package.jug;
      case 7:
        return Package.jar;
      case 8:
        return Package.item;
      default:
        return Package.box;
    }
  }

  @override
  void write(BinaryWriter writer, Package obj) {
    switch (obj) {
      case Package.box:
        writer.writeByte(0);
        break;
      case Package.cup:
        writer.writeByte(1);
        break;
      case Package.bag:
        writer.writeByte(2);
        break;
      case Package.package:
        writer.writeByte(3);
        break;
      case Package.pouch:
        writer.writeByte(4);
        break;
      case Package.bottle:
        writer.writeByte(5);
        break;
      case Package.jug:
        writer.writeByte(6);
        break;
      case Package.jar:
        writer.writeByte(7);
        break;
      case Package.item:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FoodItemOutcomeAdapter extends TypeAdapter<FoodItemOutcome> {
  @override
  final int typeId = 3;

  @override
  FoodItemOutcome read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FoodItemOutcome.finished;
      case 1:
        return FoodItemOutcome.spoiled;
      case 2:
        return FoodItemOutcome.deleted;
      default:
        return FoodItemOutcome.finished;
    }
  }

  @override
  void write(BinaryWriter writer, FoodItemOutcome obj) {
    switch (obj) {
      case FoodItemOutcome.finished:
        writer.writeByte(0);
        break;
      case FoodItemOutcome.spoiled:
        writer.writeByte(1);
        break;
      case FoodItemOutcome.deleted:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodItemOutcomeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
