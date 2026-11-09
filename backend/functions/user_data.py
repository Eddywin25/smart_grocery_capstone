"""Each user's account profile and grocery inventory.

Every function takes the signed-in user's ID, so people can only reach their own data.
The fields are described in ../SCHEMA.md.
"""

from datetime import UTC, datetime

from firebase_admin import auth
from firebase_functions.https_fn import FunctionsErrorCode, HttpsError

REQUIRED_ITEM_FIELDS = [
    "name",
    "quantity",
    "packageType",
    "location",
    "purchaseDate",
    "expiryDate",
    "source",
]
OPTIONAL_ITEM_FIELDS = ["sourceId", "ripeness", "status"]
DATE_FIELDS = ["purchaseDate", "expiryDate"]

# Fields that must be one of a fixed list of values
ALLOWED_VALUES = {
    "packageType": ["box", "cup", "bag", "package", "pouch", "bottle", "jug", "jar", "item"],
    "location": ["fridge", "freezer", "pantry", "counter"],
    "source": ["manual", "barcode", "edgeMl", "geminiCloud"],
    "ripeness": ["Unripe", "Ripe", "Overripe"],
    "status": ["active", "finished", "spoiled"],
}


def now() -> str:
    """Return the current time as text, e.g. 2026-11-08T21:30:00+00:00."""
    return datetime.now(UTC).isoformat()


def bad_request(message: str) -> HttpsError:
    return HttpsError(FunctionsErrorCode.INVALID_ARGUMENT, message)


def is_text(value) -> bool:
    return isinstance(value, str) and value.strip() != ""


def is_date(value) -> bool:
    if not isinstance(value, str):
        return False
    try:
        datetime.fromisoformat(value)
    except ValueError:
        return False
    return True


def find_item_problems(fields: dict) -> list[str]:
    """Check the inventory fields that were sent. An empty list means they're all valid."""
    problems = []

    for field in fields:
        if field not in REQUIRED_ITEM_FIELDS + OPTIONAL_ITEM_FIELDS:
            problems.append(f"unknown field {field!r}")

    for field in ["name", "sourceId"]:
        if field in fields and not is_text(fields[field]):
            problems.append(f"{field} must be non-empty text")

    # (True/False count as numbers in Python, so they are rejected separately)
    if "quantity" in fields:
        quantity = fields["quantity"]
        if isinstance(quantity, bool) or not isinstance(quantity, int) or quantity <= 0:
            problems.append("quantity must be a whole number above 0")

    for field, allowed in ALLOWED_VALUES.items():
        if field in fields and fields[field] not in allowed:
            problems.append(f"{field} must be one of {allowed}")

    for field in DATE_FIELDS:
        if field in fields and not is_date(fields[field]):
            problems.append(f"{field} must be a date like 2026-11-08T12:00:00")

    return problems


def validated_fields(fields, required: list[str]) -> dict:
    """Return the fields to save, or stop with a list of everything that's wrong."""
    if not isinstance(fields, dict):
        raise bad_request("item fields are required")

    # The app sends null for empty optional fields; treat those as not sent
    fields = {field: value for field, value in fields.items() if value is not None}

    problems = [f"{field} is required" for field in required if field not in fields]
    problems += find_item_problems(fields)
    if problems:
        raise bad_request("; ".join(problems))

    return fields


def inventory(db, uid: str):
    return db.collection("users").document(uid).collection("inventory")


def item_document(db, uid: str, item_id):
    """Return a reference to one inventory item."""
    # A "/" would point at a different place in the database
    if not is_text(item_id) or "/" in item_id:
        raise bad_request("id must be an inventory item's ID")
    return inventory(db, uid).document(item_id)


# --- Inventory ---


def list_items(db, uid: str) -> list[dict]:
    return [{"id": doc.id, **doc.to_dict()} for doc in inventory(db, uid).stream()]


def add_item(db, uid: str, fields) -> dict:
    item = validated_fields(fields, REQUIRED_ITEM_FIELDS)
    item.setdefault("status", "active")
    item["updatedAt"] = now()

    doc = inventory(db, uid).document()  # Firestore picks a new ID
    doc.set(item)
    return {"id": doc.id, **item}


def update_item(db, uid: str, item_id, fields) -> dict:
    """Change only the fields that were sent."""
    doc = item_document(db, uid, item_id)
    changes = validated_fields(fields, required=[])

    if not doc.get().exists:
        raise HttpsError(FunctionsErrorCode.NOT_FOUND, "item not found")

    changes["updatedAt"] = now()
    doc.update(changes)
    return {"id": doc.id, **doc.get().to_dict()}


def delete_item(db, uid: str, item_id) -> dict:
    doc = item_document(db, uid, item_id)
    doc.delete()
    return {"id": doc.id}


# --- Account ---
# Signing up and logging in happen in the app through Firebase Auth. This is the profile
# we keep alongside the login.


def get_profile(db, uid: str) -> dict | None:
    """Return the user's profile, or None if they haven't saved one yet."""
    profile = db.collection("users").document(uid).get()
    return profile.to_dict() if profile.exists else None


def save_profile(db, uid: str, email: str | None, display_name) -> dict:
    if not is_text(display_name):
        raise bad_request("displayName must be non-empty text")

    profile = {"displayName": display_name.strip(), "email": email, "updatedAt": now()}
    db.collection("users").document(uid).set(profile, merge=True)
    return profile


def delete_account(db, uid: str) -> dict:
    """Delete the user's profile, all of their inventory, and their login."""
    # Data goes first: if something fails, the user can still log in and try again
    db.recursive_delete(db.collection("users").document(uid))
    auth.delete_user(uid)
    return {"id": uid}
