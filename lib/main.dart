import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/routing/router.dart';  // Custom navigation/routes

void main() {
  runApp(const ProviderScope(
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Widget at root of application
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: router, // Uses go_router for navigation
    );
  }
}
