import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../models/produce_scan_result.dart';

class EdgeMlService {
  static const String _modelPath = 'assets/models/produce_model.tflite';
  static const String _labelsPath = 'assets/models/labels.txt';
  static const int _inputSize = 224;

  /// Exact lowercase produce labels mapped to canonical backend schema (mlLabel) names.
  /// Prevents substring false positives (like 'ear' matching 'bearskin' or 'hip' matching 'airship')
  /// while normalizing ImageNet labels (like 'Granny Smith' -> 'Apple') for backend compatibility.
  static const Map<String, String> _canonicalProduceMap = {
    // Baseline MobileNet v1 ImageNet produce classes
    'banana': 'Banana',
    'granny smith': 'Apple',
    'strawberry': 'Strawberry',
    'orange': 'Orange',
    'lemon': 'Lemon',
    'fig': 'Fig',
    'pineapple': 'Pineapple',
    'jackfruit': 'Jackfruit',
    'custard apple': 'Custard Apple',
    'pomegranate': 'Pomegranate',
    'broccoli': 'Broccoli',
    'cauliflower': 'Cauliflower',
    'head cabbage': 'Cabbage',
    'zucchini': 'Zucchini',
    'spaghetti squash': 'Squash',
    'acorn squash': 'Squash',
    'butternut squash': 'Squash',
    'cucumber': 'Cucumber',
    'artichoke': 'Artichoke',
    'bell pepper': 'Pepper',
    'cardoon': 'Cardoon',
    'mushroom': 'Mushroom',
    'corn': 'Corn',
    // Additional canonical 25-class backend schema labels
    'apple': 'Apple',
    'avocado': 'Avocado',
    'beans': 'Beans',
    'blueberries': 'Blueberries',
    'cabbage': 'Cabbage',
    'carrots': 'Carrots',
    'carrot': 'Carrots',
    'garlic': 'Garlic',
    'ginger': 'Ginger',
    'grapes': 'Grapes',
    'kiwi': 'Kiwi',
    'lime': 'Lime',
    'mango': 'Mango',
    'onion': 'Onion',
    'peach': 'Peach',
    'pear': 'Pear',
    'peas': 'Peas',
    'pepper': 'Pepper',
    'plum': 'Plum',
    'potato': 'Potato',
    'raspberries': 'Raspberries',
    'spinach': 'Spinach',
    'tomato': 'Tomato',
    'watermelon': 'Watermelon',
  };

  Interpreter? _interpreter;
  List<String> _labels = [];
  Future<void>? _initFuture;

  /// Loads the TFLite interpreter and label map into memory once.
  /// Caches [_initFuture] to prevent concurrent callers from allocating duplicate interpreters.
  Future<void> initialize() => _initFuture ??= _doInitialize();

  Future<void> _doInitialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      final rawLabels = await rootBundle.loadString(_labelsPath);
      _labels = rawLabels
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      debugPrint(
        '⚡ EdgeMlService initialized: ${_labels.length} labels loaded.',
      );
    } catch (e) {
      _initFuture = null; // Reset so future attempts can retry
      debugPrint('❌ Failed to initialize EdgeMlService: $e');
      rethrow;
    }
  }

  bool _isProduceLabel(String label) {
    final normalized = label.toLowerCase().trim();
    return _canonicalProduceMap.containsKey(normalized);
  }

  /// Runs local on-device inference using a background Isolate for image resizing.
  Future<ProduceScanResult> classifyProduceImage(
    Uint8List rawImageBytes, {
    double confidenceThreshold = 0.75,
  }) async {
    await initialize();

    final interpreter = _interpreter!;
    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);
    final isQuantized = inputTensor.type == TensorType.uint8;

    // 1. Decode & resize image to 224x224 RGB in a background Isolate
    final stopwatch = Stopwatch()..start();
    final inputMatrix = await preprocessImageForModel(
      rawImageBytes,
      _inputSize,
      isQuantized,
    );
    final preprocessMs = stopwatch.elapsedMilliseconds;

    // 2. Allocate output buffer matching [1, numClasses]
    final numClasses = outputTensor.shape.last;
    final List<double> probabilities;

    if (outputTensor.type == TensorType.uint8) {
      final outputBuffer = [List<int>.filled(numClasses, 0)];
      interpreter.run(inputMatrix, outputBuffer);
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

    // 3. Filter indices to valid produce classes; if using a custom produce-only
    //    model whose labels aren't in the static map, fall back to all output indices.
    final produceIndices = <int>[];
    for (int i = 0; i < probabilities.length; i++) {
      if (_isProduceLabel(_getLabelAt(i))) {
        produceIndices.add(i);
      }
    }

    if (produceIndices.isEmpty) {
      for (int i = 0; i < probabilities.length; i++) {
        produceIndices.add(i);
      }
    }

    produceIndices.sort((a, b) => probabilities[b].compareTo(probabilities[a]));

    final topIndex = produceIndices.first;
    final topConfidence = probabilities[topIndex];
    final topLabel = _formatLabel(_getLabelAt(topIndex));

    final runnerUps = produceIndices
        .skip(1)
        .where((idx) => probabilities[idx] > 0.0)
        .take(2)
        .map((idx) => _formatLabel(_getLabelAt(idx)))
        .toSet()
        .where((label) => label != topLabel)
        .toList();

    if (runnerUps.isEmpty) {
      runnerUps.addAll(
        topLabel.toLowerCase().contains('banana')
            ? ['Plantain', 'Lemon']
            : ['Banana', 'Apple'],
      );
    }

    return ProduceScanResult(
      itemName: topLabel,
      category: _inferCategory(topLabel),
      confidence: double.parse(topConfidence.toStringAsFixed(3)),
      source: ScanSource.edgeMl,
      ripeness: null,
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
    final clean = raw.trim();
    if (clean.isEmpty) return 'Unknown Item';
    final canonical = _canonicalProduceMap[clean.toLowerCase()];
    if (canonical != null) return canonical;
    return clean
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
      'onion',
      'garlic',
      'ginger',
      'spinach',
      'peas',
      'beans',
      'corn',
    ];
    for (final v in veggies) {
      if (lower.contains(v)) return 'Vegetable';
    }
    return 'Fruit';
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initFuture = null;
  }
}

/// Decodes and resizes [rawBytes] to a `[1, size, size, 3]` input tensor in a
/// background isolate.
///
/// This must stay a top-level function. `Isolate.run` copies everything its
/// closure captures, and a closure created inside an instance method shares
/// the method's context with sibling closures that reference `this`, which
/// drags the whole `EdgeMlService` (including its unsendable `_initFuture`)
/// into the isolate message and fails on device. Here the closure only sees
/// these three parameters.
@visibleForTesting
Future<List<List<List<List<num>>>>> preprocessImageForModel(
  Uint8List rawBytes,
  int targetSize,
  bool isQuantized,
) {
  return Isolate.run(
    () => _preprocessImageInIsolate(rawBytes, targetSize, isQuantized),
  );
}

/// Top-level function executed inside the background Dart Isolate.
List<List<List<List<num>>>> _preprocessImageInIsolate(
  Uint8List rawBytes,
  int targetSize,
  bool isQuantized,
) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) {
    throw Exception('Failed to decode image bytes inside background Isolate.');
  }

  final resized = img.copyResizeCropSquare(decoded, size: targetSize);

  return [
    List.generate(
      targetSize,
      (y) => List.generate(targetSize, (x) {
        final pixel = resized.getPixel(x, y);
        if (isQuantized) {
          return <int>[pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        } else {
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
