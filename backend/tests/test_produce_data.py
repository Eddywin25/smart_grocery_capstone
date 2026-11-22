"""Tests for the produce reference data (data/produce.json) and its validation (schema_check.py).

Checks that the seed data is valid, that every produce label from the on-device model has a
record, and that validate_produce accepts good records and rejects bad ones.
"""

import pytest

from schema_check import MAX_SHELF_LIFE_DAYS, find_duplicates, validate_produce
from seed import load_produce

# Produce labels from the on-device model (m1/models/grocery_labels_25.json)
ML_PRODUCE_LABELS = [
    "Apple",
    "Avocado",
    "Banana",
    "Carrots",
    "Kiwi",
    "Lemon",
    "Lime",
    "Melon",
    "Mushroom",
    "Onion",
    "Orange",
    "Peach",
    "Pear",
    "Pepper",
    "Potato",
    "Red-Grapefruit",
    "Satsumas",
    "Tomato",
]


def make_banana():
    """Return a valid produce record that each test can change."""
    return {
        "plu": "4011",
        "name": "Banana",
        "category": "Fruit",
        "defaultLocation": "counter",
        "shelfLifeDays": 5,
        "mlLabel": "Banana",
    }


def test_seed_data_is_valid():
    """The real produce.json passes every check and has at least 25 items."""
    items = load_produce()  # exits with a message if any record is invalid
    assert len(items) >= 25


def test_every_ml_produce_label_has_a_record():
    """Every label the on-device model can output matches some produce record."""
    labels_in_data = []
    for item in load_produce():
        labels_in_data.append(item.get("mlLabel"))

    for label in ML_PRODUCE_LABELS:
        assert label in labels_in_data, f"no produce record has mlLabel {label!r}"


def test_valid_record_passes():
    """A correct record has no problems."""
    item = make_banana()
    assert validate_produce(item) == []


def test_freezer_location_passes():
    """freezer is an allowed defaultLocation, not just fridge and counter."""
    item = make_banana()
    item["defaultLocation"] = "freezer"
    assert validate_produce(item) == []


def test_record_without_ml_label_passes():
    """mlLabel is optional, since the model doesn't recognize every produce item."""
    item = make_banana()
    del item["mlLabel"]
    assert validate_produce(item) == []


def test_max_shelf_life_passes():
    """Exactly MAX_SHELF_LIFE_DAYS (365) is still allowed."""
    item = make_banana()
    item["shelfLifeDays"] = MAX_SHELF_LIFE_DAYS
    assert validate_produce(item) == []


def test_misspelled_field_is_reported():
    """A typo in a field name is caught instead of being uploaded as a new field."""
    item = make_banana()
    item["mlLable"] = item.pop("mlLabel")
    assert validate_produce(item) == ["unknown field 'mlLable'"]


@pytest.mark.parametrize(
    "field, value",
    [
        ("plu", "40a1"),
        ("plu", 4011),
        ("name", ""),
        ("category", "fruit"),
        ("category", "meat"),
        ("defaultLocation", "garage"),
        ("shelfLifeDays", 0),
        ("shelfLifeDays", MAX_SHELF_LIFE_DAYS + 1),
        ("shelfLifeDays", True),
        ("mlLabel", ""),
    ],
)
def test_invalid_field_is_reported(field, value):
    """Each kind of bad value is caught for its field."""
    item = make_banana()
    item[field] = value
    assert validate_produce(item) != []


def test_unique_records_have_no_duplicates():
    """Different PLUs and names pass the duplicate check."""
    apple = {**make_banana(), "plu": "4131", "name": "Fuji Apple"}
    assert find_duplicates([make_banana(), apple]) == []


def test_duplicate_plu_is_reported():
    """Two records with the same PLU are caught, since one would overwrite the other."""
    other = {**make_banana(), "name": "Plantain"}
    assert find_duplicates([make_banana(), other]) == ["duplicate plu '4011'"]


def test_duplicate_name_is_reported():
    """Names are compared ignoring case and spaces, so "banana " repeats "Banana"."""
    other = {**make_banana(), "plu": "4235", "name": "banana "}
    assert find_duplicates([make_banana(), other]) == ["duplicate name 'banana '"]
