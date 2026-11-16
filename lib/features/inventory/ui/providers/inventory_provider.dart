import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/inventory_item.dart';

// Create provider for grocery inventory state
final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, List<InventoryItem>>(
      (ref) => InventoryNotifier(),
    );

class InventoryNotifier extends StateNotifier<List<InventoryItem>> {
  InventoryNotifier()
    : super([
        // Hardcoded item used for testing
        InventoryItem(
          id: "1",
          name: "Tomato",
          quantity: 3,
          location: StorageLocation.fridge,
          purchaseDate: DateTime.now(),
          expiryDate: DateTime.now().add(Duration(days: 10)),
          packageType: Package.bag,
        ),
      ]);

  // Add an item
  void addItem(InventoryItem item) {
    state = [...state, item];
  }

  // Remove an item
  void removeItem(String id, FoodItemOutcome outcome,) {
  state = state
      .where((item) => item.id != id)
      .toList();
  }

  // Update the quantity of an item
  void updateQuantity(String id, int quantity) {
    state = state.map((item) {

      if (item.id == id) {
        return item.itemUpdate(quantity: quantity);
      }

      return item;

    }).toList();
  }

}
