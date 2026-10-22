import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/styles/app_style.dart';
import 'ui/screens/home_screen.dart';
import 'package:go_router/go_router.dart';



final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
  ],
);


void main() {
  runApp(
    ProviderScope(  // Initialized for Riverpod state management/providers
      child: MaterialApp.router(
        routerConfig: _router,
        theme: AppStyle.base,
        title: 'Smart Grocery Housekeeping',
      ),
    ),
  );
}
