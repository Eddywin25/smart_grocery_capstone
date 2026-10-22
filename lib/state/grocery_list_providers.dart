import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grocery_item.dart';

final groceryItemsProvider = StateNotifierProvider<GroceryListNotifier, List<GroceryItem>>(
  (param) => GroceryListNotifier(),
);

class GroceryListNotifier extends StateNotifier<List<GroceryItem>> {
  GroceryListNotifier() : super([]);

  // Updates state by appending a new item to the list
  void addItem(GroceryItem item) {
    state = [...state, item];
  }

  // Updates state by removing grocery item with specified ID
  void removeItem(String id) {
    state = state.where((item) => item.id != id).toList();
  }
}
