# Firestore Schema

Field names are camelCase; the Flutter models' `toJson()` should use these names.

```
produce/{plu}
  plu, name, category, defaultLocation, shelfLifeDays, mlLabel?

products/{barcode}
  barcode, name, brand, category, imageUrl, shelfLifeDays, fetchedAt

users/{uid}/inventory/{itemId}
  name, quantity, packageType, location, purchaseDate, expiryDate,
  source, sourceId, ripeness?, status, updatedAt
```

- `category`: Fruit | Vegetable | Herb | Other (same values as `ProduceScanResult.category`)
- `location`: fridge | freezer | pantry | counter (`StorageLocation` in the app; `counter` still needs adding there)
- `quantity`: whole number (`InventoryItem.quantity` is an int)
- `packageType`: box | cup | bag | package | pouch | bottle | jug | jar | item (`Package` in the app)
- `source`: manual | barcode | edgeMl | geminiCloud (`ScanSource` names plus manual/barcode)
- `sourceId`: the produce PLU or product barcode the item came from, if any
- `ripeness`: Unripe | Ripe | Overripe, or absent
- `status`: active | finished | spoiled
- `mlLabel`: the on-device model's label for this produce (`m1/models/grocery_labels_25.json`),
  so a scan result can be matched to a produce record
