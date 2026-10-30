"""Validation for the reference data stored in Firestore. See SCHEMA.md."""

CATEGORIES = {"Fruit", "Vegetable", "Herb", "Other"}
LOCATIONS = {"fridge", "freezer", "pantry", "counter"}


def validate_produce(item: dict) -> list[str]:
    """Return a list of problems with one produce record (empty if valid)."""
    errors = []

    plu = item.get("plu")
    if not (isinstance(plu, str) and plu.isdigit() and len(plu) in (4, 5)):
        errors.append(f"plu must be a 4 or 5 digit string, got {plu!r}")

    name = item.get("name")
    if not (isinstance(name, str) and name.strip()):
        errors.append("name is required")

    if item.get("category") not in CATEGORIES:
        errors.append(f"category must be one of {sorted(CATEGORIES)}")

    if item.get("defaultLocation") not in LOCATIONS:
        errors.append(f"defaultLocation must be one of {sorted(LOCATIONS)}")

    days = item.get("shelfLifeDays")
    if not (isinstance(days, int) and not isinstance(days, bool) and days > 0):
        errors.append("shelfLifeDays must be a positive integer")

    if "mlLabel" in item:
        label = item["mlLabel"]
        if not (isinstance(label, str) and label.strip()):
            errors.append("mlLabel must be a non-empty string when present")

    return errors
