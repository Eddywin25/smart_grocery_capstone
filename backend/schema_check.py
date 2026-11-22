"""Checks that produce records have the right fields before they go into Firestore.

Firestore stores whatever it's given, so this is what catches typos and missing fields.
The allowed fields and values are listed below. seed.py runs these checks on data/produce.json
before uploading, and the tests in tests/test_produce_data.py make sure the checks work.
"""

# Allowed values (these match the Flutter app's models, except "counter",
# which still needs adding to StorageLocation in the app)
CATEGORIES = ["Fruit", "Vegetable", "Herb", "Other"]
LOCATIONS = ["fridge", "freezer", "pantry", "counter"]

# Every field a produce record may have. Anything else (e.g. a typo like "mlLable") is rejected.
KNOWN_FIELDS = ["plu", "name", "category", "defaultLocation", "shelfLifeDays", "mlLabel"]

# Nothing in the produce list should last longer than a year
MAX_SHELF_LIFE_DAYS = 365


def validate_produce(item: dict) -> list[str]:
    """Check one produce record and return a list of problems.

    An empty list means the record is valid.
    """
    errors = []

    # Check 0: no unknown fields, so a misspelled field name doesn't get uploaded
    for field in item:
        if field not in KNOWN_FIELDS:
            errors.append(f"unknown field {field!r}")

    # Check 1: plu is a 4 or 5 digit code stored as text, e.g. "4011"
    plu = item.get("plu")
    if not isinstance(plu, str):
        errors.append(f"plu must be text like \"4011\", got {plu!r}")
    elif not plu.isdigit():
        errors.append(f"plu must only contain digits, got {plu!r}")
    elif len(plu) not in (4, 5):
        errors.append(f"plu must be 4 or 5 digits long, got {plu!r}")

    # Check 2: name is non-empty text, e.g. "Banana"
    name = item.get("name")
    if not isinstance(name, str) or name.strip() == "":
        errors.append("name is required")

    # Check 3: category is one of CATEGORIES
    category = item.get("category")
    if category not in CATEGORIES:
        errors.append(f"category must be one of {CATEGORIES}, got {category!r}")

    # Check 4: defaultLocation is one of LOCATIONS
    location = item.get("defaultLocation")
    if location not in LOCATIONS:
        errors.append(f"defaultLocation must be one of {LOCATIONS}, got {location!r}")

    # Check 5: shelfLifeDays is a whole number from 1 to MAX_SHELF_LIFE_DAYS
    # (True/False count as numbers in Python, so they are rejected separately)
    days = item.get("shelfLifeDays")
    if isinstance(days, bool) or not isinstance(days, int):
        errors.append(f"shelfLifeDays must be a whole number, got {days!r}")
    elif days <= 0:
        errors.append(f"shelfLifeDays must be more than 0, got {days!r}")
    elif days > MAX_SHELF_LIFE_DAYS:
        errors.append(f"shelfLifeDays must be at most {MAX_SHELF_LIFE_DAYS}, got {days!r}")

    # Check 6: mlLabel is optional, but if it's there it can't be empty
    if "mlLabel" in item:
        label = item["mlLabel"]
        if not isinstance(label, str) or label.strip() == "":
            errors.append("mlLabel can't be empty (leave it out instead)")

    return errors


def find_duplicates(items: list[dict]) -> list[str]:
    """Check the whole list for two records with the same PLU or name.

    The PLU is the Firestore document ID, so a repeat would overwrite the earlier record.
    Names are compared ignoring case and extra spaces, so "Banana" and "banana " count as
    the same. An empty list means there are no duplicates.
    """
    errors = []
    seen_plus = set()
    seen_names = set()

    for item in items:
        plu = item.get("plu")
        if plu in seen_plus:
            errors.append(f"duplicate plu {plu!r}")
        seen_plus.add(plu)

        name = item.get("name")
        if isinstance(name, str):
            key = name.strip().lower()
            if key in seen_names:
                errors.append(f"duplicate name {name!r}")
            seen_names.add(key)

    return errors
