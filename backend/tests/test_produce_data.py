import pytest

from schema import validate_produce
from seed import load_produce

# Produce labels from the on-device model (m1/models/grocery_labels_25.json)
ML_PRODUCE_LABELS = {
    "Apple", "Avocado", "Banana", "Carrots", "Kiwi", "Lemon", "Lime", "Melon", "Mushroom",
    "Onion", "Orange", "Peach", "Pear", "Pepper", "Potato", "Red-Grapefruit", "Satsumas",
    "Tomato",
}

VALID = {
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
    labels = {item.get("mlLabel") for item in load_produce()}
    assert ML_PRODUCE_LABELS <= labels


def test_valid_record_passes():
    assert validate_produce(VALID) == []


def test_freezer_location_passes():
    assert validate_produce({**VALID, "defaultLocation": "freezer"}) == []


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
    assert validate_produce({**VALID, field: value})
