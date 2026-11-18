import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';
import '../widgets/inventory_item_card.dart';
import '../widgets/inventory_search.dart';

// Grocery Inventory Screen
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

    @override
  ConsumerState<InventoryScreen> createState() =>
      _InventoryScreenState();

}

// Handle State for Inventory Screen
class _InventoryScreenState
    extends ConsumerState<InventoryScreen> {

  String _searchBarQuery = ''; // Initializes search bar query

  @override
  Widget build(BuildContext context) {

    final items = ref.watch(
      inventoryProvider,
    ); // watch for provider state of inventory items

    // Items matching search query
    final searchResults =
      items.where((item) {
        return item.name
            .toLowerCase()
            .contains(
              _searchBarQuery.toLowerCase(),
            );

      }).toList();

    // Establish page layout
    return Scaffold(
      appBar: AppBar(title: const Text('Grocery Inventory')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),

            // Update search query
            child: InventorySearchBar(
              onChanged: (value) {
                setState(() {
                  _searchBarQuery = value;
                });
              },
            ),
          ),

          // Sub-header
          const Padding(
            padding: EdgeInsets.all(5),
            child: Text('All Groceries'),
          ),

          // Display all items in inventory
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return InventoryItemCard(item: searchResults[index]);
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
