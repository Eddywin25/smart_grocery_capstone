import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'services/recognition/gemini_vision_service.dart';
import 'services/recognition/edge_ml_service.dart';
import 'services/recognition/barcode_scanner_service.dart';
import 'services/recognition/recognition_coordinator.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase Core
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase Core initialized!');

  // 2. Activate Firebase App Check (using v0.5.x parameter names)
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestProvider(),
    providerWeb: kDebugMode
        ? WebDebugProvider()
        : ReCaptchaV3Provider('debug-placeholder-site-key'),
  );
  debugPrint('🛡️ Firebase App Check activated!');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Grocery Capstone',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const GeminiPocScreen(),
    );
  }
}

class GeminiPocScreen extends StatefulWidget {
  const GeminiPocScreen({super.key});

  @override
  State<GeminiPocScreen> createState() => _GeminiPocScreenState();
}

class _GeminiPocScreenState extends State<GeminiPocScreen> {
  String _aiResponse =
      'Press the button below to test Firebase AI Logic (Gemini).';
  bool _isLoading = false;

  final _geminiService = GeminiVisionService();

  Future<void> _testGeminiPipeline() async {
    setState(() {
      _isLoading = true;
      _aiResponse = 'Loading assets/test_banana.jpg & sending to Gemini...';
    });

    try {
      // 1. Load the actual image bytes from Flutter assets
      final byteData = await rootBundle.load('assets/test_banana.jpg');
      final imageBytes = byteData.buffer.asUint8List();

      // 2. Call our production-ready GeminiVisionService
      final result = await _geminiService.analyzeProduceImage(imageBytes);

      setState(() {
        _aiResponse = result.toPrettyJson();
      });
    } catch (e) {
      setState(() {
        _aiResponse = 'Error calling GeminiVisionService:\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  final _edgeMlService = EdgeMlService();

  Future<void> _testEdgeMlPipeline() async {
    setState(() {
      _isLoading = true;
      _aiResponse = 'Running local .tflite model in background Isolate...';
    });

    try {
      final byteData = await rootBundle.load('assets/test_banana.jpg');
      final imageBytes = byteData.buffer.asUint8List();

      final result = await _edgeMlService.classifyProduceImage(imageBytes);

      setState(() {
        _aiResponse = result.toPrettyJson();
      });
    } catch (e) {
      setState(() {
        _aiResponse = 'Error running EdgeMlService:\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  final _coordinator = RecognitionCoordinator();
  bool _requireRipeness = false;

  Future<void> _testHybridCoordinator() async {
    setState(() {
      _isLoading = true;
      _aiResponse = 'Running Hybrid RecognitionCoordinator...';
    });

    try {
      final byteData = await rootBundle.load('assets/test_banana.jpg');
      final imageBytes = byteData.buffer.asUint8List();

      final result = await _coordinator.scanProduce(
        imageBytes,
        requireRipeness: _requireRipeness,
      );

      setState(() {
        _aiResponse = result.toPrettyJson();
      });
    } catch (e) {
      setState(() {
        _aiResponse = 'Error in RecognitionCoordinator:\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openBarcodeScanner() async {
    final scannerService = BarcodeScannerService();

    final String? scannedBarcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Point at a Barcode')),
          body: MobileScanner(
            controller: scannerService.controller,
            onDetect: (capture) {
              final code = scannerService.processBarcodeCapture(capture);
              if (code != null) {
                // We got a clean, debounced barcode! Close camera & return it.
                Navigator.of(context).pop(code);
              }
            },
          ),
        ),
      ),
    );

    // Clean up the camera controller when the screen closes
    scannerService.dispose();

    if (scannedBarcode != null) {
      setState(() {
        _aiResponse =
            '📦 Barcode Scanned Successfully!\n\n'
            'Raw Code: $scannedBarcode\n'
            'Next Step: Send "$scannedBarcode" to Person D\'s lookup service.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Smart Grocery: Gemini POC'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.eco, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Milestone 1: Cloud AI Pipeline Test',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  _aiResponse,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isLoading ? null : _testGeminiPipeline,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoading ? 'Asking Gemini...' : 'Run "Hello Gemini" Test',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _isLoading ? null : _testEdgeMlPipeline,
                icon: const Icon(Icons.memory),
                label: const Text('Test Local Edge ML (.tflite)'),
              ),
              SwitchListTile(
                title: const Text(
                  'Require Ripeness / Spoilage Days',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Escalates from Edge ML to Gemini Cloud',
                  style: TextStyle(fontSize: 12),
                ),
                value: _requireRipeness,
                onChanged: _isLoading
                    ? null
                    : (val) => setState(() => _requireRipeness = val),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _isLoading ? null : _testHybridCoordinator,
                icon: const Icon(Icons.hub),
                label: const Text('Test Hybrid Coordinator (Auto-Route)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openBarcodeScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Test Live Barcode Scanner'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
