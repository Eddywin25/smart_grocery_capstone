import '../../domain/models/inventory_item.dart';
import 'package:hive/hive.dart';
part 'food_removal_event.g.dart';

// Food removal event settings
@HiveType(typeId: 10)
class FoodRemovalEvent {

  @HiveField(0)
  final String itemName;

  @HiveField(1)
  final FoodItemOutcome outcome;

  @HiveField(2)
  final DateTime eventDate;
  
  @HiveField(3)
  final int quantity;

  @HiveField(4)
  final Package packageType;

  const FoodRemovalEvent({
    required this.itemName,
    required this.outcome,
    required this.eventDate,
    required this.quantity,
    required this.packageType,
  });
}