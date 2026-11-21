import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:smart_grocery/shared/routing/router.dart';
import 'package:smart_grocery/features/inventory/domain/models/inventory_item.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Set up Hive
  await Hive.initFlutter();

  Hive.registerAdapter(
    InventoryItemAdapter(),
  );

  Hive.registerAdapter(
    StorageLocationAdapter(),
  );

  Hive.registerAdapter(
    PackageAdapter(),
  );

  Hive.registerAdapter(
    FoodItemOutcomeAdapter(),
  );
 
  await Hive.openBox<InventoryItem>(
    'inventory',
  );

  // Run App
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Widget at root of application
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router, // Uses go_router for navigation
    );
  }
}
