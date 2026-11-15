"""Find a packaged product by its barcode.

Our own 'products' collection in Firestore is checked first. Open Food Facts is only called
the first time anyone scans a barcode, and the answer is saved, which keeps us within its
rate limits and keeps repeat scans fast.
"""

from datetime import UTC, datetime

import requests
from firebase_functions.https_fn import FunctionsErrorCode, HttpsError

OPEN_FOOD_FACTS_URL = "https://world.openfoodfacts.org/api/v2/product/{}.json"
WANTED_FIELDS = "product_name,brands,image_url,categories_tags"
USER_AGENT = "SmartGroceryCapstone/1.0 (https://github.com/Eddywin25/smart_grocery_capstone)"
TIMEOUT_SECONDS = 5

# Open Food Facts doesn't say how long food lasts, so we estimate from its category tags.
# Each tag maps to (our category, shelf life in days). The first match wins, so frozen is
# listed first: ice cream is tagged as both frozen and dairy.
SHELF_LIFE_BY_TAG = {
    "en:frozen-foods": ("Frozen", 180),
    "en:dairies": ("Dairy", 10),
    "en:meats": ("Meat", 4),
    "en:seafood": ("Seafood", 2),
    "en:breads": ("Bread", 7),
    "en:beverages": ("Beverage", 30),
}
DEFAULT_SHELF_LIFE = ("Other", 30)


def clean_barcode(barcode) -> str:
    """Check a scanned barcode and return it in the form we store it."""
    if not isinstance(barcode, str):
        raise HttpsError(FunctionsErrorCode.INVALID_ARGUMENT, "barcode must be text")

    barcode = barcode.strip()
    if not barcode.isdigit() or len(barcode) not in (8, 12, 13):
        raise HttpsError(FunctionsErrorCode.INVALID_ARGUMENT, "barcode must be 8, 12 or 13 digits")

    # A 12-digit UPC is the same product as a 13-digit EAN with a leading zero
    if len(barcode) == 12:
        barcode = "0" + barcode

    return barcode


def fetch_from_open_food_facts(barcode: str) -> dict | None:
    """Return Open Food Facts' data for this barcode, or None if it doesn't know the product."""
    try:
        response = requests.get(
            OPEN_FOOD_FACTS_URL.format(barcode),
            params={"fields": WANTED_FIELDS},
            headers={"User-Agent": USER_AGENT},
            timeout=TIMEOUT_SECONDS,
        )
        if response.status_code == 404:
            return None
        response.raise_for_status()
        answer = response.json()
    except requests.RequestException as error:
        # Slow or down: tell the app to offer manual entry, and save nothing
        raise HttpsError(
            FunctionsErrorCode.UNAVAILABLE,
            "Product lookup is unavailable right now. Please enter the item by hand.",
        ) from error

    if answer.get("status") != 1:
        return None
    return answer.get("product")


def estimate_shelf_life(tags: list[str]) -> tuple[str, int]:
    """Return (category, shelf life in days) for a product's category tags."""
    for tag, estimate in SHELF_LIFE_BY_TAG.items():
        if tag in tags:
            return estimate
    return DEFAULT_SHELF_LIFE


def build_record(barcode: str, food: dict | None) -> dict:
    """Turn Open Food Facts' data into the record we save in 'products'."""
    fetched_at = datetime.now(UTC).isoformat()

    # A product with no name is no use to the app, so it counts as not found
    name = ((food or {}).get("product_name") or "").strip()
    if not name:
        return {"barcode": barcode, "notFound": True, "fetchedAt": fetched_at}

    category, shelf_life_days = estimate_shelf_life(food.get("categories_tags") or [])
    return {
        "barcode": barcode,
        "name": name,
        "brand": (food.get("brands") or "").split(",")[0].strip(),
        "category": category,
        "imageUrl": food.get("image_url") or "",
        "shelfLifeDays": shelf_life_days,
        "fetchedAt": fetched_at,
    }


def lookup_barcode(db, barcode) -> dict:
    """Return the product record for a barcode. Unknown products have notFound set to True."""
    barcode = clean_barcode(barcode)
    product_doc = db.collection("products").document(barcode)

    # Already saved? Then no outside call is needed.
    saved = product_doc.get()
    if saved.exists:
        return saved.to_dict()

    # Not saved yet: ask Open Food Facts, then keep the answer.
    record = build_record(barcode, fetch_from_open_food_facts(barcode))
    product_doc.set(record)
    return record
