# Firestore Schema

Field names are camelCase; the Flutter models' `toJson()` should use these names.

```
produce/{plu}
  plu, name, category, defaultLocation, shelfLifeDays, mlLabel?

products/{barcode}
  barcode, name, brand, category, imageUrl, shelfLifeDays, fetchedAt
  (or, if the product is unknown: barcode, notFound, fetchedAt)

users/{uid}
  displayName, email, updatedAt

users/{uid}/inventory/{itemId}
  name, quantity, packageType, location, purchaseDate, expiryDate,
  source, sourceId, ripeness?, status, updatedAt
```

- Dates and times (`purchaseDate`, `expiryDate`, `fetchedAt`, `updatedAt`) are ISO 8601 text,
  e.g. `2026-11-08T12:00:00`, which Dart's `toIso8601String()` and `DateTime.parse` handle
- `category` on `produce`: Fruit | Vegetable | Herb | Other (same values as `ProduceScanResult.category`)
- `category` on `products`: Frozen | Dairy | Meat | Seafood | Bread | Beverage | Other
- `{barcode}`: 8 or 13 digits; a 12-digit UPC is stored with a leading zero
- `shelfLifeDays` on `products`: an estimate from the category, since Open Food Facts doesn't provide one
- `location`: fridge | freezer | pantry | counter (`StorageLocation` in the app; `counter` still needs adding there)
- `quantity`: whole number (`InventoryItem.quantity` is an int)
- `packageType`: box | cup | bag | package | pouch | bottle | jug | jar | item (`Package` in the app)
- `source`: manual | barcode | edgeMl | geminiCloud (`ScanSource` names plus manual/barcode)
- `sourceId`: the produce PLU or product barcode the item came from, if any
- `ripeness`: Unripe | Ripe | Overripe, or absent
- `status`: active | finished | spoiled
- `mlLabel`: the on-device model's label for this produce (`m1/models/grocery_labels_25.json`),
  so a scan result can be matched to a produce record
