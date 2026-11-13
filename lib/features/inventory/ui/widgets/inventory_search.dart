import 'package:flutter/material.dart';

// Search Bar for Grocery Inventory
class InventorySearchBar extends StatelessWidget {
  const InventorySearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search your groceries',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
