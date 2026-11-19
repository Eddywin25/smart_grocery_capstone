import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';
import '../widgets/inventory_item_card.dart';
import '../widgets/inventory_search.dart';
import 'package:smart_grocery/features/inventory/domain/models/inventory_item.dart';
import 'package:smart_grocery/shared/utilities/string_display_utility.dart';

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

  StorageLocation? _chosenLocation; // Initializing storage location choice

  @override
  Widget build(BuildContext context) {

    // watch for provider state of inventory items
    final items = ref.watch(
      inventoryProvider,
    ); 

    // Items matching search query and location filter
    final searchResults =
      items.where((item) {
        final searchMatch = 
          item.name
            .toLowerCase()
            .contains(
              _searchBarQuery.toLowerCase(),
            );
        final locationMatch = 
          _chosenLocation == null ||
          item.location ==
            _chosenLocation;
        
        return searchMatch &&
          locationMatch;
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

          // Grocery Location Filtering
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,

            child: Row(
              children: [

                // Filter for displaying all groceries
                FilterChip(
                  label: const Text('All'),
                  selected: _chosenLocation == null,
                  onSelected: (_) {
                    setState(() {
                      _chosenLocation = null;
                    });
                  },
                ),

                
                const SizedBox(width: 8),

                // Filter for diplaying only groceries from fridge
                FilterChip(
                  label: const Text('Fridge'),
                  selected:
                      _chosenLocation ==
                      StorageLocation.fridge,
                  onSelected: (_) {
                    setState(() {
                      // Toggle fridge grocery filter when tapped
                      if (_chosenLocation ==
                          StorageLocation.fridge) {
                        _chosenLocation = null;
                      } else {
                        _chosenLocation =
                            StorageLocation.fridge;
                      }

                    });
                  }
                ),

                // Filter for displaying only groceries from freezer
                FilterChip(
                  label: const Text('Freezer'),
                  selected:
                      _chosenLocation ==
                      StorageLocation.freezer,

                  onSelected: (_) {
                    setState(() {
                      // Toggle freezer grocery filter when tapped
                      if (_chosenLocation ==
                          StorageLocation.freezer) {
                        _chosenLocation = null;
                      } else {
                        _chosenLocation =
                            StorageLocation.freezer;
                      }

                    });
                  }
                ),

                // Filter for displaying only groceries from the pantry
                FilterChip(
                  label: const Text('Pantry'),
                  selected:
                      _chosenLocation ==
                      StorageLocation.pantry,

                  onSelected: (_) {
                    setState(() {
                      // Toggle pantry grocery filter when tapped
                      if (_chosenLocation ==
                          StorageLocation.pantry) {
                        _chosenLocation = null;
                      } else {
                        _chosenLocation =
                            StorageLocation.pantry;
                      }

                    });
                  }
                ),

                // 
                FilterChip(
                  label: const Text('Counter'),
                  selected:
                      _chosenLocation ==
                      StorageLocation.counter,

                  onSelected: (_) {
                    setState(() {
                      // Toggle counter grocery filter when tapped
                      if (_chosenLocation ==
                          StorageLocation.counter) {
                        _chosenLocation = null;
                      } else {
                        _chosenLocation =
                            StorageLocation.counter;
                      }
                    });
                  }
                ),

              ],
            ),
          ),

          // Sub-header
          Padding(
            padding: EdgeInsets.all(5),
            child: 
              // Grocery title selection based on active filter
              Text(
                _chosenLocation == null
                    ? 'All Groceries'
                    : '${_chosenLocation!.name.capitalized} Items',
              )
          ),

          // Display items from inventory
          Expanded(
            child: searchResults.isEmpty
              ? const Center(
                child: Text(
                  'No groceries found from your search criteria.',
                  style: TextStyle(
                    color: Colors.red,
                  )
                ),
              )
              : ListView.builder(
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
