# Firestore Schema

```
produce/{plu}
  plu, name, category, default_location, shelf_life_days

products/{barcode}
  barcode, name, brand, category, image_url, shelf_life_days, fetched_at

users/{uid}/inventory/{itemId}
  name, source, source_id, location, quantity,
  date_purchased, expires_at, status, updated_at
```

- `category`: fruit | vegetable
- `location`: fridge | pantry | counter
- `source`: barcode | produce | manual
- `status`: active | finished | spoiled
