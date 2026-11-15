import 'dart:typed_data';

import 'package:smart_grocery/models/produce_scan_result.dart';
import 'package:smart_grocery/services/recognition/edge_ml_service.dart';
import 'package:smart_grocery/services/recognition/gemini_vision_service.dart';
import 'package:smart_grocery/services/recognition/recognition_providers.dart';

/// Shared test doubles for the recognition layer. They never touch native
/// TFLite, Firebase or camera channels, so they are safe in headless CI.

class FakeEdgeMlService extends EdgeMlService {
  ProduceScanResult? resultToReturn;
  Object? errorToThrow;

  @override
  Future<void> initialize() async {}

  @override
  Future<ProduceScanResult> classifyProduceImage(
    Uint8List rawImageBytes, {
    double confidenceThreshold = 0.75,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return resultToReturn!;
  }

  @override
  void dispose() {}
}

class FakeGeminiVisionService extends GeminiVisionService {
  ProduceScanResult? resultToReturn;
  Object? errorToThrow;
  int callCount = 0;

  @override
  Future<ProduceScanResult> analyzeProduceImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
    double reviewThreshold = 0.75,
  }) async {
    callCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return resultToReturn!;
  }
}

class FakeImageCaptureService implements ImageCaptureService {
  /// Bytes returned by [capture]; `null` simulates the user cancelling.
  Uint8List? bytesToReturn = Uint8List.fromList([1, 2, 3, 4]);
  final List<bool> calls = [];

  @override
  Future<Uint8List?> capture({required bool fromCamera}) async {
    calls.add(fromCamera);
    return bytesToReturn;
  }
}
