"""Checks that produce records have the right fields before they go into Firestore.

Firestore stores whatever it's given, so this is what catches typos and missing fields.
The fields are described in SCHEMA.md. seed.py runs these checks on data/produce.json
before uploading, and the tests in tests/test_produce_data.py make sure the checks work.
"""

# Allowed values (these match the Flutter app's models)
CATEGORIES = ["Fruit", "Vegetable", "Herb", "Other"]
LOCATIONS = ["fridge", "freezer", "pantry", "counter"]


def validate_produce(item: dict) -> list[str]:
    """Check one produce record and return a list of problems.

    An empty list means the record is valid.
    """
    errors = []

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

    # Check 5: shelfLifeDays is a whole number above 0
    # (True/False count as numbers in Python, so they are rejected separately)
    days = item.get("shelfLifeDays")
    if isinstance(days, bool) or not isinstance(days, int):
        errors.append(f"shelfLifeDays must be a whole number, got {days!r}")
    elif days <= 0:
        errors.append(f"shelfLifeDays must be more than 0, got {days!r}")

    # Check 6: mlLabel is optional, but if it's there it can't be empty
    if "mlLabel" in item:
        label = item["mlLabel"]
        if not isinstance(label, str) or label.strip() == "":
            errors.append("mlLabel can't be empty (leave it out instead)")

    return errors
