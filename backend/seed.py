"""Upload the produce list (data/produce.json) to the 'produce' collection in Firestore.

Every record is checked with schema_check.py first. If anything is wrong, nothing is uploaded.

Usage:
    python seed.py --dry-run                      # check the data only, no Firebase needed
    python seed.py                                # upload using ./service-account.json
    python seed.py --key path/to/key.json         # upload using a key somewhere else
"""

import argparse
import json
import sys
from pathlib import Path

from schema_check import validate_produce

DATA_FILE = Path(__file__).parent / "data" / "produce.json"


def load_produce() -> list[dict]:
    """Read produce.json, check every record, and return the list.

    Stops the program with a list of problems if any record is invalid.
    """
    items = json.loads(DATA_FILE.read_text())
    problems = []

    # Check each record's fields (see schema_check.py)
    for item in items:
        name = item.get("name", "?")
        for error in validate_produce(item):
            problems.append(f"{name}: {error}")

    # Check that no two records share a PLU, since the PLU is the Firestore document ID
    seen_plus = set()
    for item in items:
        plu = item.get("plu")
        if plu in seen_plus:
            problems.append(f"duplicate plu {plu}")
        seen_plus.add(plu)

    if problems:
        sys.exit("Invalid produce data:\n  " + "\n  ".join(problems))

    return items


def upload(items: list[dict], key_path: str) -> None:
    """Write each record to Firestore as produce/{plu}."""
    # Imported here so --dry-run and the tests work without firebase-admin installed
    import firebase_admin
    from firebase_admin import credentials, firestore

    firebase_admin.initialize_app(credentials.Certificate(key_path))
    db = firestore.client()

    # A batch sends all the writes together, so either they all save or none do
    batch = db.batch()
    for item in items:
        doc = db.collection("produce").document(item["plu"])
        batch.set(doc, item)
    batch.commit()


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload data/produce.json to Firestore.")
    parser.add_argument("--key", default="service-account.json",
                        help="path to the Firebase service account key")
    parser.add_argument("--dry-run", action="store_true",
                        help="check the data without uploading")
    args = parser.parse_args()

    # Step 1: load and check the data
    items = load_produce()

    if args.dry_run:
        print(f"{len(items)} produce items valid (dry run, nothing uploaded)")
        return

    # Step 2: make sure the Firebase key exists
    if not Path(args.key).exists():
        sys.exit(f"Service account key not found: {args.key} (see README.md)")

    # Step 3: upload
    upload(items, args.key)
    print(f"Uploaded {len(items)} items to the 'produce' collection")


if __name__ == "__main__":
    main()
