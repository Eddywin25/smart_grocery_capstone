import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';
import '../../domain/models/inventory_item.dart';
import '../widgets/inventory_item_form.dart';

// Edit Item Screen for editing grocery inventory item
class EditItemScreen
    extends ConsumerWidget {

  final InventoryItem item;

  const EditItemScreen({
    super.key,
    required this.item,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Inventory Item',
        ),
      ),

      body: InventoryItemForm(
        // Start with existing item details
        initialItem: item,

        // Title of save button
        saveButtonName:
            'Save Changes',

        // Update the item and return to previous screen
        onSave: (updatedItem) {

          ref
              .read(
                inventoryProvider.notifier,
              )
              .updateItem(updatedItem);

          context.pop();
        },
      ),
    );
  }
}