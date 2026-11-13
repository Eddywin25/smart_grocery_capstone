import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../models/produce_scan_result.dart';
import 'barcode_scanner_service.dart';
import 'edge_ml_service.dart';
import 'gemini_vision_service.dart';

class RecognitionCoordinator {
  final EdgeMlService _edgeMlService;
  final GeminiVisionService _geminiService;
  final BarcodeScannerService barcodeScanner;

  /// Default minimum confidence required to trust the local .tflite model
  /// without escalating to Gemini Cloud.
  final double confidenceThreshold;

  RecognitionCoordinator({
    EdgeMlService? edgeMlService,
    GeminiVisionService? geminiService,
    BarcodeScannerService? barcodeScanner,
    this.confidenceThreshold = 0.75,
  }) : _edgeMlService = edgeMlService ?? EdgeMlService(),
       _geminiService = geminiService ?? GeminiVisionService(),
       barcodeScanner = barcodeScanner ?? BarcodeScannerService();

  /// Pre-warms the local TFLite interpreter when the app or scanner screen
  /// opens.
  Future<void> initialize() async {
    await _edgeMlService.initialize();
  }

  /// Main entry point for Person C's UI when scanning unpackaged produce.
  ///
  /// 1. Runs fast on-device Edge ML in a background Isolate first.
  /// 2. Escalates to Gemini Cloud if local confidence < [confidenceThreshold],
  ///    or if [requireRipeness] is true.
  /// 3. Falls back to the local Edge ML guess (with needsReview: true) if
  ///    the device is offline or Gemini is unreachable.
  Future<ProduceScanResult> scanProduce(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
    bool requireRipeness = false,
  }) async {
    ProduceScanResult? localResult;

    // Step 1: Attempt fast on-device inference (Edge ML)
    try {
      localResult = await _edgeMlService.classifyProduceImage(
        imageBytes,
        confidenceThreshold: confidenceThreshold,
      );
      debugPrint(
        '🧠 [Coordinator] Edge ML result: ${localResult.itemName} '
        '(confidence: ${localResult.confidence})',
      );
    } catch (e) {
      debugPrint(
        '⚠️ [Coordinator] Edge ML failed ($e). Escalating directly to Gemini...',
      );
    }

    // Step 2: Check if Edge ML is confident enough and ripeness isn't required
    final isConfident =
        localResult != null &&
        localResult.confidence >= confidenceThreshold &&
        !localResult.needsReview;

    if (isConfident && !requireRipeness) {
      debugPrint('✅ [Coordinator] Returning fast Edge ML result.');
      return localResult;
    }

    // Step 3: Escalate to Gemini Cloud Vision
    final reason = localResult == null
        ? 'Edge ML unavailable'
        : (requireRipeness
              ? 'Ripeness analysis requested'
              : 'Low local confidence (${localResult.confidence} < $confidenceThreshold)');
    debugPrint('☁️ [Coordinator] Escalating to Gemini Cloud ($reason)...');

    try {
      final cloudResult = await _geminiService.analyzeProduceImage(
        imageBytes,
        mimeType: mimeType,
      );
      debugPrint('✅ [Coordinator] Returning Gemini Cloud result.');
      return cloudResult;
    } catch (cloudError) {
      debugPrint('❌ [Coordinator] Gemini Cloud failed: $cloudError');

      // Step 4: Graceful offline fallback if we have a local Edge ML guess
      if (localResult != null) {
        debugPrint(
          '🛡️ [Coordinator] Falling back to Edge ML result with needsReview = true.',
        );
        return ProduceScanResult(
          itemName: localResult.itemName,
          category: localResult.category,
          confidence: localResult.confidence,
          source: ScanSource.edgeMl,
          ripeness: localResult.ripeness,
          estDaysUntilSpoil: localResult.estDaysUntilSpoil,
          alternatives: localResult.alternatives,
          needsReview:
              true, // Force user review since cloud verification failed
        );
      }
      rethrow;
    }
  }

  void dispose() {
    _edgeMlService.dispose();
    barcodeScanner.dispose();
  }
}
