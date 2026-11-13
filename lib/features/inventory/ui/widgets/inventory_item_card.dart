import '../../domain/models/inventory_item.dart';

import 'package:flutter/material.dart';

// Listing for a Grocery Inventory Record
class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;

  const InventoryItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              '${item.location.name} : ${item.quantity} ${item.packageType.packageReference(item.quantity)}',
            ),
          ],
        ),
        trailing: Text(item.expiryTime),
      ),
    );
  }
}
