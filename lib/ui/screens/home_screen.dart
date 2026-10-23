import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/grocery_list_providers.dart'; // for state management
import '../components/app_card.dart';
import 'package:go_router/go_router.dart';  // routing between pages


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(groceryItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Grocery Home Page")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return AppCard(
            onTap: () {
              context.push('/item-details', extra: item);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                Text("${item.daysUntilSpoiled} days"),
              ],
            ),
          );
        },
      ),
    );
  }
}


