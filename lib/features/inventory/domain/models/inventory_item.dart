// Inventory Item Model and Attributes

// Possible storage locations
enum StorageLocation { fridge, freezer, pantry, counter }

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

// Possible end states of food
enum FoodItemOutcome { finished, spoiled, deleted }

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

  // Get the purchased date in MM/DD/YYYY format
  String get displayPurchaseDate {
    return '${purchaseDate.month}/${purchaseDate.day}/${purchaseDate.year}';
  }

  // Get the expiry date in MM/DD/YYYY format
  String get displayExpiryDate {
    return '${expiryDate.month}/${expiryDate.day}/${expiryDate.year}';
  }

  // Get the quantity, package type, and the location of the item
  String get displayQuantLocation {
    return '$displayItemLocation : $displayQuantPackage';
  }

  // Get the quantity and package type only of the item
  String get displayQuantPackage {
    return '$quantity ${packageType.packageReference(quantity)}';
  }

  // Converts the food item to title case
  String get displayItemName {
  return name
      .split(' ')
      .map(
        (word) =>
            word[0].toUpperCase() +
            word.substring(1).toLowerCase(),
      )
      .join(' ');
  }

  // Capitalizes the food item's storage location
  String get displayItemLocation {
  return location.name[0].toUpperCase() + location.name.substring(1);
  }

  // Create new inventory item instance with updated attributes
  InventoryItem itemUpdate({
    String? id,
    String? name,
    int? quantity,
    StorageLocation? location,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    Package? packageType,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      location: location ?? this.location,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      packageType: packageType ?? this.packageType,
    );
  }

}