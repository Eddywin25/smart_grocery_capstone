import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';
import '../widgets/inventory_item_card.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref,
  ) {
    final items =
        ref.watch(inventoryProvider); // watch for provider state of inventory items

    return Scaffold(  // establish page layout
      appBar: AppBar(
        title: const Text(
          'Grocery Inventory',
        ),
      ),
      body: ListView.builder( // list of grocery item widgets
        itemCount: items.length,
        itemBuilder: (
          context,
          index,
        ) {
          return InventoryItemCard( // return grocery item info
            item: items[index],
          );
        },
      ),
    );
  }
}