import 'package:hive/hive.dart';
part 'inventory_item.g.dart';


// Inventory Item Model and Attributes (Interfaced with Hive)

// Possible storage locations
@HiveType(typeId: 1)
enum StorageLocation { 
  @HiveField(0)
  fridge, 

  @HiveField(1)
  freezer, 

  @HiveField(2)
  pantry, 

  @HiveField(3)
  counter 
}

// Possible types of packaging
@HiveType(typeId: 2)
enum Package { 
  @HiveField(0)
  box, 
  
  @HiveField(1)
  cup, 
  
  @HiveField(2)
  bag, 
  
  @HiveField(3)
  package, 
  
  @HiveField(4)
  pouch, 
  
  @HiveField(5)
  bottle, 
  
  @HiveField(6)
  jug, 
  
  @HiveField(7)
  jar, 
  
  @HiveField(8)
  item 
}

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
@HiveType(typeId:3)
enum FoodItemOutcome { 
  @HiveField(0)
  finished, 
  
  @HiveField(1)
  spoiled, 
  
  @HiveField(2)
  deleted 
}

// Grocery item and associated attributes
@HiveType(typeId: 0)
class InventoryItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int quantity;

  @HiveField(3)
  final StorageLocation location;

  @HiveField(4)
  final DateTime purchaseDate;

  @HiveField(5)
  final DateTime expiryDate;

  @HiveField(6)
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
    if (days == 0) {
      return "Expires today";
    }
    if (days == 1) {
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
  InventoryItem itemCopyUpdate({
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