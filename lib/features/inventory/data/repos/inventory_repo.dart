import 'package:hive/hive.dart';
import '../../domain/models/inventory_item.dart';

// Hive-interfacing repository to CRUD operations
class InventoryRepository {

  final Box<InventoryItem> _inventoryBox =
    Hive.box<InventoryItem>(
      'inventory',
    );

  // Load inventory
  List<InventoryItem> loadInventory() {
    return _inventoryBox.values.toList();
  }

  // Clear inventory
  Future<void> clearInventory() async {
    await _inventoryBox.clear();
  }

  // Retrieve inventory item
  InventoryItem? getItem(String id) {
    return _inventoryBox.get(id);
  }

  // Add inventory
  Future<void> addItem(InventoryItem item) async {
    await _inventoryBox.put(
      item.id,
      item,
    );

    await _inventoryBox.flush();

  }

  // Update inventory
  Future<void> updateItem(InventoryItem item) async {
    await _inventoryBox.put(
      item.id,
      item,
    );
  }

  // Delete inventory
  Future<void> deleteItem(String id) async {
    await _inventoryBox.delete(id);
  }

}