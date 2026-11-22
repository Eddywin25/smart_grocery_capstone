import 'package:flutter/material.dart';

// Search Bar for Grocery Inventory
class InventorySearchBar extends StatelessWidget {

  final ValueChanged<String> onChanged;

  const InventorySearchBar({
    super.key,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'Search groceries',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}