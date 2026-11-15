# Backend

Firestore, Python scripts, and the API the app calls. Schema: [SCHEMA.md](SCHEMA.md).

## Setup

```bash
cd backend
python3.13 -m venv .venv    # creates a .venv folder
source .venv/bin/activate   # prompt now starts with (.venv)
pip install -r requirements-dev.txt -r functions/requirements.txt  # installs Firebase, pytest, ruff
```

## Seed

Save your Firebase service account key as `backend/service-account.json` (never commit it).

```bash
python seed.py --dry-run   # prints "31 produce items valid (dry run, nothing uploaded)"
python seed.py             # prints "Uploaded 31 items to the 'produce' collection"
```

After seeding, the `produce` collection shows up in the Firebase console under Firestore Database.

## API

The code is in `functions/`. The app calls these with `FirebaseFunctions.instance.httpsCallable('name')`.
Every call requires a signed-in user.

| Function | Send | Get back |
|---|---|---|
| `lookup_barcode` | `barcode` | the product, or a record with `notFound: true` |
| `list_inventory` | nothing | a list of the user's items |
| `add_inventory_item` | `item` (the fields in SCHEMA.md) | the saved item with its `id` |
| `update_inventory_item` | `id`, `item` (only the fields to change) | the updated item |
| `delete_inventory_item` | `id` | the `id` |
| `get_profile` | nothing | the profile, or null if none is saved |
| `save_profile` | `displayName` | the saved profile |
| `delete_account` | nothing | the `id`; removes the profile, inventory and login |

If Open Food Facts is slow or down, `lookup_barcode` returns an `unavailable` error and saves
nothing, so the app should offer manual entry. Signing up and logging in happen in the app with
Firebase Auth.

## Deploy

The project needs the Blaze plan, Authentication turned on, and a Firestore database. Run from the repo root:

```bash
npm install -g firebase-tools    # installs the firebase command
firebase login                   # opens a browser to sign in with Google

# Firebase needs its own environment inside functions/ to deploy (one time only)
python3.13 -m venv backend/functions/venv
backend/functions/venv/bin/pip install -r backend/functions/requirements.txt

firebase deploy --only functions,firestore:rules  # prints "Deploy complete!"
```

The rules then show up in the Firebase console under Firestore Database → Rules, and the API under Functions.

## Test

```bash
pytest          # prints "84 passed"
ruff check .    # prints "All checks passed!"
```

## CI

GitHub runs these checks on every push:

- **backend**: the tests and lint above, plus `python seed.py --dry-run`
- **flutter**: `flutter analyze` and `flutter test` (only the default demo test for now)

## Run the app

```bash
cd ..
flutter pub get   # downloads Flutter packages
flutter run       # builds and opens the app on a simulator, emulator, or Chrome
```
