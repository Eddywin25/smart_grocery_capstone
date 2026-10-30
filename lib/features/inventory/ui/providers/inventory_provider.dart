import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/inventory_item.dart';

// Create provider for grocery inventory state
final inventoryProvider =
  StateNotifierProvider<InventoryNotifier, List<InventoryItem>>(
    (ref) => InventoryNotifier(),
);

class InventoryNotifier
    extends StateNotifier<List<InventoryItem>> {

  InventoryNotifier() : super([
    // Hardcoded item used for testing
    InventoryItem(id: "1", name: "Tomato", quantity: "3", location: StorageLocation.fridge, purchaseDate: DateTime.now(), expiryDate: DateTime.now().add(Duration(days: 10)) )
  ]);

  // Add an item
  void addItem(
    InventoryItem item,
  ) {
    state = [...state, item];
  }
}