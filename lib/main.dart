import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'firebase_options.dart';
import 'services/recognition/barcode_scanner_service.dart';
import 'services/recognition/edge_ml_service.dart';
import 'services/recognition/gemini_vision_service.dart';
import 'services/recognition/recognition_coordinator.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Grocery POC',
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
  final _visionService = GeminiVisionService();
  final _edgeMlService = EdgeMlService();
  late final _coordinator = RecognitionCoordinator(
    edgeMlService: _edgeMlService,
    geminiService: _visionService,
  );

  String _aiResponse = 'Select a recognition pipeline below to test.';
  bool _isLoading = false;
  bool _requireRipeness = false;

  Future<void> _testGeminiPipeline() async {
    setState(() {
      _isLoading = true;
      _aiResponse = 'Analyzing test_banana.jpg with Gemini Cloud...';
    });

    try {
      final byteData = await rootBundle.load('assets/test_banana.jpg');
      final imageBytes = byteData.buffer.asUint8List();

      final result = await _visionService.analyzeProduceImage(imageBytes);
      if (!mounted) return;

      setState(() {
        _aiResponse = result.toPrettyJson();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiResponse = 'Error calling GeminiVisionService:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testEdgeMlPipeline() async {
    setState(() {
      _isLoading = true;
      _aiResponse = 'Running local .tflite model in background Isolate...';
    });

    try {
      final byteData = await rootBundle.load('assets/test_banana.jpg');
      final imageBytes = byteData.buffer.asUint8List();

      final result = await _edgeMlService.classifyProduceImage(imageBytes);
      if (!mounted) return;

      setState(() {
        _aiResponse = result.toPrettyJson();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiResponse = 'Error running EdgeMlService:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
      if (!mounted) return;

      setState(() {
        _aiResponse = result.toPrettyJson();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiResponse = 'Error in RecognitionCoordinator:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                Navigator.of(context).pop(code);
              }
            },
          ),
        ),
      ),
    );

    scannerService.dispose();
    if (!mounted) return;

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
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Grocery: Vision & Edge ML POC'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.eco, size: 56, color: Colors.green),
              const SizedBox(height: 12),
              const Text(
                'Milestone 1 & 2: Hybrid Recognition Pipeline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
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
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.hub),
                label: const Text('Test Hybrid Coordinator (Auto-Route)'),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _isLoading ? null : _testEdgeMlPipeline,
                icon: const Icon(Icons.memory),
                label: const Text('Test Local Edge ML (.tflite)'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _testGeminiPipeline,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Test Gemini Cloud Directly'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _openBarcodeScanner,
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
