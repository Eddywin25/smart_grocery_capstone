"""Estimate when a grocery item will expire, based on where it's stored.

Shelf-life days come from data/shelf_life.json (USDA FoodKeeper guidance). For each item we
use the most specific estimate we can find, in this order:

  1. the food itself, matched by name ("Fuji Apple" -> apple)
  2. the produce or barcode record it came from (sourceId)
  3. the category the app sent (e.g. Dairy)
  4. a general default ("Other")

Ripeness then adjusts the result: unripe produce lasts longer, overripe produce less.
"""

import json
import re
from datetime import UTC, datetime, timedelta
from pathlib import Path

from user_data import ALLOWED_VALUES, bad_request, is_date, is_text

SHELF_LIFE = json.loads((Path(__file__).parent / "data" / "shelf_life.json").read_text())
FOODS = SHELF_LIFE["foods"]
CATEGORIES = SHELF_LIFE["categories"]
ALIASES = SHELF_LIFE["aliases"]

LOCATIONS = ALLOWED_VALUES["location"]
RIPENESS = ALLOWED_VALUES["ripeness"]

# Counter and pantry are both room temperature, so one can stand in for the other
ROOM_TEMPERATURE = {"counter": "pantry", "pantry": "counter"}

# When USDA doesn't list a storage location for a food, assume it won't last
NOT_LISTED_DAYS = 1

UNRIPE_EXTRA_DAYS = 3


def parse_date(text: str) -> datetime:
    """Read ISO 8601 date text. Dates without a time zone are treated as UTC."""
    date = datetime.fromisoformat(text)
    return date if date.tzinfo else date.replace(tzinfo=UTC)


def food_key(name) -> str | None:
    """Return the shelf-life entry for a food name, or None if there isn't one.

    Matches the whole name first, then its last word, so "Granny Smith Apple" and
    "Red Seedless Grapes" find apple and grape.
    """
    if not is_text(name):
        return None

    words = re.sub(r"[^a-z ]", " ", name.lower()).split()
    if not words:
        return None

    for candidate in [" ".join(words), words[-1]]:
        for form in [candidate, singular(candidate)]:
            form = ALIASES.get(form, form)
            if form in FOODS:
                return form
    return None


def singular(word: str) -> str:
    """Return a simple singular form: tomatoes -> tomato, carrots -> carrot."""
    if word.endswith("oes"):
        return word[:-2]
    if word.endswith("s") and not word.endswith("ss"):
        return word[:-1]
    return word


def days_for(entry: dict, location: str) -> tuple[int, bool]:
    """Return (days, listed) for a location in a shelf-life entry.

    listed is False when the entry has no value for that location, in which case a
    short NOT_LISTED_DAYS estimate is returned.
    """
    if location in entry:
        return entry[location], True
    other = ROOM_TEMPERATURE.get(location)
    if other in entry:
        return entry[other], True
    return NOT_LISTED_DAYS, False


def estimate_from_record(db, source_id: str, location: str) -> tuple[int, bool, str, str] | None:
    """Return (days, listed, basis, matchedOn) from the produce or product record, or None.

    A 4-5 digit sourceId is a produce PLU; an 8 or 13 digit one is a product barcode.
    """
    if not source_id.isdigit():
        return None

    if len(source_id) in (4, 5):
        snapshot = db.collection("produce").document(source_id).get()
        if not snapshot.exists:
            return None
        record = snapshot.to_dict()

        key = food_key(record.get("mlLabel")) or food_key(record.get("name"))
        if key:
            return (*days_for(FOODS[key], location), "food", key)
        if location == record.get("defaultLocation") and record.get("shelfLifeDays"):
            return record["shelfLifeDays"], True, "produce", source_id
        category = record.get("category")

    elif len(source_id) in (8, 13):
        snapshot = db.collection("products").document(source_id).get()
        if not snapshot.exists or snapshot.to_dict().get("notFound"):
            return None
        category = snapshot.to_dict().get("category")

    else:
        return None

    if category in CATEGORIES:
        return (*days_for(CATEGORIES[category], location), "category", category)
    return None


def adjust_for_ripeness(days: int, ripeness, location: str) -> int:
    """Lengthen or shorten the estimate for unripe or overripe produce (not in the freezer)."""
    if location == "freezer" or ripeness is None:
        return days
    if ripeness == "Unripe":
        return days + UNRIPE_EXTRA_DAYS
    if ripeness == "Overripe":
        return max(1, days // 3)
    return days


def estimate_expiry(db, data: dict) -> dict:
    """Estimate an item's expiry date.

    Sends: name, location, and optionally purchaseDate (defaults to now), ripeness,
    sourceId (produce PLU or barcode) and category.
    Returns: expiryDate, shelfLifeDays, basis (food | produce | category | default),
    matchedOn, and a warning if USDA doesn't list that storage location for the food.
    """
    name = data.get("name")
    location = data.get("location")
    purchase_date = data.get("purchaseDate")
    ripeness = data.get("ripeness")
    source_id = data.get("sourceId")
    category = data.get("category")

    problems = []
    if not is_text(name):
        problems.append("name must be non-empty text")
    if location not in LOCATIONS:
        problems.append(f"location must be one of {LOCATIONS}")
    if purchase_date is not None and not is_date(purchase_date):
        problems.append("purchaseDate must be a date like 2026-11-08T12:00:00")
    if ripeness is not None and ripeness not in RIPENESS:
        problems.append(f"ripeness must be one of {RIPENESS}")
    if source_id is not None and not is_text(source_id):
        problems.append("sourceId must be non-empty text")
    if problems:
        raise bad_request("; ".join(problems))

    # Steps 1-4: use the most specific estimate available
    key = food_key(name)
    if key:
        days, listed = days_for(FOODS[key], location)
        basis, matched_on = "food", key
    else:
        from_record = estimate_from_record(db, source_id.strip(), location) if source_id else None
        if from_record:
            days, listed, basis, matched_on = from_record
        elif category in CATEGORIES:
            days, listed = days_for(CATEGORIES[category], location)
            basis, matched_on = "category", category
        else:
            days, listed = days_for(CATEGORIES["Other"], location)
            basis, matched_on = "default", "Other"

    days = adjust_for_ripeness(days, ripeness, location)

    start = datetime.fromisoformat(purchase_date) if purchase_date else datetime.now(UTC)
    result = {
        "expiryDate": (start + timedelta(days=days)).isoformat(),
        "shelfLifeDays": days,
        "basis": basis,
        "matchedOn": matched_on,
    }
    if not listed:
        result["warning"] = (
            f"USDA doesn't list {location} storage for {matched_on}, so this is a short estimate."
        )
    return result
