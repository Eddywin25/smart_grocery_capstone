import pytest

from schema import validate_produce
from seed import load_produce


def test_seed_data_is_valid():
    items = load_produce()  # exits with a message if any record is invalid
    assert len(items) >= 25


def test_valid_record_passes():
    item = {
        "plu": "4011",
        "name": "Banana",
        "category": "fruit",
        "default_location": "counter",
        "shelf_life_days": 5,
    }
    assert validate_produce(item) == []


@pytest.mark.parametrize(
    "field, value",
    [
        ("plu", "40a1"),
        ("plu", 4011),
        ("name", ""),
        ("category", "meat"),
        ("default_location", "freezer"),
        ("shelf_life_days", 0),
        ("shelf_life_days", True),
    ],
)
def test_invalid_field_is_reported(field, value):
    item = {
        "plu": "4011",
        "name": "Banana",
        "category": "fruit",
        "default_location": "counter",
        "shelf_life_days": 5,
        field: value,
    }
    assert validate_produce(item)
