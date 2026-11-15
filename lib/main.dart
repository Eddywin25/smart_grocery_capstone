import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'services/auth/auth_service.dart';
import 'shared/routing/router.dart'; // Custom navigation/routes

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase Core initialized!');

  // todo (milestone-3): Replace web ReCaptchaV3Provider key via
  // String.fromEnvironment before production web release.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerWeb: kDebugMode
        ? WebDebugProvider()
        : ReCaptchaV3Provider(
            const String.fromEnvironment(
              'RECAPTCHA_V3_SITE_KEY',
              defaultValue: 'debug-placeholder-site-key',
            ),
          ),
  );
  debugPrint('🛡️ Firebase App Check activated!');

  // Cloud Functions need a signed-in user. Sign in anonymously in the
  // background so the app opens instantly even offline; the barcode lookup
  // calls ensureSignedIn() again before every request.
  unawaited(
    AuthService().ensureSignedIn().then(
      (_) => debugPrint('🔑 Signed in anonymously.'),
      onError: (Object e) => debugPrint('🔑 Anonymous sign-in deferred: $e'),
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Widget at root of application
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Smart Grocery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: router, // Uses go_router for navigation
    );
  }
}
