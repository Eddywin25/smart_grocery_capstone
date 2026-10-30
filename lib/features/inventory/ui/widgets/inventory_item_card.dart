import '../../domain/models/inventory_item.dart';
import 'package:flutter/material.dart';



class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;

  const InventoryItemCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.name),
        subtitle: Text(
          '${item.quantity} * In ${item.location.name}',
        ),
        trailing: Text(
          item.expiryTime,
        ),
      ),
    );
  }
}