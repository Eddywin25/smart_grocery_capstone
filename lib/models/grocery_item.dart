// Grocery Item Constructor

class GroceryItem {
  final String id;
  final String name;
  final DateTime datePurchased;
  final int daysUntilSpoiled;
  final String location;

  GroceryItem({
    required this.id,
    required this.name,
    required this.datePurchased,
    required this.daysUntilSpoiled,
    required this.location
  });
}
