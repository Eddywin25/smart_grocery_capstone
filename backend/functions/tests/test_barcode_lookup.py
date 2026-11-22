"""Tests for barcode_lookup.py. Firestore and Open Food Facts are faked, so these run offline."""

import json
from unittest.mock import MagicMock, patch

import pytest
import requests
from barcode_lookup import clean_barcode, estimate_shelf_life, lookup_barcode
from firebase_functions.https_fn import FunctionsErrorCode, HttpsError

NUTELLA = {
    "product_name": "Nutella",
    "brands": "Nutella, Ferrero",
    "image_url": "https://example.com/nutella.jpg",
    "categories_tags": ["en:snacks", "en:spreads"],
}


def fake_db(saved_record=None):
    """Return a fake Firestore that holds saved_record for any product, if one is given."""
    db = MagicMock()
    saved = db.collection.return_value.document.return_value.get.return_value
    saved.exists = saved_record is not None
    saved.to_dict.return_value = saved_record
    return db


def saved_product(db):
    """Return the fake document that lookup_barcode reads from and saves to."""
    return db.collection.return_value.document.return_value


def off_response(body, status_code=200):
    """Build the response Open Food Facts would send."""
    response = requests.Response()
    response.status_code = status_code
    response._content = json.dumps(body).encode()
    return response


@pytest.mark.parametrize(
    "scanned, stored",
    [
        ("3017620422003", "3017620422003"),  # 13-digit EAN stays the same
        ("012345678905", "0012345678905"),  # 12-digit UPC gets a leading zero
        ("96385074", "96385074"),  # 8-digit EAN stays the same
        (" 3017620422003\n", "3017620422003"),  # stray spaces are removed
    ],
)
def test_clean_barcode_accepts_product_barcodes(scanned, stored):
    """Valid barcodes are trimmed, and 12-digit UPCs get a leading zero."""
    assert clean_barcode(scanned) == stored


@pytest.mark.parametrize("bad", ["", "abc", "123", "https://example.com", None, 3017620422003])
def test_clean_barcode_rejects_anything_else(bad):
    """Text, URLs, wrong lengths and non-text values are rejected."""
    with pytest.raises(HttpsError) as error:
        clean_barcode(bad)
    assert error.value.code == FunctionsErrorCode.INVALID_ARGUMENT


def test_saved_product_does_not_call_open_food_facts():
    """A product already in Firestore is returned without calling Open Food Facts."""
    record = {"barcode": "3017620422003", "name": "Nutella"}
    with patch("barcode_lookup.requests.get") as get:
        assert lookup_barcode(fake_db(record), "3017620422003") == record
    get.assert_not_called()


def test_saved_not_found_does_not_call_open_food_facts():
    """A barcode already saved as notFound isn't looked up again."""
    record = {"barcode": "3017620422003", "notFound": True}
    with patch("barcode_lookup.requests.get") as get:
        assert lookup_barcode(fake_db(record), "3017620422003") == record
    get.assert_not_called()


def test_new_product_is_fetched_and_saved():
    """A new barcode is fetched from Open Food Facts, cleaned up, and saved."""
    db = fake_db()
    answer = off_response({"status": 1, "product": NUTELLA})
    with patch("barcode_lookup.requests.get", return_value=answer):
        record = lookup_barcode(db, "3017620422003")

    assert record["name"] == "Nutella"
    assert record["brand"] == "Nutella"
    assert record["category"] == "Other"
    assert record["shelfLifeDays"] == 30
    saved_product(db).set.assert_called_once_with(record)


def test_request_identifies_the_app_and_has_a_timeout():
    """Requests send our User-Agent (Open Food Facts asks for one) and a 5 second timeout."""
    answer = off_response({"status": 1, "product": NUTELLA})
    with patch("barcode_lookup.requests.get", return_value=answer) as get:
        lookup_barcode(fake_db(), "3017620422003")

    assert "SmartGroceryCapstone" in get.call_args.kwargs["headers"]["User-Agent"]
    assert get.call_args.kwargs["timeout"] == 5


@pytest.mark.parametrize(
    "answer",
    [
        off_response({"status": 0}),  # Open Food Facts doesn't know it
        off_response({"status": 0}, status_code=404),
        off_response({"status": 1, "product": {"product_name": ""}}),  # no usable name
    ],
)
def test_unknown_product_is_saved_as_not_found(answer):
    """Unknown products (status 0, 404, or no name) are saved as notFound."""
    db = fake_db()
    with patch("barcode_lookup.requests.get", return_value=answer):
        record = lookup_barcode(db, "3017620422003")

    assert record["notFound"] is True
    saved_product(db).set.assert_called_once_with(record)


@pytest.mark.parametrize(
    "failure",
    [
        {"side_effect": requests.Timeout()},
        {"side_effect": requests.ConnectionError()},
        {"return_value": off_response({}, status_code=429)},  # rate limited
        {"return_value": off_response({}, status_code=500)},
    ],
)
def test_outage_tells_the_app_and_saves_nothing(failure):
    """Timeouts, connection errors, 429s and 500s return unavailable and save nothing."""
    db = fake_db()
    with patch("barcode_lookup.requests.get", **failure), pytest.raises(HttpsError) as error:
        lookup_barcode(db, "3017620422003")

    assert error.value.code == FunctionsErrorCode.UNAVAILABLE
    saved_product(db).set.assert_not_called()


@pytest.mark.parametrize("body", [b"", b"<html>Down for maintenance</html>", b"[]"])
def test_unusable_response_tells_the_app_and_saves_nothing(body):
    """A blank, HTML, or non-object body returns unavailable instead of a 500."""
    answer = requests.Response()
    answer.status_code = 200
    answer._content = body
    db = fake_db()

    with patch("barcode_lookup.requests.get", return_value=answer), pytest.raises(HttpsError) as error:
        lookup_barcode(db, "3017620422003")

    assert error.value.code == FunctionsErrorCode.UNAVAILABLE
    saved_product(db).set.assert_not_called()


@pytest.mark.parametrize(
    "tags, expected",
    [
        (["en:dairies", "en:yogurts"], ("Dairy", 10)),
        (["en:dairies", "en:frozen-foods"], ("Frozen", 180)),  # frozen wins over dairy
        (["en:spreads"], ("Other", 30)),
        ([], ("Other", 30)),
    ],
)
def test_estimate_shelf_life(tags, expected):
    """Category tags map to a shelf life, frozen wins over dairy, and unknown tags use the default."""
    assert estimate_shelf_life(tags) == expected
