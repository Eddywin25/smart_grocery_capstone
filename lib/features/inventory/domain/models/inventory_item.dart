// Inventory Item Model and Attributes

// Possible storage locations
enum StorageLocation { fridge, freezer, pantry }

// Possible types of packaging
enum Package { box, cup, bag, package, pouch, bottle, jug, jar, item }

// Allows determination of singular vs plural package type
extension PackageExtension on Package {
  String packageReference(int quantity) {
    switch (this) {
      case Package.box:
        return quantity == 1 ? "box" : "boxes";

      case Package.cup:
        return quantity == 1 ? "cup" : "cups";

      case Package.bag:
        return quantity == 1 ? "bag" : "bags";

      case Package.package:
        return quantity == 1 ? "package" : "packages";

      case Package.pouch:
        return quantity == 1 ? "pouch" : "pouches";

      case Package.bottle:
        return quantity == 1 ? "bottle" : "bottles";

      case Package.jug:
        return quantity == 1 ? "jug" : "jugs";

      case Package.jar:
        return quantity == 1 ? "jar" : "jars";

      case Package.item:
        return quantity == 1 ? "item" : "items";
    }
  }
}

// Grocery item and associated attributes
class InventoryItem {
  final String id;
  final String name;
  final int quantity;
  final StorageLocation location;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final Package packageType;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.location,
    required this.purchaseDate,
    required this.expiryDate,
    required this.packageType,
  });

  // Number of days from current date to estimated expiry date
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiryDay.difference(today).inDays;
  }
  
  // Flag for determining if food expires soon
  bool get expiresSoon => daysLeft <= 3;

  // Message to indicate expiry time
  String get expiryTime {
    final days = daysLeft;
    if (days < 0) {
      final overdue = days.abs();
      return overdue == 1 ? 'Expired 1 day ago' : 'Expired $overdue days ago';
    }
    if (daysLeft == 0) {
      return "Expires today";
    }
    if (daysLeft == 1) {
      return "Expires tomorrow";
    }
    return "Expires in $days days";
  }
}
