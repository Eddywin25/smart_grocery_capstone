# Backend

Firestore + Python scripts. Schema: [SCHEMA.md](SCHEMA.md).

## Setup

```bash
cd backend
python3 -m venv .venv                                    # creates a .venv folder
source .venv/bin/activate                                # prompt now starts with (.venv)
pip install -r requirements.txt -r requirements-dev.txt  # installs firebase-admin, pytest, ruff
```

## Seed

Save your Firebase service account key as `backend/service-account.json` (never commit it).

```bash
python seed.py --dry-run   # prints "31 produce items valid (dry run, nothing uploaded)"
python seed.py             # prints "Uploaded 31 items to the 'produce' collection"
```

After seeding, the `produce` collection shows up in the Firebase console under Firestore Database.

## Deploy rules

Run from the repo root:

```bash
npm install -g firebase-tools           # installs the firebase command
firebase login                          # opens a browser to sign in with Google
firebase use --add                      # pick the team's Firebase project
firebase deploy --only firestore:rules  # prints "Deploy complete!"
```

The rules then show up in the Firebase console under Firestore Database → Rules.

## Test

```bash
pytest          # prints "13 passed"
ruff check .    # prints "All checks passed!"
```

## Run the app

```bash
cd ..
flutter pub get   # downloads Flutter packages
flutter run       # builds and opens the app on a simulator, emulator, or Chrome
```
