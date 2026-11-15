"""Tests for user_data.py and the sign-in check. Firestore is faked, so these run offline."""

from unittest.mock import MagicMock, patch

import main
import pytest
import user_data
from firebase_functions.https_fn import FunctionsErrorCode, HttpsError


def make_item():
    """Return a valid inventory item that each test can change."""
    return {
        "name": "Milk",
        "quantity": 2,
        "packageType": "jug",
        "location": "fridge",
        "purchaseDate": "2026-11-08T12:00:00.000",
        "expiryDate": "2026-11-15T12:00:00.000",
        "source": "barcode",
        "sourceId": "3017620422003",
    }


def fake_item_document(db):
    """Return the fake document that inventory functions read and write."""
    users = db.collection.return_value
    return users.document.return_value.collection.return_value.document.return_value


def test_add_item_saves_it_as_active():
    db = MagicMock()
    fake_item_document(db).id = "item1"

    result = user_data.add_item(db, "user1", make_item())

    assert result["id"] == "item1"
    assert result["status"] == "active"
    saved = fake_item_document(db).set.call_args.args[0]
    assert saved["name"] == "Milk"
    assert "updatedAt" in saved


def test_add_item_uses_the_callers_folder():
    db = MagicMock()
    user_data.add_item(db, "user1", make_item())
    db.collection.return_value.document.assert_called_with("user1")


def test_null_optional_fields_are_left_out():
    db = MagicMock()
    item = make_item()
    item["ripeness"] = None

    user_data.add_item(db, "user1", item)

    assert "ripeness" not in fake_item_document(db).set.call_args.args[0]


@pytest.mark.parametrize(
    "field, value",
    [
        ("name", ""),
        ("quantity", 0),
        ("quantity", "2"),
        ("quantity", True),
        ("packageType", "crate"),
        ("location", "garage"),
        ("purchaseDate", "yesterday"),
        ("expiryDate", 20261108),
        ("source", "magic"),
        ("ripeness", "Rotten"),
        ("status", "gone"),
        ("mistake", "unknown field"),
    ],
)
def test_add_item_rejects_bad_fields(field, value):
    db = MagicMock()
    item = make_item()
    item[field] = value

    with pytest.raises(HttpsError) as error:
        user_data.add_item(db, "user1", item)

    assert error.value.code == FunctionsErrorCode.INVALID_ARGUMENT
    fake_item_document(db).set.assert_not_called()


@pytest.mark.parametrize("field", user_data.REQUIRED_ITEM_FIELDS)
def test_add_item_requires_each_field(field):
    item = make_item()
    del item[field]
    with pytest.raises(HttpsError):
        user_data.add_item(MagicMock(), "user1", item)


@pytest.mark.parametrize("fields", [None, "milk", []])
def test_add_item_rejects_non_item_data(fields):
    with pytest.raises(HttpsError):
        user_data.add_item(MagicMock(), "user1", fields)


def test_list_items_includes_each_id():
    db = MagicMock()
    doc = MagicMock(id="item1")
    doc.to_dict.return_value = {"name": "Milk"}
    db.collection.return_value.document.return_value.collection.return_value.stream.return_value = [
        doc
    ]

    assert user_data.list_items(db, "user1") == [{"id": "item1", "name": "Milk"}]


def test_update_item_changes_only_what_was_sent():
    db = MagicMock()
    document = fake_item_document(db)
    document.get.return_value.exists = True

    user_data.update_item(db, "user1", "item1", {"quantity": 1})

    changes = document.update.call_args.args[0]
    assert set(changes) == {"quantity", "updatedAt"}


def test_update_item_validates_fields():
    db = MagicMock()
    with pytest.raises(HttpsError):
        user_data.update_item(db, "user1", "item1", {"quantity": -1})
    fake_item_document(db).update.assert_not_called()


def test_update_missing_item_is_not_found():
    db = MagicMock()
    fake_item_document(db).get.return_value.exists = False

    with pytest.raises(HttpsError) as error:
        user_data.update_item(db, "user1", "nope", {"quantity": 1})

    assert error.value.code == FunctionsErrorCode.NOT_FOUND


def test_delete_item():
    db = MagicMock()
    user_data.delete_item(db, "user1", "item1")
    fake_item_document(db).delete.assert_called_once()


@pytest.mark.parametrize("bad_id", [None, "", "../other", 5])
def test_bad_item_id_is_rejected(bad_id):
    with pytest.raises(HttpsError):
        user_data.delete_item(MagicMock(), "user1", bad_id)


def test_save_profile():
    db = MagicMock()
    profile = user_data.save_profile(db, "user1", "a@example.com", "  Sam ")

    assert profile["displayName"] == "Sam"
    assert profile["email"] == "a@example.com"
    db.collection.return_value.document.return_value.set.assert_called_once_with(
        profile, merge=True
    )


@pytest.mark.parametrize("bad_name", [None, "", "   ", 5])
def test_save_profile_requires_a_name(bad_name):
    with pytest.raises(HttpsError):
        user_data.save_profile(MagicMock(), "user1", None, bad_name)


def test_get_profile_is_none_before_one_is_saved():
    db = MagicMock()
    db.collection.return_value.document.return_value.get.return_value.exists = False
    assert user_data.get_profile(db, "user1") is None


def test_delete_account_removes_data_and_login():
    db = MagicMock()
    with patch("user_data.auth.delete_user") as delete_user:
        user_data.delete_account(db, "user1")

    db.recursive_delete.assert_called_once()
    delete_user.assert_called_once_with("user1")


def test_api_rejects_callers_who_are_not_signed_in():
    with pytest.raises(HttpsError) as error:
        main.signed_in_user(MagicMock(auth=None))
    assert error.value.code == FunctionsErrorCode.UNAUTHENTICATED


def test_api_returns_the_signed_in_user():
    assert main.signed_in_user(MagicMock(auth=MagicMock(uid="user1"))) == "user1"


@pytest.mark.parametrize("data", [None, "text", [1, 2]])
def test_api_treats_non_key_value_data_as_empty(data):
    assert main.request_data(MagicMock(data=data)) == {}
