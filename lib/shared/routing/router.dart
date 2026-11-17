
import 'package:go_router/go_router.dart';
import '../../features/inventory/ui/screens/inventory_screen.dart';
import '../../features/add_item/ui/screens/add_item_screen.dart';
import '../../features/add_item/ui/screens/manually_add_item_screen.dart';
import '../../features/add_item/ui/screens/barcode_scan_screen.dart';
import '../../features/add_item/ui/screens/food_recognition_screen.dart';

// Router used for app navigation
final router = GoRouter(
  initialLocation:
      '/inventory', // Entry point route - Update to Home Dashboard Later
  routes: [
    // Route for Inventory Screen
    GoRoute(
      path: '/inventory',
      builder: (context, state) {
        return const InventoryScreen();
      },
    ),
    GoRoute(
      path: '/add-item',
      builder: (context, state) {
        return const AddItemScreen();
      },
    ),
    GoRoute(
      path: '/manual-add-item',
      builder: (context, state) {
        return const ManuallyAddItemScreen();
      },
    ),
    GoRoute(
      path: '/barcode-scan-add-item',
      builder: (context, state) {
        return const BarcodeScanScreen();
      },
    ),
    GoRoute(
      path: '/ai-add-item',
      builder: (context, state) {
        return const FoodRecognitionScreen();
      },
    ),
  ],
);
