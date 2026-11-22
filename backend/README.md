# Backend

Firestore, Python scripts, and the API the app calls.

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
| `add_inventory_item` | `item` (the fields listed in `functions/user_data.py`) | the saved item with its `id` |
| `update_inventory_item` | `id`, `item` (only the fields to change) | the updated item |
| `delete_inventory_item` | `id` | the `id` |
| `get_profile` | nothing | the profile, or null if none is saved |
| `save_profile` | `displayName` | the saved profile |
| `delete_account` | nothing | the `id`; removes the profile, inventory, misidentification photos and login |
| `estimate_expiry` | `name`, `location`; optional `purchaseDate`, `ripeness`, `sourceId`, `category` | `expiryDate`, `shelfLifeDays`, `basis`, `matchedOn`, and a `warning` if USDA doesn't list that location |
| `find_recipes` | optional `withinDays` (1-14, default 3) | `ingredients` searched, `recipes`, and a `message` when there are none |
| `report_misidentification` | `image` (base64 JPEG/PNG, 5 MB max), `predictedLabel`, `correctLabel`, `confidence`, `source`; optional `alternatives`, `modelVersion` | the report `id` |

If Open Food Facts is slow or down, `lookup_barcode` returns an `unavailable` error and saves
nothing, so the app should offer manual entry. Signing up and logging in happen in the app with
Firebase Auth.

**Expiry estimates** (`expiry.py`) use the shelf-life days in `functions/data/shelf_life.json`,
which are approximate values based on USDA FoodKeeper guidance. It tries the food's name first
("Fuji Apple" matches apple), then the produce or barcode record in `sourceId`, then `category`,
then a general default. `basis` says which one was used.

**Recipe search** (`recipes.py`) uses the user's active items expiring within `withinDays`. It
asks Spoonacular first, dropping the item that expires last until something matches, then falls
back to TheMealDB one ingredient at a time. No matches returns an empty list with a `message`;
only when every search fails to connect does it return `unavailable`.

**Misidentified produce** (`misidentifications.py`): when a user corrects a scan, the app sends
the photo and both labels. The photo is saved to Cloud Storage at `misidentified/{uid}/{id}.jpg`
and the details to the `misidentifications` collection, for retraining the model later. The app
should ask the user before sending their photo.

## Deploy

The project needs the Blaze plan, Authentication turned on, a Firestore database, and Cloud
Storage turned on (for misidentification photos). Run from the repo root:

```bash
npm install -g firebase-tools    # installs the firebase command
firebase login                   # opens a browser to sign in with Google

# Firebase needs its own environment inside functions/ to deploy (one time only)
python3.13 -m venv backend/functions/venv
backend/functions/venv/bin/pip install -r backend/functions/requirements.txt

# Spoonacular API key for find_recipes (one time only; free key at spoonacular.com/food-api)
firebase functions:secrets:set SPOONACULAR_KEY

firebase deploy --only functions,firestore:rules  # prints "Deploy complete!"
```

The rules then show up in the Firebase console under Firestore Database → Rules, and the API under Functions.

## Test

```bash
pytest          # prints "20 passed"
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
