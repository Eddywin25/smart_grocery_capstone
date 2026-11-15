"""The API the app calls. Firebase runs each function below as its own endpoint.

These are deliberately short: each one checks who is calling, then hands off to
barcode_lookup.py or user_data.py, where the real work happens.

From Flutter: FirebaseFunctions.instance.httpsCallable('lookup_barcode').call({'barcode': code})
"""

import barcode_lookup
import user_data
from firebase_admin import firestore, initialize_app
from firebase_functions import https_fn
from firebase_functions.options import set_global_options

initialize_app()

# Never run more than 10 copies at once, so a bug or traffic spike can't run up the bill
set_global_options(max_instances=10)


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
    signed_in_user(req)
    return barcode_lookup.lookup_barcode(firestore.client(), request_data(req).get("barcode"))


# --- Inventory ---


@https_fn.on_call()
def list_inventory(req):
    return user_data.list_items(firestore.client(), signed_in_user(req))


@https_fn.on_call()
def add_inventory_item(req):
    uid = signed_in_user(req)
    return user_data.add_item(firestore.client(), uid, request_data(req).get("item"))


@https_fn.on_call()
def update_inventory_item(req):
    uid = signed_in_user(req)
    data = request_data(req)
    return user_data.update_item(firestore.client(), uid, data.get("id"), data.get("item"))


@https_fn.on_call()
def delete_inventory_item(req):
    uid = signed_in_user(req)
    return user_data.delete_item(firestore.client(), uid, request_data(req).get("id"))


# --- Account ---


@https_fn.on_call()
def get_profile(req):
    return user_data.get_profile(firestore.client(), signed_in_user(req))


@https_fn.on_call()
def save_profile(req):
    uid = signed_in_user(req)
    email = req.auth.token.get("email")
    display_name = request_data(req).get("displayName")
    return user_data.save_profile(firestore.client(), uid, email, display_name)


@https_fn.on_call()
def delete_account(req):
    return user_data.delete_account(firestore.client(), signed_in_user(req))
