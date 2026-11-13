import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../models/produce_scan_result.dart';

class EdgeMlService {
  static const String _modelPath = 'assets/models/produce_model.tflite';
  static const String _labelsPath = 'assets/models/labels.txt';
  static const int _inputSize = 224;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  /// Loads the TFLite interpreter and label map into memory once.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      final rawLabels = await rootBundle.loadString(_labelsPath);
      _labels = rawLabels
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      _isInitialized = true;
      debugPrint(
        '⚡ EdgeMlService initialized: ${_labels.length} labels loaded.',
      );
    } catch (e) {
      debugPrint('❌ Failed to initialize EdgeMlService: $e');
      rethrow;
    }
  }

  /// Runs local on-device inference using a background Isolate for image resizing.
  Future<ProduceScanResult> classifyProduceImage(
    Uint8List rawImageBytes, {
    double confidenceThreshold = 0.75,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final interpreter = _interpreter!;
    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);
    final isQuantized = inputTensor.type == TensorType.uint8;

    // 1. Decode & resize image to 224x224 RGB in a background Isolate
    final stopwatch = Stopwatch()..start();
    final inputMatrix = await Isolate.run(
      () => _preprocessImageInIsolate(rawImageBytes, _inputSize, isQuantized),
    );
    final preprocessMs = stopwatch.elapsedMilliseconds;

    // 2. Allocate output buffer matching [1, numClasses]
    final numClasses = outputTensor.shape.last;
    final List<double> probabilities;

    if (outputTensor.type == TensorType.uint8) {
      final outputBuffer = [List<int>.filled(numClasses, 0)];
      interpreter.run(inputMatrix, outputBuffer);
      // Quantized uint8 outputs range from 0..255
      probabilities = outputBuffer[0].map((v) => v / 255.0).toList();
    } else {
      final outputBuffer = [List<double>.filled(numClasses, 0.0)];
      interpreter.run(inputMatrix, outputBuffer);
      probabilities = outputBuffer[0];
    }

    stopwatch.stop();
    debugPrint(
      '⚡ Edge ML finished in ${stopwatch.elapsedMilliseconds}ms '
      '(Isolate preprocess: ${preprocessMs}ms)',
    );

    // 3. Sort indices by highest probability
    final produceIndices = <int>[];
    for (int i = 0; i < probabilities.length; i++) {
      if (_isProduceLabel(_getLabelAt(i))) {
        produceIndices.add(i);
      }
    }

    produceIndices.sort((a, b) => probabilities[b].compareTo(probabilities[a]));

    final topIndex = produceIndices.first;
    final topConfidence = probabilities[topIndex];
    final topLabel = _formatLabel(_getLabelAt(topIndex));

    // Only include runner-ups that actually registered > 0 probability;
    // otherwise provide sensible fallback produce options.
    final runnerUps = produceIndices
        .skip(1)
        .where((idx) => probabilities[idx] > 0.0)
        .take(2)
        .map((idx) => _formatLabel(_getLabelAt(idx)))
        .toList();

    if (runnerUps.isEmpty) {
      runnerUps.addAll(
        topLabel.toLowerCase().contains('banana')
            ? ['Plantain', 'Lemon']
            : ['Banana', 'Granny Smith'],
      );
    }

    return ProduceScanResult(
      itemName: topLabel,
      category: _inferCategory(topLabel),
      confidence: double.parse(topConfidence.toStringAsFixed(3)),
      source: ScanSource.edgeMl,
      ripeness: null, // Local classifier only identifies item; Gemini estimates ripeness
      estDaysUntilSpoil: null,
      alternatives: runnerUps,
      needsReview: topConfidence < confidenceThreshold,
    );
  }

  String _getLabelAt(int index) {
    if (index >= 0 && index < _labels.length) {
      return _labels[index];
    }
    return 'Class #$index';
  }

  String _formatLabel(String raw) {
    if (raw.isEmpty) return 'Unknown Item';
    return raw
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _inferCategory(String itemName) {
    final lower = itemName.toLowerCase();
    const veggies = [
      'broccoli',
      'cauliflower',
      'cucumber',
      'zucchini',
      'squash',
      'pepper',
      'cabbage',
      'artichoke',
      'cardoon',
      'mushroom',
      'potato',
      'carrot',
    ];
    for (final v in veggies) {
      if (lower.contains(v)) return 'Vegetable';
    }
    return 'Fruit';
  }

  static const List<String> _produceKeywords = [
    'banana',
    'granny smith',
    'strawberry',
    'orange',
    'lemon',
    'fig',
    'pineapple',
    'jackfruit',
    'custard apple',
    'pomegranate',
    'broccoli',
    'cauliflower',
    'cabbage',
    'zucchini',
    'squash',
    'cucumber',
    'artichoke',
    'bell pepper',
    'cardoon',
    'mushroom',
    'corn',
    'ear',
    'acorn',
    'hip',
  ];

  bool _isProduceLabel(String label) {
    final lower = label.toLowerCase();
    return _produceKeywords.any((k) => lower.contains(k));
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

/// Top-level / static function executed inside the background Dart Isolate.
/// Decodes JPEG/PNG bytes, center-crops and resizes to 224x224, and builds a
/// 4D tensor [1, 224, 224, 3].
List<List<List<List<num>>>> _preprocessImageInIsolate(
  Uint8List rawBytes,
  int targetSize,
  bool isQuantized,
) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) {
    throw Exception('Failed to decode image bytes inside background Isolate.');
  }

  // Resize and center-crop to 224x224 square
  final resized = img.copyResizeCropSquare(decoded, size: targetSize);

  return [
    List.generate(
      targetSize,
      (y) => List.generate(targetSize, (x) {
        final pixel = resized.getPixel(x, y);
        if (isQuantized) {
          return <int>[pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        } else {
          // Standard float32 normalization (-1.0 to 1.0)
          return <double>[
            (pixel.r - 127.5) / 127.5,
            (pixel.g - 127.5) / 127.5,
            (pixel.b - 127.5) / 127.5,
          ];
        }
      }),
    ),
  ];
}
