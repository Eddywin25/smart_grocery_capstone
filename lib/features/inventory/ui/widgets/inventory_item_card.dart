import 'package:smart_grocery/features/inventory/ui/providers/inventory_provider.dart';

import '../../domain/models/inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Listing for a Grocery Inventory Record
class InventoryItemCard extends ConsumerWidget {
  final InventoryItem item;

  const InventoryItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Row for Item ID, Name, Quantity, Location, and Days till expiry
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID · ${item.id}',
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                    ),
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      item.displayQuantLocation,
                    ),
                  ],
                ),
              ),
              Text(
                item.expiryTime,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.red.shade700, 
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Space
          const SizedBox(height: 16),

          // Row for purchase and expiry dates
          Row(children: [
              Expanded(
                child: _DateInfoDisplay(
                  title: 'Purchased',
                  value: item.displayPurchaseDate,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _DateInfoDisplay(
                  title: 'Estimated Spoilage',
                  value: item.displayExpiryDate,
                ),
              ),
            ],
          ),

          // Space
          const SizedBox(height: 16),

          // Row for updating quantity and completion status of food item
          Row(
            children: [
              // Quantity Update Field
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 180,
                ),
                child:
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () async {
                              if (item.quantity > 1) {
                                ref
                                  .read(
                                    inventoryProvider.notifier,
                                  )
                                  .updateQuantity(
                                    item.id,
                                    item.quantity - 1,
                                  );
                              }

                              if (item.quantity == 1) {

                                final confirmed =
                                    await _confirmRemoval(
                                  context,
                                  'Finish Item',
                                  'Quantity will reach zero. Mark item as finished?',
                                );

                                if (confirmed == true) {
                                  ref
                                    .read(
                                      inventoryProvider.notifier,
                                    )
                                    .removeItem(
                                      item.id,
                                      FoodItemOutcome.finished,
                                    );
                                }
                                return;
                              }
                            },
                          ),
                        ),

                        Expanded(
                          child: Center(
                            child: Text(
                              item.displayQuantPackage,
                            ),
                          ),
                        ),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              ref
                                .read(
                                  inventoryProvider.notifier,
                                )
                                .updateQuantity(
                                  item.id,
                                  item.quantity + 1,
                                );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ),

              // Separate Quantity Update field and Food Status Buttons
              const Spacer(),

              // Food Status Buttons
              Wrap(
                spacing: 10,
                children: [

                  // Button for finishing food
                  OutlinedButton(
                    onPressed: ()  async{
                      final confirmation = 
                        await _confirmRemoval(
                        context, 
                        "Finished Item", 
                        "Mark ${item.displayItemName} as finished?"
                      );

                      if (confirmation == true) {
                        ref
                          .read(inventoryProvider.notifier)
                          .removeItem(item.id, FoodItemOutcome.finished);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                    ),
                    child: 
                      const Text(
                        'Finished',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ),

                  // Button for marking food as spoiled
                  OutlinedButton(
                    onPressed: ()  async{
                      final confirmation = 
                        await _confirmRemoval(
                        context, 
                        "Spoiled Item", 
                        "Mark ${item.displayItemName} as spoiled?"
                      );

                      if (confirmation == true) {
                        ref
                          .read(inventoryProvider.notifier)
                          .removeItem(item.id, FoodItemOutcome.spoiled);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.shade100,
                    ),
                    child: 
                        Text(
                        'Spoiled',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ),

                  // Button for deleting a food item
                  OutlinedButton(
                    onPressed: ()  async{
                      final confirmation = 
                        await _confirmRemoval(
                        context, 
                        "Delete Item", 
                        "Delete ${item.displayItemName}?"
                      );

                      if (confirmation == true) {
                        ref
                          .read(inventoryProvider.notifier)
                          .removeItem(item.id, FoodItemOutcome.deleted);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.red.shade300,
                    ),
                    child: 
                        Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }
}
      

// Private class used to display date information for a grocery item   
class _DateInfoDisplay extends StatelessWidget {

  final String title;
  final String value;

  const _DateInfoDisplay({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.grey.shade300, // Color.fromRGBO(235, 235, 255, 0.8),

        borderRadius:
            BorderRadius.circular(8),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // Date type / title
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87, 
            ),
          ),

          // Space
          const SizedBox(height: 4),

          // Date value
          Text(
            value,
            style: const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


// Private helper used to confirm removal of a grocery item from inventory
Future<bool?> _confirmRemoval(
  BuildContext context,
  String title,
  String message,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, true);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}