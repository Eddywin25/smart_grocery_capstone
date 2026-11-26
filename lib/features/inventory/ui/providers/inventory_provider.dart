import '../../domain/models/inventory_item.dart';
import 'package:smart_grocery/features/inventory/data/repos/inventory_repo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_grocery/features/inventory/domain/models/food_removal_event.dart';
import 'package:smart_grocery/features/inventory/data/repos/food_history_repo.dart';


final inventoryProvider =
  NotifierProvider<
    InventoryNotifier,
    List<InventoryItem>
  >(
    InventoryNotifier.new,
  );


// State Management
class InventoryNotifier
    extends Notifier<List<InventoryItem>> {

  final InventoryRepository _repository = InventoryRepository();

  final FoodHistoryRepository _foodHistoryRepository = FoodHistoryRepository();

  @override
  List<InventoryItem> build() {
    return _repository.loadInventory();
  }

  // Add an item
  Future<void> addItem(InventoryItem item) async {
    await _repository.addItem(item);
    state = _repository.loadInventory();
  }

  // Remove an item from inventory
  Future<void> removeItem(String id, FoodItemOutcome outcome) async {
    // find item to delete
    final item = state.firstWhere((item) => item.id == id);

    // Create removal event record
    final event = FoodRemovalEvent(itemName: item.name, outcome: outcome, eventDate: DateTime.now());

    // Save the removal event in history
    await _foodHistoryRepository.addEvent(event);

    // Remove item from inventory
    await _repository.deleteItem(id);

    state = _repository.loadInventory();
  }

  // Update the quantity of an item
  Future<void> updateQuantity(String id, int quantity) async {
    final item =
        state.firstWhere(
          (item) => item.id == id,
        );

    final updatedItem =
        item.itemCopyUpdate(
          quantity: quantity,
        );

    await _repository.updateItem(updatedItem);

    state = _repository.loadInventory();
  }

  // Update attributes of a grocery item (used for Edit Screen)
  Future<void> updateItem(InventoryItem updatedItem) async {
    await _repository.updateItem(
      updatedItem,
    );
    state = _repository.loadInventory();
  }

}
