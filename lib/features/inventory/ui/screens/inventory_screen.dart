import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';
import '../widgets/inventory_item_card.dart';
import '../widgets/inventory_search.dart';

// Grocery Inventory Screen
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      inventoryProvider,
    ); // watch for provider state of inventory items

    return Scaffold(
      // Establish page layout
      appBar: AppBar(title: const Text('Grocery Inventory')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: InventorySearchBar(),
          ),

          const Padding(
            padding: EdgeInsets.all(5),
            child: Text('All Groceries'),
          ),

          // Display all items in inventory
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return InventoryItemCard(item: items[index]);
              },
            ),
          ),
        ],
      ),

      // Add Item Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {context.push('/add-item');},
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}
