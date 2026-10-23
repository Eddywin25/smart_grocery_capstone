"""Validation for the reference data stored in Firestore. See SCHEMA.md."""

CATEGORIES = {"fruit", "vegetable"}
LOCATIONS = {"fridge", "pantry", "counter"}


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

    if item.get("default_location") not in LOCATIONS:
        errors.append(f"default_location must be one of {sorted(LOCATIONS)}")

    days = item.get("shelf_life_days")
    if not (isinstance(days, int) and not isinstance(days, bool) and days > 0):
        errors.append("shelf_life_days must be a positive integer")

    return errors
