/// A product returned by the `lookup_barcode` Cloud Function
/// (`backend/functions/barcode_lookup.py`). Unknown products come back with
/// [notFound] set and no other details.
class ProductLookupResult {
  final String barcode;
  final String? name;
  final String? brand;
  final String? category;
  final String? imageUrl;
  final int? shelfLifeDays;
  final bool notFound;

  const ProductLookupResult({
    required this.barcode,
    this.name,
    this.brand,
    this.category,
    this.imageUrl,
    this.shelfLifeDays,
    this.notFound = false,
  });

  /// Parses the callable's response. Firebase hands back
  /// `Map<Object?, Object?>`, so keys and values are read defensively, and
  /// empty strings (Open Food Facts often has blank fields) become null.
  factory ProductLookupResult.fromMap(Map<Object?, Object?> data) {
    String? text(String key) {
      final value = data[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return ProductLookupResult(
      barcode: text('barcode') ?? '',
      name: text('name'),
      brand: text('brand'),
      category: text('category'),
      imageUrl: text('imageUrl'),
      shelfLifeDays: (data['shelfLifeDays'] as num?)?.toInt(),
      notFound: data['notFound'] == true,
    );
  }
}
