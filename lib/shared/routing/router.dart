import 'package:go_router/go_router.dart';
import '../../features/inventory/ui/screens/inventory_screen.dart';


final router = GoRouter(

  initialLocation: '/inventory',  // Entry point route - Update to Home Dashboard Later
  routes: [
    // Route for Inventory Screen
    GoRoute(
      path: '/inventory',
      builder: (
        context,
        state
      ) {
        return const InventoryScreen();
      },
    ),
  ],
);