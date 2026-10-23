"""Upload reference data (data/produce.json) to Firestore.

Usage:
    python seed.py --dry-run                      # validate only, no Firebase
    python seed.py                                # uses ./service-account.json
    python seed.py --key path/to/key.json
"""

import argparse
import json
import sys
from pathlib import Path

from schema import validate_produce

DATA_FILE = Path(__file__).parent / "data" / "produce.json"


def load_produce() -> list[dict]:
    items = json.loads(DATA_FILE.read_text())
    problems = []
    for item in items:
        problems += [f"{item.get('name', '?')}: {e}" for e in validate_produce(item)]
    plus = [item.get("plu") for item in items]
    problems += [f"duplicate plu {p}" for p in set(plus) if plus.count(p) > 1]
    if problems:
        sys.exit("Invalid produce data:\n  " + "\n  ".join(problems))
    return items


def upload(items: list[dict], key_path: str) -> None:
    import firebase_admin
    from firebase_admin import credentials, firestore

    firebase_admin.initialize_app(credentials.Certificate(key_path))
    db = firestore.client()
    batch = db.batch()
    for item in items:
        batch.set(db.collection("produce").document(item["plu"]), item)
    batch.commit()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--key", default="service-account.json")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    items = load_produce()
    if args.dry_run:
        print(f"{len(items)} produce items valid (dry run, nothing uploaded)")
        return
    if not Path(args.key).exists():
        sys.exit(f"Service account key not found: {args.key} (see README.md)")
    upload(items, args.key)
    print(f"Uploaded {len(items)} items to the 'produce' collection")


if __name__ == "__main__":
    main()
