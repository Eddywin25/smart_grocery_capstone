// Determination of Expiry for a Food Item

// ExpiryEstService has expiry times hardcoded currently.
// This will be replaced by externally facing service to fetch recommended expiry.

class ExpiryEstService {
  static final Map<String, int> _shelfLifeDays = {
    'milk': 7,
    'yogurt': 14,
    'spinach': 5,
    'banana': 6,
    'apple': 30,
    'bread': 7,
    'tomato': 10,
    'potato': 45,
    'avocado': 7,
  };

  DateTime estimateExpiry(String itemName) {
    final days = _shelfLifeDays[itemName.toLowerCase()] ?? 7;

    return DateTime.now().add(Duration(days: days));
  }
}
