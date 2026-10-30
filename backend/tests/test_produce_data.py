"""Tests for the produce reference data (data/produce.json) and its validation (schema_check.py).

Checks that the seed data is valid, that every produce label from the on-device model has a
record, and that validate_produce accepts good records and rejects bad ones.
"""

import pytest

from schema_check import validate_produce
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
    items = load_produce()  # exits with a message if any record is invalid
    assert len(items) >= 25


def test_every_ml_produce_label_has_a_record():
    labels_in_data = []
    for item in load_produce():
        labels_in_data.append(item.get("mlLabel"))

    for label in ML_PRODUCE_LABELS:
        assert label in labels_in_data, f"no produce record has mlLabel {label!r}"


def test_valid_record_passes():
    item = make_banana()
    assert validate_produce(item) == []


def test_freezer_location_passes():
    item = make_banana()
    item["defaultLocation"] = "freezer"
    assert validate_produce(item) == []


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
        ("shelfLifeDays", True),
        ("mlLabel", ""),
    ],
)
def test_invalid_field_is_reported(field, value):
    item = make_banana()
    item[field] = value
    assert validate_produce(item) != []
