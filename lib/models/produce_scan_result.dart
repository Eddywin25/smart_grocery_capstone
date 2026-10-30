import 'dart:convert';

/// Where a recognition result came from.
enum ScanSource { edgeMl, geminiCloud }

/// The single object the recognition engine returns for produce,
/// whether it was recognized on-device or by Gemini.
class ProduceScanResult {
  final String itemName; // e.g., "Banana"
  final String category; // "Fruit", "Vegetable", "Herb", or "Other"
  final double confidence; // 0.0 to 1.0
  final ScanSource source; // edgeMl or geminiCloud
  final String? ripeness; // "Unripe", "Ripe", "Overripe", or null
  final int? estDaysUntilSpoil; // Gemini's estimate, if any
  final List<String> alternatives; // runner-up guesses for the fix screen
  final bool needsReview; // true for low-confidence or offline guesses

  const ProduceScanResult({
    required this.itemName,
    required this.category,
    required this.confidence,
    required this.source,
    this.ripeness,
    this.estDaysUntilSpoil,
    this.alternatives = const [],
    this.needsReview = false,
  });

  /// Fake data so the UI (Person C) can be built before recognition works.
  static const sample = ProduceScanResult(
    itemName: 'Banana',
    category: 'Fruit',
    confidence: 0.94,
    source: ScanSource.edgeMl,
    ripeness: 'Ripe',
    estDaysUntilSpoil: 4,
    alternatives: ['Plantain', 'Mango'],
  );

  /// Parses the structured JSON returned by Gemini or local storage.
  factory ProduceScanResult.fromJson(
    Map<String, dynamic> json, {
    ScanSource source = ScanSource.geminiCloud,
    double confidenceThreshold = 0.75,
  }) {
    final parsedConfidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;
    final rawRipeness = json['ripeness'] as String?;

    return ProduceScanResult(
      itemName: json['itemName'] as String? ?? 'Unknown Item',
      category: json['category'] as String? ?? 'Other',
      confidence: parsedConfidence,
      source: source,
      ripeness: (rawRipeness == 'N/A') ? null : rawRipeness,
      estDaysUntilSpoil: (json['estDaysUntilSpoil'] as num?)?.toInt(),
      alternatives:
          (json['alternatives'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      // Automatically flag for user review if confidence is below threshold
      needsReview:
          json['needsReview'] as bool? ??
          (parsedConfidence < confidenceThreshold),
    );
  }

  /// Converts the object to a Map for Hive/Firestore storage or debugging.
  Map<String, dynamic> toJson() => {
    'itemName': itemName,
    'category': category,
    'confidence': confidence,
    'source': source.name, // Serializes enum as "edgeMl" or "geminiCloud"
    'ripeness': ripeness,
    'estDaysUntilSpoil': estDaysUntilSpoil,
    'alternatives': alternatives,
    'needsReview': needsReview,
  };

  /// Pretty-prints JSON for the POC debug screen and console logs.
  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
