import 'package:hive/hive.dart';
import 'package:smart_grocery/features/inventory/domain/models/food_removal_event.dart';


// Class for handling food history records
class FoodHistoryRepository {

  final Box<FoodRemovalEvent>
      _foodHistoryBox =
          Hive.box<FoodRemovalEvent>(
            'food_history',
          );

  List<FoodRemovalEvent>
      loadHistory() {

    return _foodHistoryBox.values
        .toList();
  }

  Future<void> addEvent(
    FoodRemovalEvent event,
  ) async {

    await _foodHistoryBox.add(event);
  }
}