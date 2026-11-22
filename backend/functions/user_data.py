"""Each user's account profile and grocery inventory.

Every function takes the signed-in user's ID, so people can only reach their own data.
The allowed inventory fields are listed below.
"""

from datetime import UTC, datetime

from firebase_admin import auth
from firebase_functions.https_fn import FunctionsErrorCode, HttpsError
from google.cloud.firestore import DELETE_FIELD

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
# Optional fields an update can remove by sending null. status always keeps a value.
CLEARABLE_ITEM_FIELDS = ["sourceId", "ripeness"]
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
    """Return the error the app gets when it sends invalid data."""
    return HttpsError(FunctionsErrorCode.INVALID_ARGUMENT, message)


def is_text(value) -> bool:
    """Return True if value is text with something other than spaces in it."""
    return isinstance(value, str) and value.strip() != ""


def is_date(value) -> bool:
    """Return True if value is ISO 8601 date text, e.g. 2026-11-08T12:00:00."""
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


def trimmed_fields(fields) -> dict:
    """Return the fields with spaces trimmed from text, so " Milk " is saved as "Milk"."""
    if not isinstance(fields, dict):
        raise bad_request("item fields are required")
    return {
        field: value.strip() if isinstance(value, str) else value
        for field, value in fields.items()
    }


def validated_fields(fields, required: list[str]) -> dict:
    """Return the fields to save for a new item, or stop with everything that's wrong."""
    # The app sends null for empty optional fields; treat those as not sent
    fields = {field: value for field, value in trimmed_fields(fields).items() if value is not None}

    problems = [f"{field} is required" for field in required if field not in fields]
    problems += find_item_problems(fields)
    if problems:
        raise bad_request("; ".join(problems))

    return fields


def validated_changes(fields) -> tuple[dict, list[str]]:
    """Return (fields to change, fields to remove) for an update, or stop if anything's wrong.

    Sending null for sourceId or ripeness removes it. Other fields can't be removed.
    """
    fields = trimmed_fields(fields)
    changes = {field: value for field, value in fields.items() if value is not None}
    cleared = [field for field, value in fields.items() if value is None]

    problems = find_item_problems(changes)
    for field in cleared:
        if field not in REQUIRED_ITEM_FIELDS + OPTIONAL_ITEM_FIELDS:
            problems.append(f"unknown field {field!r}")
        elif field not in CLEARABLE_ITEM_FIELDS:
            problems.append(f"{field} can't be removed")
    if problems:
        raise bad_request("; ".join(problems))

    return changes, cleared


def inventory(db, uid: str):
    """Return the user's inventory collection, users/{uid}/inventory."""
    return db.collection("users").document(uid).collection("inventory")


def item_document(db, uid: str, item_id):
    """Return a reference to one inventory item."""
    # A "/" would point at a different place in the database
    if not is_text(item_id) or "/" in item_id:
        raise bad_request("id must be an inventory item's ID")
    return inventory(db, uid).document(item_id)


# --- Inventory ---


def list_items(db, uid: str) -> list[dict]:
    """Return every item in the user's inventory, each with its id."""
    return [{"id": doc.id, **doc.to_dict()} for doc in inventory(db, uid).stream()]


def add_item(db, uid: str, fields) -> dict:
    """Save a new item (status defaults to active) and return it with its new id."""
    item = validated_fields(fields, REQUIRED_ITEM_FIELDS)
    item.setdefault("status", "active")
    item["updatedAt"] = now()

    doc = inventory(db, uid).document()  # Firestore picks a new ID
    doc.set(item)
    return {"id": doc.id, **item}


def update_item(db, uid: str, item_id, fields) -> dict:
    """Change only the fields that were sent, and return the updated item.

    Sending null for sourceId or ripeness removes that field.
    """
    doc = item_document(db, uid, item_id)
    changes, cleared = validated_changes(fields)

    snapshot = doc.get()
    if not snapshot.exists:
        raise HttpsError(FunctionsErrorCode.NOT_FOUND, "item not found")

    changes["updatedAt"] = now()
    doc.update({**changes, **{field: DELETE_FIELD for field in cleared}})

    # Build the result from the read above instead of reading the document again
    item = {**snapshot.to_dict(), **changes}
    for field in cleared:
        item.pop(field, None)
    return {"id": doc.id, **item}


def delete_item(db, uid: str, item_id) -> dict:
    """Delete one item from the user's inventory and return its id."""
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
    """Save the user's display name and email (null for anonymous users) and return them."""
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
