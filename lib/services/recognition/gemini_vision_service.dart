import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../models/produce_scan_result.dart';

class GeminiVisionService {
  static const String _modelName = 'gemini-3.8-flash';
  static const int _maxRetriesOnServerError = 2;

  static final Schema _produceResponseSchema = Schema.object(
    properties: {
      'itemName': Schema.string(
        description:
            'Specific name of the produce item (e.g., Cavendish Banana).',
      ),
      'category': Schema.string(
        description: 'Broad grocery category (e.g., Fruit, Vegetable, Herb).',
      ),
      'confidence': Schema.number(
        description: 'Confidence score between 0.0 and 1.0.',
      ),
      'ripeness': Schema.string(
        description:
            'Visual ripeness state: Unripe, Ripe, Very Ripe, or Overripe.',
        nullable: true,
      ),
      'estDaysUntilSpoil': Schema.integer(
        description:
            'Estimated days remaining at room/fridge temp before spoiling.',
        nullable: true,
      ),
      'alternatives': Schema.array(
        items: Schema.string(),
        description: 'Top 2 alternative produce guesses if ambiguous.',
      ),
    },
    optionalProperties: ['ripeness', 'estDaysUntilSpoil'],
  );

  static const String _systemPrompt = '''
Analyze this grocery produce image and return a JSON object matching the required schema.
Identify the specific fruit, vegetable, or herb, estimate its visual ripeness and days until spoilage,
and provide 2 reasonable alternative produce names in case of ambiguity.
''';

  late final GenerativeModel _model = _buildModel();

  GenerativeModel _buildModel() {
    return FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _produceResponseSchema,
        temperature: 0.1,
      ),
    );
  }

  Future<ProduceScanResult> analyzeProduceImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
    double reviewThreshold = 0.75,
  }) async {
    // 1. Compress/resize large images in a background Isolate so upload & cloud
    //    token processing finish in ~2-4 seconds instead of timing out.
    final payload = await Isolate.run(
      () => _compressForCloudInIsolate(imageBytes, mimeType),
    );
    debugPrint(
      '☁️ Uploading image to Gemini (${(payload.bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)...',
    );

    for (int attempt = 1; attempt <= _maxRetriesOnServerError; attempt++) {
      try {
        final stopwatch = Stopwatch()..start();

        final response = await _model
            .generateContent([
              Content.multi([
                InlineDataPart(payload.mimeType, payload.bytes),
                const TextPart(_systemPrompt),
              ]),
            ])
            .timeout(
              const Duration(seconds: 18),
              onTimeout: () => throw TimeoutException(
                'Gemini Cloud ($_modelName) timed out after 18s.',
              ),
            );

        stopwatch.stop();
        debugPrint(
          '✅ Gemini Cloud responded in ${stopwatch.elapsedMilliseconds}ms',
        );

        final rawText = response.text;
        if (rawText == null || rawText.trim().isEmpty) {
          throw const FormatException(
            'Gemini returned an empty response body.',
          );
        }

        final Map<String, dynamic> decoded =
            jsonDecode(rawText) as Map<String, dynamic>;

        return ProduceScanResult.fromJson(
          decoded,
          source: ScanSource.geminiCloud,
          confidenceThreshold: reviewThreshold,
        );
      } catch (e) {
        final errorStr = e.toString();
        debugPrint(
          '⚠️ GeminiVisionService attempt $attempt ($_modelName) failed: $errorStr',
        );

        // Do NOT retry on Quota/Rate-Limit (429) or Timeout — retrying immediately
        // just burns the 5 RPM free-tier quota. Only retry transient 500/503 errors.
        final isTransientServerError =
            errorStr.contains('500') ||
            errorStr.contains('503') ||
            errorStr.contains('high demand') ||
            errorStr.contains('INTERNAL');

        if (!isTransientServerError || attempt == _maxRetriesOnServerError) {
          rethrow;
        }

        const backoffMs = 2000;
        debugPrint(
          '⏳ Transient 500 spike. Waiting ${backoffMs}ms before 1 retry...',
        );
        await Future.delayed(const Duration(milliseconds: backoffMs));
      }
    }

    throw StateError('Unreachable retry termination.');
  }
}

class _CompressedPayload {
  final Uint8List bytes;
  final String mimeType;
  const _CompressedPayload(this.bytes, this.mimeType);
}

/// Resizes images larger than 512px down to 512px JPEG (quality 80) in a background Isolate.
/// Preserves the original bytes and mimeType if decoding fails.
_CompressedPayload _compressForCloudInIsolate(
  Uint8List rawBytes,
  String fallbackMimeType,
) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) {
    return _CompressedPayload(rawBytes, fallbackMimeType);
  }

  final resized = (decoded.width > 512 || decoded.height > 512)
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 512 : null,
          height: decoded.height > decoded.width ? 512 : null,
        )
      : decoded;

  return _CompressedPayload(
    Uint8List.fromList(img.encodeJpg(resized, quality: 80)),
    'image/jpeg',
  );
}
