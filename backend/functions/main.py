"""The API the app calls. Firebase runs each function below as its own endpoint.

These are deliberately short: each one checks who is calling, then hands off to
barcode_lookup.py, user_data.py, expiry.py, recipes.py or misidentifications.py,
where the real work happens.

From Flutter: FirebaseFunctions.instance.httpsCallable('lookup_barcode').call({'barcode': code})
"""

import barcode_lookup
import expiry
import misidentifications
import recipes
import user_data
from firebase_admin import firestore, initialize_app, storage
from firebase_functions import https_fn
from firebase_functions.options import set_global_options
from firebase_functions.params import SecretParam

initialize_app()

# Never run more than 10 copies at once, so a bug or traffic spike can't run up the bill
set_global_options(max_instances=10)

# Set once with: firebase functions:secrets:set SPOONACULAR_KEY
SPOONACULAR_KEY = SecretParam("SPOONACULAR_KEY")


def signed_in_user(req) -> str:
    """Return the caller's user ID, or stop if they aren't signed in."""
    if req.auth is None:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.UNAUTHENTICATED, "You must be signed in."
        )
    return req.auth.uid


def request_data(req) -> dict:
    """Return what the app sent, or an empty dict if it wasn't key/value data."""
    return req.data if isinstance(req.data, dict) else {}


# --- Barcode lookup ---


@https_fn.on_call()
def lookup_barcode(req):
    """Look up a scanned barcode. Sends: barcode. Returns: the product, or notFound."""
    signed_in_user(req)
    return barcode_lookup.lookup_barcode(firestore.client(), request_data(req).get("barcode"))


# --- Inventory ---


@https_fn.on_call()
def list_inventory(req):
    """Return all of the signed-in user's inventory items."""
    return user_data.list_items(firestore.client(), signed_in_user(req))


@https_fn.on_call()
def add_inventory_item(req):
    """Add an item. Sends: item. Returns: the saved item with its id."""
    uid = signed_in_user(req)
    return user_data.add_item(firestore.client(), uid, request_data(req).get("item"))


@https_fn.on_call()
def update_inventory_item(req):
    """Change an item. Sends: id, item (only the fields to change)."""
    uid = signed_in_user(req)
    data = request_data(req)
    return user_data.update_item(firestore.client(), uid, data.get("id"), data.get("item"))


@https_fn.on_call()
def delete_inventory_item(req):
    """Delete an item. Sends: id. Returns: the id."""
    uid = signed_in_user(req)
    return user_data.delete_item(firestore.client(), uid, request_data(req).get("id"))


# --- Expiry and recipes ---


@https_fn.on_call()
def estimate_expiry(req):
    """Estimate an expiry date. Sends: name, location, and optionally purchaseDate, ripeness,
    sourceId and category. Returns: expiryDate, shelfLifeDays, basis, matchedOn."""
    signed_in_user(req)
    return expiry.estimate_expiry(firestore.client(), request_data(req))


@https_fn.on_call(secrets=[SPOONACULAR_KEY])
def find_recipes(req):
    """Suggest recipes for items expiring soon. Sends: optionally withinDays (default 3).
    Returns: ingredients, recipes, and a message when there are none."""
    uid = signed_in_user(req)
    return recipes.find_recipes(
        firestore.client(), uid, request_data(req), SPOONACULAR_KEY.value or None
    )


# --- Misidentified produce ---


@https_fn.on_call()
def report_misidentification(req):
    """Log a scan the user corrected. Sends: image (base64), predictedLabel, correctLabel,
    confidence, source, and optionally alternatives and modelVersion. Returns: the report id."""
    uid = signed_in_user(req)
    return misidentifications.report_misidentification(
        firestore.client(), storage.bucket(), uid, request_data(req)
    )


# --- Account ---


@https_fn.on_call()
def get_profile(req):
    """Return the user's profile, or null if they haven't saved one."""
    return user_data.get_profile(firestore.client(), signed_in_user(req))


@https_fn.on_call()
def save_profile(req):
    """Save the user's profile. Sends: displayName. The email comes from their login."""
    uid = signed_in_user(req)
    email = req.auth.token.get("email")
    display_name = request_data(req).get("displayName")
    return user_data.save_profile(firestore.client(), uid, email, display_name)


@https_fn.on_call()
def delete_account(req):
    """Delete the user's profile, inventory, misidentification photos and login."""
    uid = signed_in_user(req)
    db = firestore.client()
    # Photos first: user_data.delete_account removes the login last, so a failure can be retried
    misidentifications.delete_user_reports(db, storage.bucket(), uid)
    return user_data.delete_account(db, uid)
