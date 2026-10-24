// Where a recognition result came from
enum ScanSource { edgeMl, geminiCloud }

// The single object the recognition enginer returns for produce,
// whether it was recognized on device or by Gemini
class ProduceScanResult {
  final String itemName; // e.g., Banana
  final String category; // "Fruit" or "Vegetable"
  final double confidence; // 0.0 to 1.0
  final ScanSource source; // edgeM1 or geminiCloud
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

  // Fake data so the UI can be build before recognition works
  static const sample = ProduceScanResult(
    itemName: 'Banana',
    category: 'Fruit',
    confidence: 0.94,
    source: ScanSource.edgeMl,
    ripeness: 'Ripe',
    estDaysUntilSpoil: 4,
    alternatives: ['Plantain', 'Mango'],
  );
}
