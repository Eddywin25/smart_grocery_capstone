import 'dart:convert';

enum ScanSource { edgeMl, geminiCloud, barcode, manual }

class ProduceScanResult {
  final String itemName;
  final String category;
  final double confidence;
  final ScanSource source;
  final String? ripeness;
  final int? estDaysUntilSpoil;
  final List<String> alternatives;
  final bool needsReview;

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

  factory ProduceScanResult.fromJson(
    Map<String, dynamic> json, {
    ScanSource source = ScanSource.geminiCloud,
    double confidenceThreshold = 0.75,
  }) {
    final parsedConfidence = (json['confidence'] as num?)?.toDouble() ?? 0.0;

    final rawSource = json['source'] as String?;
    final resolvedSource = rawSource != null
        ? ScanSource.values.firstWhere(
            (e) => e.name == rawSource,
            orElse: () => source,
          )
        : source;

    final rawRipeness = (json['ripeness'] as String?)?.trim();
    final normalizedRipeness =
        (rawRipeness == null ||
            rawRipeness.isEmpty ||
            rawRipeness.toUpperCase() == 'N/A' ||
            rawRipeness.toLowerCase() == 'null')
        ? null
        : rawRipeness;

    return ProduceScanResult(
      itemName: (json['itemName'] as String?)?.trim() ?? 'Unknown Item',
      category: (json['category'] as String?)?.trim() ?? 'Produce',
      confidence: parsedConfidence,
      source: resolvedSource,
      ripeness: normalizedRipeness,
      estDaysUntilSpoil: (json['estDaysUntilSpoil'] as num?)?.toInt(),
      alternatives:
          (json['alternatives'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      needsReview:
          json['needsReview'] as bool? ??
          (parsedConfidence < confidenceThreshold),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'category': category,
      'confidence': confidence,
      'source': source.name,
      'ripeness': ripeness,
      'estDaysUntilSpoil': estDaysUntilSpoil,
      'alternatives': alternatives,
      'needsReview': needsReview,
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}
