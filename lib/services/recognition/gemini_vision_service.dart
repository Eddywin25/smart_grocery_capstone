import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../../models/produce_scan_result.dart';

class GeminiVisionService {
  static const List<String> _fallbackModels = [
    'gemini-3.8-flash',
    'gemini-3.8-flash',
    'gemini-3.8-flash',
  ];

  /// Strict JSON schema that forces Gemini to match ProduceScanResult
  static final Schema _produceSchema = Schema.object(
    properties: {
      'itemName': Schema.string(
        description: 'Specific produce name, e.g., Cavendish Banana',
      ),
      'category': Schema.enumString(
        enumValues: ['Fruit', 'Vegetable', 'Herb', 'Other'],
      ),
      'ripeness': Schema.enumString(
        enumValues: ['Unripe', 'Ripe', 'Overripe', 'N/A'],
      ),
      'estDaysUntilSpoil': Schema.integer(
        description: 'Estimated days left at room/fridge temp',
      ),
      'confidence': Schema.number(
        description: 'Confidence score between 0.0 and 1.0',
      ),
      'alternatives': Schema.array(
        items: Schema.string(),
        description: 'Top 2 runner-up produce guesses so the user can manually fix input',
      ),
    },
  );

  /// Identifies unpackaged produce from raw image bytes (JPEG/PNG)
  Future<ProduceScanResult> analyzeProduceImage(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    const prompt = '''
    Analyze this grocery item photo. Identify the specific produce item, its category, 
    its visual ripeness state, estimated days until spoilage, your confidence score, 
    and 2 similar-looking alternative items in case the user needs to correct the scan.
    ''';

    final imagePart = InlineDataPart(mimeType, imageBytes);
    final textPart = TextPart(prompt);

    for (int attempt = 0; attempt < _fallbackModels.length; attempt++) {
      final modelName = _fallbackModels[attempt];
      try {
        final model = FirebaseAI.googleAI().generativeModel(
          model: modelName,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: _produceSchema,
          ),
        );

        final response = await model.generateContent([
          Content.multi([textPart, imagePart]),
        ]);

        final rawText = response.text;
        if (rawText == null || rawText.isEmpty) {
          throw Exception('Empty response from $modelName');
        }

        final Map<String, dynamic> decoded = jsonDecode(rawText);
        return ProduceScanResult.fromJson(
          decoded,
          source: ScanSource.geminiCloud,
        );
      } catch (e) {
        debugPrint(
          '⚠️ GeminiVisionService attempt ${attempt + 1} ($modelName) failed: $e',
        );
        if (attempt == _fallbackModels.length - 1) rethrow;
        await Future.delayed(Duration(milliseconds: 1500 * (attempt + 1)));
      }
    }
    throw StateError('Unreachable');
  }
}
