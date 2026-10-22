# FamilyTrack

Family spending tracker with shared budgets.

```
familytrack/
├── mobile/    Flutter app (iOS + Android)
└── backend/   Node.js + Express + TypeScript API for syncing family groups
```

## Run the app

```bash
cd mobile
flutter pub get
flutter run
```

## Run the API

Needs Node.js 22.13 or newer (uses the built-in `node:sqlite`).

```bash
cd backend
npm install
cp .env.example .env   # then set JWT_SECRET
npm run dev            # http://localhost:3001
npm test
```

See [backend/README.md](backend/README.md) for the endpoints.

## Connecting the app to the API

Everything lives on the API, so the app asks you to sign in first:

1. Start the API (`npm run dev` in `backend/`).
2. Open the app → **Create Account** → **Create Family** (or **Join
   Family** with someone's invite code).
3. Share the invite code from the **Family** tab; others sign up and join.

The app keeps a copy on the phone, so it still works offline and uploads
changes once it's back online.

Changes upload about a second after they're made. The family's changes download
on launch, when the app comes back to the foreground, every minute, and on
pull-to-refresh in the Family tab.

Default server address: `http://localhost:3001/api` (iOS simulator) or
`http://10.0.2.2:3001/api` (Android emulator). On a real phone, set your
computer's Wi-Fi address under **Profile → Server**, or run
`flutter run --dart-define=API_URL=http://<your-ip>:3001/api`.

Sync test against a running API (covers every feature end to end):

```bash
cd backend && PORT=3100 npm run dev
cd mobile && API_URL=http://localhost:3100/api flutter test test/sync_integration_test.dart
```
