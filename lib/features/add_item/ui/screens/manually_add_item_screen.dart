import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../inventory/ui/providers/inventory_provider.dart';
import '../../../inventory/ui/widgets/inventory_item_form.dart';


// Screen for Manually Entering Information to Add Grocery Item to Inventory
class ManuallyAddItemScreen
    extends ConsumerWidget {

  const ManuallyAddItemScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manual Entry',
        ),
      ),

      body: InventoryItemForm(
        // Title of save button
        saveButtonName: 'Save Item',

        // Save the item and go to inventory screen
        onSave: (item) {

          ref
              .read(
                inventoryProvider.notifier,
              )
              .addItem(item);

          context.go('/inventory');
        },
      ),
    );
  }
}

