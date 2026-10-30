
// Possible storage locations
enum StorageLocation {
  fridge,
  freezer,
  pantry,
}

// Grocery item and associated attributes
class InventoryItem {
  final String id;
  final String name;
  final String quantity;
  final StorageLocation location;
  final DateTime purchaseDate;
  final DateTime expiryDate;


  const InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.location,
    required this.purchaseDate,
    required this.expiryDate,
  });

  // Number of days from current date to estimated expiry date
  int get daysLeft =>
      expiryDate.difference(DateTime.now()).inDays;

  // Flag for determining if food expires soon
  bool get expiresSoon =>
      daysLeft <= 3;

  // Message to indicate expiry time
  String get expiryTime {
    if (daysLeft <= 0) {
      return "Expires today";
    }

    if (daysLeft == 1) {
      return "Expires tomorrow";
    }

    return "Expires in $daysLeft days";
  }
}